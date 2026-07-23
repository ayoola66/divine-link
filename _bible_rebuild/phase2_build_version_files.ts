/**
 * Phase 2 — build the 5 downloadable premium version files (WEBBE, YLT, Darby, DRA, BBE).
 *
 * Each version becomes a STANDALONE, ATTACH-compatible SQLite file with the SAME `verses`
 * schema as the bundled Bible.db, so the app can `ATTACH` it and query verses directly. These
 * files are hosted (Netlify /bibles/) and downloaded on demand by premium users — they are NOT
 * bundled in the app (keeps the initial download light).
 *
 * Output: _bible_rebuild/bibles/{ID}.sqlite  + a catalog.json manifest.
 * Idempotent; disk-caches raw chapter JSON under _bible_rebuild/cache/.
 *
 *   bun _bible_rebuild/phase2_build_version_files.ts
 */
import { Database } from "bun:sqlite";
import { mkdirSync, existsSync, readFileSync, writeFileSync, rmSync, statSync } from "node:fs";
import { createHash } from "node:crypto";

const HERE = decodeURIComponent(new URL(".", import.meta.url).pathname);
const CACHE = `${HERE}cache`;
const OUT = `${HERE}bibles`;
const API = "https://bible.helloao.org/api";
const CONCURRENCY = 12;

const TARGETS = [
  { src: "eng_webpb", id: "WEBBE", name: "World English Bible (British Edition)", year: 2000, requires_attribution: 0, attribution_text: "World English Bible British Edition (public domain).", sort_order: 6 },
  { src: "eng_ylt",   id: "YLT",   name: "Young's Literal Translation",           year: 1898, requires_attribution: 0, attribution_text: null, sort_order: 7 },
  { src: "eng_dby",   id: "DBY",   name: "Darby Translation",                     year: 1890, requires_attribution: 0, attribution_text: null, sort_order: 8 },
  { src: "eng_dra",   id: "DRA",   name: "Douay-Rheims 1899",                     year: 1899, requires_attribution: 0, attribution_text: null, sort_order: 9 },
  { src: "eng_bbe",   id: "BBE",   name: "Bible in Basic English",                year: 1949, requires_attribution: 0, attribution_text: "Bible in Basic English (public domain).", sort_order: 10 },
];

mkdirSync(CACHE, { recursive: true });
mkdirSync(OUT, { recursive: true });

async function getChapter(src: string, book: string, chapter: number): Promise<any> {
  const dir = `${CACHE}/${src}/${book}`;
  const file = `${dir}/${chapter}.json`;
  if (existsSync(file)) { try { return JSON.parse(readFileSync(file, "utf8")); } catch {} }
  const url = `${API}/${src}/${book}/${chapter}.json`;
  let lastErr: any;
  for (let a = 1; a <= 4; a++) {
    try {
      const res = await fetch(url); if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      mkdirSync(dir, { recursive: true }); writeFileSync(file, JSON.stringify(json));
      return json;
    } catch (e) { lastErr = e; await new Promise(r => setTimeout(r, 300 * a)); }
  }
  throw new Error(`fetch failed ${url}: ${lastErr}`);
}

function verseText(content: any[]): string {
  const parts: string[] = [];
  for (const item of content) {
    if (typeof item === "string") parts.push(item);
    else if (item && typeof item === "object" && typeof item.text === "string") parts.push(item.text);
  }
  return parts.join(" ").replace(/\s+/g, " ").trim();
}

interface Row { book_id: number; chapter: number; verse: number; text: string }

// Canonical Protestant 66 in order → USFM code maps to book_id (index+1), matching the app's
// `books` table. Mapping by USFM code (not ordinal position) is correct across canons: Catholic
// versions like DRA append deuterocanonical books (TOB/JDT/WIS/SIR/BAR/1MA/2MA) which are simply
// not in this map and get skipped, so book_ids never shift.
const USFM_ORDER = ["GEN","EXO","LEV","NUM","DEU","JOS","JDG","RUT","1SA","2SA","1KI","2KI","1CH","2CH","EZR","NEH","EST","JOB","PSA","PRO","ECC","SNG","ISA","JER","LAM","EZK","DAN","HOS","JOL","AMO","OBA","JON","MIC","NAM","HAB","ZEP","HAG","ZEC","MAL","MAT","MRK","LUK","JHN","ACT","ROM","1CO","2CO","GAL","EPH","PHP","COL","1TH","2TH","1TI","2TI","TIT","PHM","HEB","JAS","1PE","2PE","1JN","2JN","3JN","JUD","REV"];
const USFM_TO_BOOKID: Record<string, number> = Object.fromEntries(USFM_ORDER.map((c, i) => [c, i + 1]));

async function fetchVerses(src: string, id: string): Promise<Row[]> {
  const books: any[] = ((await (await fetch(`${API}/${src}/books.json`)).json()) as any).books ?? [];
  const canonical = books.filter((b: any) => USFM_TO_BOOKID[b.id] != null);
  if (canonical.length !== 66) console.warn(`  ⚠ ${id}: ${canonical.length}/66 canonical books (source had ${books.length})`);
  const skipped = books.length - canonical.length;
  if (skipped > 0) console.log(`  ℹ ${id}: skipped ${skipped} non-canonical (deuterocanonical) books`);
  const rows: Row[] = [];
  for (let bi = 0; bi < canonical.length; bi++) {
    const book = canonical[bi], bookId = USFM_TO_BOOKID[book.id], n = book.numberOfChapters ?? 0;
    const results: any[] = new Array(n);
    let idx = 0;
    const worker = async () => { while (idx < n) { const my = idx++; results[my] = await getChapter(src, book.id, my + 1); } };
    await Promise.all(Array.from({ length: Math.min(CONCURRENCY, n) }, worker));
    for (const chJson of results) {
      const ch = chJson?.chapter; if (!ch) continue;
      for (const c of ch.content ?? []) {
        if (c?.type !== "verse") continue;
        const text = verseText(c.content ?? []); if (!text) continue;
        rows.push({ book_id: bookId, chapter: ch.number ?? 0, verse: c.number, text });
      }
    }
    process.stdout.write(`\r  ${id}: ${bi + 1}/66 books, ${rows.length} verses`);
  }
  process.stdout.write("\n");
  return rows;
}

const manifest: any[] = [];

for (const t of TARGETS) {
  console.log(`▶ ${t.id} (${t.name})`);
  const rows = await fetchVerses(t.src, t.id);

  const outFile = `${OUT}/${t.id}.sqlite`;
  if (existsSync(outFile)) rmSync(outFile);
  const db = new Database(outFile);
  db.run(`CREATE TABLE verses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    translation_id TEXT NOT NULL, book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL, verse INTEGER NOT NULL, text TEXT NOT NULL)`);
  db.run("CREATE INDEX idx_verses_lookup ON verses(translation_id, book_id, chapter, verse)");
  db.run(`CREATE TABLE version_meta (
    id TEXT PRIMARY KEY, name TEXT, year INTEGER, verse_count INTEGER,
    requires_attribution INTEGER, attribution_text TEXT)`);
  const ins = db.prepare("INSERT INTO verses (translation_id, book_id, chapter, verse, text) VALUES (?,?,?,?,?)");
  const tx = db.transaction(() => {
    for (const r of rows) ins.run(t.id, r.book_id, r.chapter, r.verse, r.text);
    db.prepare("INSERT INTO version_meta (id,name,year,verse_count,requires_attribution,attribution_text) VALUES (?,?,?,?,?,?)")
      .run(t.id, t.name, t.year, rows.length, t.requires_attribution, t.attribution_text);
  });
  tx();

  // verify
  const dups = (db.query("SELECT COUNT(*) n FROM (SELECT 1 FROM verses GROUP BY book_id,chapter,verse HAVING COUNT(*)>1)").get() as any).n;
  const contam = (db.query("SELECT COUNT(*) n FROM verses WHERE text LIKE '%¶%' OR text GLOB '*[a-z][0-9]:[0-9]*'").get() as any).n;
  const books = (db.query("SELECT COUNT(DISTINCT book_id) n FROM verses").get() as any).n;
  const j316 = (db.query("SELECT text FROM verses WHERE book_id=43 AND chapter=3 AND verse=16").get() as any)?.text ?? "(missing)";
  db.run("VACUUM"); db.close();

  const bytes = statSync(outFile).size;
  const sha = createHash("sha256").update(readFileSync(outFile)).digest("hex");
  console.log(`  ✓ ${t.id}: ${rows.length} verses, ${books} books, dups=${dups}, contam=${contam}, ${(bytes/1048576).toFixed(1)}MB`);
  console.log(`      John 3:16 → ${j316.slice(0,80)}${j316.length>80?"…":""}`);

  manifest.push({
    id: t.id, name: t.name, year: t.year, tier: "premium", downloadable: true,
    verse_count: rows.length, file: `${t.id}.sqlite`, file_size: bytes, sha256: sha,
    requires_attribution: !!t.requires_attribution, attribution_text: t.attribution_text,
    sort_order: t.sort_order,
    download_url: `https://divinelink.netlify.app/bibles/${t.id}.sqlite`,
  });
}

writeFileSync(`${OUT}/catalog.json`, JSON.stringify({ version: 1, versions: manifest }, null, 2));
console.log(`\n✅ Built ${TARGETS.length} version files + catalog.json in ${OUT}`);
