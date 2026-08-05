#!/usr/bin/env python3
"""Keep the website's visible version badges + release-notes list in sync with a release.

Called automatically by release.sh at the end of every release — do not run by hand
unless you're deliberately backfilling a version the site missed (see release.sh history).

Usage:
    update_website_version.py <version> <zip_filename> <release_date> <release_notes_html>

<release_notes_html> is the SAME HTML block release.sh already collects for appcast.xml
(e.g. "<h2>What's New in 1.6.1</h2><ul><li>...</li></ul>") — reused here so there is only
ever one place to type release notes, not two.
"""
import re
import sys
from pathlib import Path

SITE_DIR = Path(__file__).resolve().parent.parent / "Distribution" / "netlify-site"
INDEX_HTML = SITE_DIR / "index.html"
RELEASES_HTML = SITE_DIR / "releases.html"


def replace_version_span(text: str, css_class: str, new_version: str) -> str:
    pattern = re.compile(rf'(<span class="{css_class}">)v[\d.]+(</span>)')
    new_text, count = pattern.subn(rf"\g<1>v{new_version}\g<2>", text)
    if count == 0:
        print(f"⚠️  No <span class=\"{css_class}\"> found — site markup may have changed; skipped.")
    return new_text


def demote_previous_latest(html: str) -> str:
    # Strip " latest open" from the class of whatever release-item currently claims it,
    # and drop its "Latest" badge — there can only be one.
    html = html.replace('class="release-item latest open"', 'class="release-item"', 1)
    html = re.sub(r'\s*<span class="release-badge">Latest</span>\n?', "\n", html, count=1)
    return html


def build_release_item(version: str, zip_filename: str, release_date: str, notes_html: str) -> str:
    # notes_html looks like "<h2>Title</h2><ul>...</ul>" (same block typed for appcast.xml).
    title_match = re.search(r"<h2>(.*?)</h2>", notes_html, re.DOTALL)
    title = title_match.group(1).strip() if title_match else "What's New"
    ul_match = re.search(r"<ul>.*?</ul>", notes_html, re.DOTALL)
    list_html = ul_match.group(0) if ul_match else "<ul></ul>"

    return f"""
            <!-- v{version} -->
            <div class="release-item latest open">
                <div class="release-header" onclick="toggleRelease(this)">
                    <div class="release-info">
                        <span class="release-version">v{version}</span>
                        <span class="release-date">{release_date}</span>
                        <span class="release-badge">Latest</span>
                    </div>
                    <div class="release-toggle">▼</div>
                </div>
                <div class="release-content">
                    <div class="release-body">
                        <div class="release-section">
                            <h4 class="fixed">🔧 {title}</h4>
                            {list_html}
                        </div>
                        <a href="releases/{zip_filename}" class="release-download">⬇️ Download v{version}</a>
                    </div>
                </div>
            </div>
"""


def main():
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)
    version, zip_filename, release_date, notes_html = sys.argv[1:5]

    # --- index.html: footer version badge only ---
    index_text = INDEX_HTML.read_text()
    index_text = replace_version_span(index_text, "version-badge", version)
    INDEX_HTML.write_text(index_text)
    print(f"✅ index.html footer badge → v{version}")

    # --- releases.html: hero badge, footer badge, and a new release-item entry ---
    releases_text = RELEASES_HTML.read_text()
    releases_text = replace_version_span(releases_text, "version-number", version)
    releases_text = replace_version_span(releases_text, "footer-version", version)
    releases_text = demote_previous_latest(releases_text)

    new_item = build_release_item(version, zip_filename, release_date, notes_html)
    anchor = '<section class="releases">\n        <div class="container">\n            '
    if anchor not in releases_text:
        print('⚠️  Could not find releases-list anchor in releases.html — new entry NOT inserted. Insert manually.')
    else:
        releases_text = releases_text.replace(anchor, anchor + new_item.strip() + "\n\n            ", 1)
        print(f"✅ releases.html — new v{version} entry added, previous entry demoted from Latest")

    RELEASES_HTML.write_text(releases_text)


if __name__ == "__main__":
    main()
