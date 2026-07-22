/**
 * Phase 0 — Translations metadata migration.
 *
 * Extends the existing `translations` table with the metadata the app needs to drive a
 * dynamic, free/premium-aware version list, makes the table reflect the verses actually
 * present, and removes any translation row that has no verses (so the app can never offer
 * a broken/empty version).
 *
 * Idempotent: safe to run repeatedly. Run with:
 *   bun _bible_rebuild/phase0_translations_migration.ts
 *
 * Operates on the bundled source DB at DivineLink/DivineLink/Resources/Bible.db.
 */
import { Database } from "bun:sqlite";
import { copyFileSync, existsSync } from "node:fs";

const DB_PATH = decodeURIComponent(new URL("../DivineLink/DivineLink/Resources/Bible.db", import.meta.url).pathname);
if (!existsSync(DB_PATH)) {
  console.error("❌ Bible.db not found at", DB_PATH);
  process.exit(1);
}

// Backup before touching the bundled DB. IMPORTANT: write it OUTSIDE the Resources folder —
// this project's Xcode synchronized group auto-bundles everything under Resources/, so a .bak
// there would ship inside the app. Keep backups in _bible_rebuild/ (gitignored, non-bundled).
const backup = decodeURIComponent(new URL("./Bible.db.pre-phase0.bak", import.meta.url).pathname);
copyFileSync(DB_PATH, backup);
console.log("🗄  backup:", backup);

const db = new Database(DB_PATH);

// --- 1. Extend the schema (guarded — ALTER only if the column is absent) ------------------
const cols = new Set(
  db.query(`PRAGMA table_info(translations)`).all().map((r: any) => r.name)
);
const addColumn = (name: string, ddl: string) => {
  if (!cols.has(name)) {
    db.run(`ALTER TABLE translations ADD COLUMN ${ddl}`);
    console.log("  + column", name);
  }
};
addColumn("language", "language TEXT DEFAULT 'en'");
addColumn("is_public_domain", "is_public_domain INTEGER DEFAULT 0");
addColumn("is_premium", "is_premium INTEGER DEFAULT 0");
addColumn("requires_attribution", "requires_attribution INTEGER DEFAULT 0");
addColumn("attribution_text", "attribution_text TEXT");
addColumn("source_url", "source_url TEXT");
addColumn("verse_count", "verse_count INTEGER DEFAULT 0");
addColumn("sort_order", "sort_order INTEGER DEFAULT 0");

// --- 2. Canonical metadata for the versions that actually ship right now -------------------
// Only public-domain versions with verses in the DB. Future versions (BSB, LSV, …) are added
// by their own phase migrations when their verses land — keeping "in table == has verses".
type Meta = {
  id: string; name: string; year: number; language: string;
  is_default: number; is_public_domain: number; is_premium: number;
  requires_attribution: number; attribution_text: string | null;
  source_url: string | null; sort_order: number;
};
const META: Meta[] = [
  { id: "KJV", name: "King James Version", year: 1769, language: "en", is_default: 1, is_public_domain: 1, is_premium: 0, requires_attribution: 0, attribution_text: null, source_url: "https://github.com/scrollmapper/bible_databases", sort_order: 1 },
  { id: "WEB", name: "World English Bible", year: 2000, language: "en", is_default: 0, is_public_domain: 1, is_premium: 0, requires_attribution: 0, attribution_text: "World English Bible (public domain).", source_url: "https://getbible.net", sort_order: 2 },
  { id: "ASV", name: "American Standard Version", year: 1901, language: "en", is_default: 0, is_public_domain: 1, is_premium: 0, requires_attribution: 0, attribution_text: null, source_url: "https://github.com/scrollmapper/bible_databases", sort_order: 3 },
];

// Actual verse counts, straight from the data.
const verseCount = (id: string): number =>
  (db.query(`SELECT COUNT(*) AS n FROM verses WHERE translation_id = ?`).get(id) as any).n as number;

const upsert = db.prepare(`
  INSERT INTO translations
    (id, name, year, is_default, language, is_public_domain, is_premium,
     requires_attribution, attribution_text, source_url, verse_count, sort_order)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
  ON CONFLICT(id) DO UPDATE SET
    name=excluded.name, year=excluded.year, is_default=excluded.is_default,
    language=excluded.language, is_public_domain=excluded.is_public_domain,
    is_premium=excluded.is_premium, requires_attribution=excluded.requires_attribution,
    attribution_text=excluded.attribution_text, source_url=excluded.source_url,
    verse_count=excluded.verse_count, sort_order=excluded.sort_order
`);

for (const m of META) {
  const n = verseCount(m.id);
  if (n === 0) { console.warn(`  ⚠ ${m.id} has 0 verses — skipping metadata upsert`); continue; }
  upsert.run(m.id, m.name, m.year, m.is_default, m.language, m.is_public_domain,
    m.is_premium, m.requires_attribution, m.attribution_text, m.source_url, n, m.sort_order);
  console.log(`  ✓ ${m.id}: ${n} verses`);
}

// --- 3. Remove translation rows that have no verses (e.g. the stray YLT) -------------------
const orphans = db.query(
  `SELECT id FROM translations WHERE id NOT IN (SELECT DISTINCT translation_id FROM verses)`
).all().map((r: any) => r.id);
for (const id of orphans) {
  db.run(`DELETE FROM translations WHERE id = ?`, [id]);
  console.log(`  🧹 removed empty translation row: ${id}`);
}

// --- 4. Report ----------------------------------------------------------------------------
console.log("\n=== translations table now ===");
for (const r of db.query(
  `SELECT id, name, year, is_default, is_premium, is_public_domain, verse_count, sort_order
   FROM translations ORDER BY sort_order`
).all() as any[]) {
  console.log(`  ${r.id.padEnd(4)} ${String(r.name).padEnd(28)} ${r.year}  def=${r.is_default} prem=${r.is_premium} pd=${r.is_public_domain} verses=${r.verse_count}`);
}

db.close();
console.log("\n✅ Phase 0 migration complete.");
