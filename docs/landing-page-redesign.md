# Landing Page Redesign — Design Audit & Implementation Plan

**File:** `Distribution/netlify-site/index.html`
**Audit Date:** 2026-02-18
**Status:** Pending Implementation

---

## Overview

This document captures the full design audit of the Divine Link landing page and tracks all planned improvements. Updates are grouped by priority and type. Each item includes a clear rationale, the specific change required, and a status field to track progress.

---

## What's Working Well (Keep These)

- **Burnt orange brand colour (`#E07A2B`)** — warm, faith-coded, distinctive against competitors using blues and purples
- **Dark theme** — right choice for an AV/church booth audience
- **Tier naming: Mercy / Grace / Love** with Bible verse subtitles — genuinely memorable and on-brand
- **Billing toggle (Monthly / Yearly)** — clean and functional
- **Feature set and comparison table** — comprehensive and well-structured
- **Semantic HTML and meta/SEO** — structured data, OG tags, and JSON-LD are solid

---

## Priority 1 — Critical (High Impact, No New Assets Needed)

### 1.1 Typography Overhaul

**Problem:** The page uses `Inter` as its primary font family. Inter is the most overused font in AI-generated and template UIs. For a product with spiritually themed tier names and a faith-tech audience, this is a significant missed opportunity.

**Fix:**
- Replace `Inter` with a pairing of **Cinzel** (display/headings) + **DM Sans** (body/UI text)
- Cinzel has classical, inscribed-stone gravitas that fits the spiritual naming; DM Sans is clean but more characterful than Inter
- Load from Google Fonts:
  ```html
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800&family=DM+Sans:wght@400;500;600&display=swap" rel="stylesheet">
  ```
- Apply in CSS:
  ```css
  body { font-family: 'DM Sans', sans-serif; }
  h1, h2, h3, .logo, .price { font-family: 'Cinzel', serif; }
  ```

**Files to change:** `index.html` (lines 127–129 font link, line 157 body font-family, add heading rule)

---

### 1.2 Scroll Animations

**Problem:** The page has zero entrance animations. For a 9-section long-form landing page, the lack of scroll reveals makes it feel static and unengaging. The only motion is CSS hover transitions.

**Fix:** Use `IntersectionObserver` to add a `.visible` class when elements enter the viewport, then animate with CSS:

```css
.reveal {
  opacity: 0;
  transform: translateY(28px);
  transition: opacity 0.55s ease, transform 0.55s ease;
}
.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}
/* Stagger children */
.reveal-stagger .feature-card:nth-child(1) { transition-delay: 0s; }
.reveal-stagger .feature-card:nth-child(2) { transition-delay: 0.08s; }
.reveal-stagger .feature-card:nth-child(3) { transition-delay: 0.16s; }
/* ... repeat for each child */

/* Respect user motion preferences */
@media (prefers-reduced-motion: reduce) {
  .reveal { opacity: 1; transform: none; transition: none; }
}
```

```js
const observer = new IntersectionObserver(
  (entries) => entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); }),
  { threshold: 0.12 }
);
document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
```

**Apply `.reveal` to:** `.section-header`, `.feature-card`, `.step`, `.price-card`, `.why-card`, `.showcase-grid`, `.cta-content`

**Files to change:** `index.html` (CSS block + `<script>` block at bottom)

---

### 1.3 Mobile Navigation (Hamburger Menu)

**Problem:** At `max-width: 768px`, `.nav-links` is set to `display: none` with no replacement. Mobile users have no way to navigate the site.

**Fix:** Add a hamburger button that toggles a mobile menu drawer:

```html
<button class="nav-toggle" aria-label="Open menu" aria-expanded="false">
  <span></span><span></span><span></span>
</button>
```

```css
.nav-toggle {
  display: none;
  flex-direction: column;
  gap: 5px;
  background: none;
  border: none;
  cursor: pointer;
  padding: 8px;
}
.nav-toggle span {
  width: 24px; height: 2px;
  background: var(--text);
  border-radius: 2px;
  transition: all 0.3s;
}
@media (max-width: 768px) {
  .nav-toggle { display: flex; }
  .nav-links {
    display: flex;
    flex-direction: column;
    position: fixed;
    top: 0; right: -100%;
    width: 280px; height: 100vh;
    background: var(--bg-card);
    padding: 80px 32px 32px;
    transition: right 0.35s ease;
    border-left: 1px solid rgba(255,255,255,0.08);
  }
  .nav-links.open { right: 0; }
}
```

**Files to change:** `index.html` (header HTML, CSS block, script block)

---

### 1.4 Replace Emoji Icons in Feature Cards

**Problem:** All 9 feature cards use raw emoji as icons (🎤, 🔍, 📺, etc.). Emoji icons are visually inconsistent across operating systems and browsers, and they signal an unpolished prototype rather than a production product.

**Fix:** Replace with inline SVG icons sourced from [Heroicons](https://heroicons.com/) or [Lucide](https://lucide.dev/). Wrap in the existing `.feature-icon` container so no layout changes are needed.

**Affected icons to replace:**
| Emoji | Feature | Suggested SVG Icon Name (Lucide) |
|-------|---------|----------------------------------|
| 🎤 | Live Speech Recognition | `mic` |
| 🔍 | Intelligent Detection | `scan-search` |
| 📺 | ProPresenter Integration | `monitor-play` |
| ⚡ | Direct API Integration | `zap` |
| 📖 | Multiple Translations | `book-open` |
| 📑 | Multi-Verse Handling | `list` |
| 👤 | Pastor Profiles | `user-round` |
| 🔒 | Secure & Reliable | `shield-check` |
| 📬 | In-App Support | `message-square` |

Also replace emoji in `.why-icon` cards, integration bar, and the `.hero-badge`.

**Files to change:** `index.html` (feature-grid HTML, why-grid HTML, integration-logos HTML)

---

## Priority 2 — High Impact, Requires Assets or Content

### 2.1 Hero — Replace Stock Photo with App Screenshot

**Problem:** The right column of the hero grid contains an Unsplash stock photo of a church interior used as a generic background image. For a software product, the hero is the highest-value real estate on the page. It should show the actual app UI.

**Fix:**
- Place a macOS-style window mockup (or a real app screenshot) in `.hero-image`
- Style it with a realistic macOS window shadow:
  ```css
  .hero-mockup {
    border-radius: 12px;
    box-shadow:
      0 0 0 1px rgba(255,255,255,0.08),
      0 40px 80px rgba(0,0,0,0.6),
      0 20px 40px rgba(0,0,0,0.4);
  }
  ```
- Optionally wrap in a `.mac-window` div with a traffic-light dots header for authenticity

**Assets needed:** A screenshot of the Divine Link app in use (verse detected, push button visible)

**Files to change:** `index.html` (hero-image `<img>` src + CSS)

---

### 2.2 Add Testimonials Section

**Problem:** Beyond unverifiable stats (500+ churches, 50K+ scriptures), there is no qualitative social proof. Testimonials from real church AV operators would significantly improve conversion, particularly for a niche product in a trust-sensitive community.

**Fix:** Add a new section between `#how-it-works` and `#pricing`:

```html
<section class="testimonials" id="testimonials">
  <div class="container">
    <div class="section-header reveal">
      <div class="section-tag">From the Community</div>
      <h2 class="section-title">Trusted by Worship Teams</h2>
    </div>
    <div class="testimonial-grid">
      <blockquote class="testimonial-card reveal">
        <p>"We used to scramble every Sunday to find the scripture. Divine Link changed our entire workflow."</p>
        <cite>— AV Operator, Grace Community Church</cite>
      </blockquote>
      <!-- additional quotes -->
    </div>
  </div>
</section>
```

**Content needed:** 2–3 real quotes from users. Can use anonymised church names if needed.

**Files to change:** `index.html` (new section HTML + CSS)

---

### 2.3 Hero Stats — Verify or Replace

**Problem:** Stats in the hero (`500+ Churches`, `50K+ Scriptures Detected`, `99.2% Accuracy`) are high-value social proof if accurate, but if they're estimates or aspirational they can actively erode trust when users scrutinise them.

**Options:**
- **If accurate:** Keep them, but add a subtle note like "as of Feb 2026"
- **If estimates:** Replace with verifiable product claims, e.g.:
  - `10+` Bible Translations
  - `macOS 14+` Supported
  - `£0` to Start

**Files to change:** `index.html` (`.hero-stats` HTML)

---

## Priority 3 — Polish & Refinement

### 3.1 Background Atmosphere — Noise Texture

**Problem:** Section backgrounds alternate between `--bg-dark` and `--bg` for rhythm, but everything feels flat. There's no atmospheric depth.

**Fix:** Add a subtle SVG noise overlay as a fixed pseudo-element:

```css
body::after {
  content: '';
  position: fixed;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  opacity: 0.025;
  pointer-events: none;
  z-index: 9999;
}
```

**Files to change:** `index.html` (CSS block — `body::after`)

---

### 3.2 "Why Choose" Card 3 — Layout Fix

**Problem:** Card 3 (Better Value) has `.highlight-stat` ("33% less") placed between `.why-icon` and `h3`. No other card has this element, creating an inconsistent visual rhythm across the grid.

**Fix:** Either:
- Move `.highlight-stat` inside the `<p>` tag as a bolded inline element, or
- Add a stat to all 6 cards to make the pattern consistent (e.g. `100%` local, `1-click` display, `0ms` cloud latency)

**Files to change:** `index.html` (`.why-grid` HTML, lines ~1671–1710)

---

### 3.3 Footer — Add Structure

**Problem:** The footer is a single flex row with logo, links, and copyright. For a product with multiple supporting pages (Terms, Privacy, Releases, Compare, Contact), this feels sparse and buries navigation.

**Fix:** Expand to a 3-column layout:
- **Col 1:** Logo + one-line description
- **Col 2:** Product links (Features, Pricing, Releases, Compare)
- **Col 3:** Legal & Support (Terms, Privacy, Contact)

**Files to change:** `index.html` (footer HTML + CSS)

---

### 3.4 Integration Bar — Replace Emoji with Styled Badges

**Problem:** The integration bar uses emoji logos (`📺 ProPresenter 7`, `🎤 macOS Speech`) for professional software integrations. This reads as placeholder content.

**Fix:** Replace with styled pill/badge elements with proper icon + text:

```html
<div class="integration-badge">
  <svg><!-- monitor icon --></svg>
  <span>ProPresenter 7</span>
</div>
```

**Files to change:** `index.html` (`.integration-logos` HTML + `.integration-logo` CSS)

---

### 3.5 CTA Section — Strengthen Copy

**Problem:** The final CTA section simply repeats the download button with generic copy: "Ready to Transform Your Services?" This is a missed opportunity to reinforce the value proposition before the user leaves or converts.

**Fix:** Add a supporting reassurance line and secondary link:
```html
<p class="cta-reassurance">Free to start • No credit card required • macOS 14+</p>
<div class="cta-buttons">
  <a href="..." class="btn btn-primary">⬇ Download Free</a>
  <a href="#pricing" class="btn btn-secondary">View Pricing</a>
</div>
```

**Files to change:** `index.html` (`.cta-content` HTML)

---

### 3.6 Miscellaneous Small Fixes

| # | Issue | Location | Fix |
|---|-------|----------|-----|
| a | `line-height` inconsistency (1.7 body vs 1.8 in `<p>` overrides) | Various `<p>` tags | Standardise to `1.75` everywhere |
| b | `.step::after` connector lines misalign at 2-column breakpoint | `steps-container` at 1024px | Add `@media` override: `step::after { display: none; }` at ≤1024px |
| c | `background-clip: text` on inline `<span>` elements can cause rendering bugs | Price display, logo span | Wrap in `display: inline-block` |
| d | No `prefers-reduced-motion` media query | CSS | Add global rule (covered in 1.2) |
| e | `.hero-image` fully hidden at tablet (`display: none` at 1024px) | Hero section | Show below hero text rather than hiding |
| f | Mercy price card `.price` gradient override is double-declared | Lines 766–768 | Remove the redundant `.price-card .price` rule; the `.price-card.featured .price` rule is sufficient |

---

## Implementation Order

| Step | Item | Priority | Est. Effort |
|------|------|----------|-------------|
| 1 | Typography overhaul (1.1) | Critical | Small |
| 2 | Scroll animations (1.2) | Critical | Small |
| 3 | Mobile hamburger nav (1.3) | Critical | Small |
| 4 | Replace emoji icons (1.4) | Critical | Medium |
| 5 | App screenshot in hero (2.1) | High | Requires screenshot asset |
| 6 | Add testimonials section (2.2) | High | Requires quote content |
| 7 | Verify/replace hero stats (2.3) | High | Content decision needed |
| 8 | Background noise texture (3.1) | Polish | Small |
| 9 | Fix Why-Choose card 3 (3.2) | Polish | Small |
| 10 | Footer restructure (3.3) | Polish | Small |
| 11 | Integration bar badges (3.4) | Polish | Small |
| 12 | CTA copy improvements (3.5) | Polish | Small |
| 13 | Miscellaneous fixes (3.6) | Polish | Small |

---

## Notes

- Steps 1–4 can all be done in a single session with no new assets
- Steps 5–7 are blocked on content/assets from the team
- All changes are isolated to `Distribution/netlify-site/index.html`
- No framework changes, build tools, or dependency additions required
