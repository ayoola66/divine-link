/**
 * Phase 1 — import BSB + LSV (modern, public-domain) into the live Bible.db.
 *
 * Source: helloao.org Free-Use Bible API (public-domain / free-use translations).
 * Incremental + idempotent: deletes any existing rows for these translation_ids, re-imports,
 * and registers/updates their rows in the Phase-0 `translations` metadata table.
 * Raw chapter JSON is cached under _bible_rebuild/cache/ so re-runs don't re-hit the network.
 *
 *   bun _bible_rebuild/phase1_import_bsb_lsv.ts
 */
import { Database } from "bun:sqlite";
import { mkdirSync, existsSync, readFileSync, writeFileSync, copyFileSync } from "node:fs";

const HERE = decodeURIComponent(new URL(".", import.meta.url).pathname);
const DB_PATH = decodeURIComponent(new URL("../DivineLink/DivineLink/Resources/Bible.db", import.meta.url).pathname);
const CACHE = `${HERE}cache`;
const API = "https://bible.helloao.org/api";
const CONCURRENCY = 12;

// Each target: helloao source id -> our DB translation_id + metadata.
const TARGETS = [
  {
    src: "BSB", dbId: "BSB", name: "Berean Standard Bible", year: 2022,
    is_premium: 1, requires_attribution: 1,
    attribution_text: "The Holy Bible, Berean Standard Bible, BSB. Produced in cooperation with Bible Hub, Discovery Bible, OpenBible.com, and the Berean Bible Translation Committee. Public Domain.",
    source_url: "https://bible.helloao.org", sort_order: 4,
  },
  {
    src: "eng_lsv", dbId: "LSV", name: "Literal Standard Version", year: 2020,
    is_premium: 1, requires_attribution: 1,
    attribution_text: "The Holy Bible, Literal Standard Version, LSV. Copyright © 2020 Covenant Press. Released for free, non-commercial use.",
    source_url: "https://bible.helloao.org", sort_order: 5,
  },
];

if (!existsSync(DB_PATH)) { console.error("❌ Bible.db not found:", DB_PATH); process.exit(1); }
mkdirSync(CACHE, { recursive: true });

// --- fetch a chapter JSON, disk-cached, with retry -----------------------------------------
async function getChapter(src: string, book: string, chapter: number): Promise<any> {
  const dir = `${CACHE}/${src}/${book}`;
  const file = `${dir}/${chapter}.json`;
  if (existsSync(file)) {
    try { return JSON.parse(readFileSync(file, "utf8")); } catch { /* refetch on bad cache */ }
  }
  const url = `${API}/${src}/${book}/${chapter}.json`;
  let lastErr: any;
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      mkdirSync(dir, { recursive: true });
      writeFileSync(file, JSON.stringify(json));
      return json;
    } catch (e) {
      lastErr = e;
      await new Promise(r => setTimeout(r, 300 * attempt));
    }
  }
  throw new Error(`fetch failed ${url}: ${lastErr}`);
}

// --- extract clean verse text from a helloao verse.content array ---------------------------
// content is a mix of plain strings and objects ({noteId}, headings, line breaks). Keep only
// the string fragments; join with spaces; collapse whitespace. (LSV's [bracketed] words are
// part of the text and are preserved.)
function verseText(content: any[]): string {
  const parts: string[] = [];
  for (const item of content) {
    if (typeof item === "string") parts.push(item);
    else if (item && typeof item === "object" && typeof item.text === "string") parts.push(item.text);
    // skip {noteId}, {heading}, {lineBreak}, poetry markers, etc.
  }
  return parts.join(" ").replace(/\s+/g, " ").trim();
}

interface Row { book_id: number; chapter: number; verse: number; text: string }

async function importTarget(t: typeof TARGETS[number]): Promise<Row[]> {
  const booksJson: any = await (await fetch(`${API}/${t.src}/books.json`)).json();
  const books: any[] = booksJson.books ?? [];
  if (books.length !== 66) console.warn(`  ⚠ ${t.dbId}: ${books.length} books (expected 66)`);

  const rows: Row[] = [];
  for (let bi = 0; bi < books.length; bi++) {
    const book = books[bi];
    const bookId = bi + 1; // canonical order → book_id (matches DB books table 1..66)
    const nChapters: number = book.numberOfChapters ?? 0;

    // fetch this book's chapters with bounded concurrency
    const chapters: number[] = Array.from({ length: nChapters }, (_, i) => i + 1);
    const results: any[] = new Array(nChapters);
    let idx = 0;
    async function worker() {
      while (idx < chapters.length) {
        const my = idx++;
        results[my] = await getChapter(t.src, book.id, chapters[my]);
      }
    }
    await Promise.all(Array.from({ length: Math.min(CONCURRENCY, nChapters) }, worker));

    for (const chJson of results) {
      const ch = chJson?.chapter;
      if (!ch) continue;
      const chapterNum: number = ch.number ?? 0;
      for (const c of ch.content ?? []) {
        if (c?.type !== "verse") continue;
        const text = verseText(c.content ?? []);
        if (!text) continue;
        rows.push({ book_id: bookId, chapter: chapterNum, verse: c.number, text });
      }
    }
    process.stdout.write(`\r  ${t.dbId}: ${bi + 1}/66 books, ${rows.length} verses`);
  }
  process.stdout.write("\n");
  return rows;
}

// --- main ----------------------------------------------------------------------------------
const backup = `${HERE}Bible.db.pre-phase1.bak`;
copyFileSync(DB_PATH, backup);
console.log("🗄  backup:", backup, "\n");

const db = new Database(DB_PATH);
const insert = db.prepare("INSERT INTO verses (translation_id, book_id, chapter, verse, text) VALUES (?,?,?,?,?)");
const upsertMeta = db.prepare(`
  INSERT INTO translations
    (id, name, year, is_default, language, is_public_domain, is_premium,
     requires_attribution, attribution_text, source_url, verse_count, sort_order)
  VALUES (?,?,?,0,'en',1,?,?,?,?,?,?)
  ON CONFLICT(id) DO UPDATE SET
    name=excluded.name, year=excluded.year, is_public_domain=1, is_premium=excluded.is_premium,
    requires_attribution=excluded.requires_attribution, attribution_text=excluded.attribution_text,
    source_url=excluded.source_url, verse_count=excluded.verse_count, sort_order=excluded.sort_order
`);

for (const t of TARGETS) {
  console.log(`▶ ${t.dbId} (${t.name}) — fetching from helloao…`);
  const rows = await importTarget(t);

  const tx = db.transaction(() => {
    db.run("DELETE FROM verses WHERE translation_id = ?", [t.dbId]); // idempotent
    for (const r of rows) insert.run(t.dbId, r.book_id, r.chapter, r.verse, r.text);
    upsertMeta.run(t.dbId, t.name, t.year, t.is_premium, t.requires_attribution,
      t.attribution_text, t.source_url, rows.length, t.sort_order);
  });
  tx();
  console.log(`  ✓ ${t.dbId}: imported ${rows.length} verses\n`);
}

// --- verification --------------------------------------------------------------------------
console.log("=== verification ===");
for (const t of TARGETS) {
  const n = (db.query("SELECT COUNT(*) n FROM verses WHERE translation_id=?").get(t.dbId) as any).n;
  const dups = (db.query(
    "SELECT COUNT(*) n FROM (SELECT 1 FROM verses WHERE translation_id=? GROUP BY book_id,chapter,verse HAVING COUNT(*)>1)"
  ).get(t.dbId) as any).n;
  // John 3:16 = book_id 43, chapter 3, verse 16
  const j316 = (db.query("SELECT text FROM verses WHERE translation_id=? AND book_id=43 AND chapter=3 AND verse=16").get(t.dbId) as any)?.text ?? "(missing)";
  const contam = (db.query(
    "SELECT COUNT(*) n FROM verses WHERE translation_id=? AND (text LIKE '%¶%' OR text GLOB '*[a-z][0-9]:[0-9]*')"
  ).get(t.dbId) as any).n;
  console.log(`  ${t.dbId}: verses=${n} dups=${dups} contamination=${contam}`);
  console.log(`      John 3:16 → ${j316.slice(0, 90)}${j316.length > 90 ? "…" : ""}`);
}

console.log("\n=== translations table ===");
for (const r of db.query("SELECT id,name,year,is_premium,is_public_domain,requires_attribution,verse_count,sort_order FROM translations ORDER BY sort_order").all() as any[]) {
  console.log(`  ${r.id.padEnd(4)} ${String(r.name).padEnd(28)} ${r.year} prem=${r.is_premium} pd=${r.is_public_domain} attr=${r.requires_attribution} verses=${r.verse_count}`);
}

db.run("VACUUM");
db.close();
console.log("\n✅ Phase 1 import complete.");
