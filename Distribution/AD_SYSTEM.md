# Divine Link - Dynamic Ad System Documentation

## Overview

Divine Link includes a comprehensive dynamic ad system that allows administrators to manage advertisements displayed within the macOS application. The system supports multiple ad formats, automatic rotation, enforcement mechanisms, and real-time updates without requiring app restarts.

## Table of Contents

1. [Architecture](#architecture)
2. [Ad Formats](#ad-formats)
3. [Admin Dashboard](#admin-dashboard)
4. [Database Schema](#database-schema)
5. [API Endpoints](#api-endpoints)
6. [App Integration](#app-integration)
7. [Ad Rotation & Refresh](#ad-rotation--refresh)
8. [Enforcement System](#enforcement-system)
9. [Troubleshooting](#troubleshooting)

---

## Architecture

### Components

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────┐
│   Admin Page    │─────────▶│   Supabase   │◀────────│  macOS App  │
│  (Netlify)      │  HTTP   │   Database   │  HTTP   │ (SwiftUI)   │
└─────────────────┘         └──────────────┘         └─────────────┘
                                      │
                                      │ RPC Functions
                                      ▼
                            ┌─────────────────┐
                            │  Ad Management  │
                            │   Functions     │
                            └─────────────────┘
```

### Technology Stack

- **Frontend (Admin)**: HTML/CSS/JavaScript hosted on Netlify
- **Backend**: Supabase (PostgreSQL + RPC Functions)
- **App**: SwiftUI with `DynamicAdService` singleton
- **Caching**: Local JSON cache for offline support

---

## Ad Formats

The system supports three ad formats:

### 1. Square Ads (1:1 Ratio)
- **Aspect Ratio**: 1:1 (e.g., 200×200px, 300×300px)
- **Location**: Right sidebar
- **Use Case**: Product images, logos, book covers
- **Max Display**: Up to 3 stacked vertically

### 2. Portrait Ads (9:16 Ratio)
- **Aspect Ratio**: 9:16 (tall, vertical)
- **Location**: Right sidebar (below square ads)
- **Use Case**: Book covers, mobile app screenshots
- **Max Display**: 1 per sidebar

### 3. Banner Ads (728×90 Ratio)
- **Aspect Ratio**: ~8:1 (wide, horizontal)
- **Location**: Bottom of app window (full width)
- **Use Case**: Promotional banners, affiliate links
- **Max Display**: 1 per app window

---

## Admin Dashboard

### Access

**URL**: `https://divinelink.netlify.app/admin.html`

**Authentication**: Password-protected (configured in admin.html)

### Features

1. **Live Preview**
   - Mirrors exact app layout
   - Shows square + portrait + banner slots
   - Displays active ads count per format
   - Highlights enforced ads with 📌 indicator

2. **Create Ad**
   - Select format (Square/Portrait/Banner)
   - Enter ad name (shown in tooltip)
   - Upload image URL
   - Enter click URL (affiliate link)
   - Set priority (1-100, higher = shown first)
   - Enable enforcement (pins ad, prevents rotation)

3. **Manage Ads**
   - View all ads in grid
   - See statistics (views, clicks)
   - Enable/Disable ads
   - Enforce/Release ads
   - Delete ads

4. **Statistics**
   - Total ads count
   - Active ads count
   - Enforced ads count
   - Total clicks
   - Click-through rate (CTR)

### Creating an Ad

1. Navigate to admin dashboard
2. Select format (Square/Portrait/Banner)
3. Fill in required fields:
   - **Name**: Display name (shown in tooltip)
   - **Image URL**: Direct link to image
   - **Click URL**: Destination when clicked
   - **Priority**: 1-100 (default: 50)
   - **Enforced**: Check to pin ad
4. Click "Create Ad"
5. Ad appears in app within 15 minutes (or restart app)

---

## Database Schema

### `ads` Table

```sql
CREATE TABLE public.ads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slot TEXT NOT NULL,              -- 'square', 'portrait', 'banner'
    format TEXT NOT NULL,            -- 'square', 'portrait', 'banner'
    image_url TEXT NOT NULL,
    click_url TEXT NOT NULL,
    alt_text TEXT,
    priority INTEGER DEFAULT 50,
    is_active BOOLEAN DEFAULT TRUE,
    is_enforced BOOLEAN DEFAULT FALSE,
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### RLS Policies

- **Public Read**: Anyone can read active ads
- **Admin Write**: Only authenticated admins can create/update/delete

### RPC Functions

#### `get_all_active_ads()`

Returns all active ads ordered by enforcement status and priority.

**Returns**:
```json
[
  {
    "id": "uuid",
    "name": "Bible Study Journal",
    "slot": "square",
    "format": "square",
    "image_url": "https://...",
    "click_url": "https://...",
    "alt_text": "Bible Study Journal",
    "priority": 50,
    "is_enforced": false
  }
]
```

#### `record_ad_event(ad_id, event_type)`

Records impression or click events.

**Parameters**:
- `ad_id`: UUID of the ad
- `event_type`: 'impression' or 'click'

---

## API Endpoints

### Fetch Active Ads

```
POST /rest/v1/rpc/get_all_active_ads
Headers:
  apikey: <SUPABASE_ANON_KEY>
  Content-Type: application/json
Body: {}
```

### Record Event

```
POST /rest/v1/rpc/record_ad_event
Headers:
  apikey: <SUPABASE_ANON_KEY>
  Content-Type: application/json
Body: {
  "ad_id": "uuid",
  "event_type": "impression" | "click"
}
```

---

## App Integration

### DynamicAdService

Singleton service managing ad fetching, caching, and rotation.

**Key Methods**:

```swift
// Fetch ads from server
await DynamicAdService.shared.fetchAds()

// Get ad for specific format
let ad = DynamicAdService.shared.ad(for: .square)

// Get all ads for format
let squares = DynamicAdService.shared.ads(for: .square)

// Check if portrait ad available
if DynamicAdService.shared.hasPortraitAd { ... }

// Force refresh (after admin adds new ad)
DynamicAdService.shared.forceRefresh()
```

### Ad Display Views

#### AdSidebarView
- Displays square and portrait ads
- Dynamic layout based on available ads
- Shows "Remove Ads" button at bottom

#### AdBannerView
- Displays banner ads at bottom
- Full-width layout
- Shows placeholder if no banner ad

### Layout Rules

**Sidebar Layout** (Dynamic - adapts to window size and available ads):
- **Default (2 ads)**:
  - 3 squares (when no portrait ad available)
  - OR 1 square + 1 portrait (when portrait ad available)
- **Stretched Window (3 ads)**:
  - 2 squares + 1 portrait (when window height allows and portrait ad available)
- **Priority**: Portrait ads are always prioritised when available
- **Dynamic**: Layout automatically adjusts when window is resized

**Banner Layout**:
- **Always shows** if banner ad is available (regardless of subscription status)
- Shows placeholder if no banner ad but ads should be shown
- Full width at bottom of app
- Hidden only if no banner ad AND premium user

---

## Ad Rotation & Refresh

### Rotation (Between Cached Ads)

- **Interval**: Every 5 minutes
- **Behavior**: Rotates between ads of same format
- **Exception**: Enforced ads never rotate

### Server Refresh (Fetch New Ads)

- **Interval**: Every 15 minutes
- **Behavior**: Fetches latest ads from Supabase
- **On App Start**: Always fetches fresh ads
- **Manual**: Call `forceRefresh()` for instant update

### Caching

- **Location**: `~/Library/Caches/dynamic_ads.json`
- **Expiry**: 24 hours
- **Offline**: Uses cached ads if server unavailable
- **Format**: JSON with timestamp

---

## Enforcement System

### How It Works

1. **Enforced Ads**: Always shown first in their format slot
2. **Non-Enforced**: Rotate every 5 minutes
3. **Priority**: Among enforced ads, higher priority shown first

### Use Cases

- **Promotional Campaigns**: Pin specific ads for limited time
- **Important Announcements**: Ensure visibility
- **A/B Testing**: Enforce one variant, rotate others

### Admin Actions

- **Enforce**: Click "📌 Enforce" button in admin
- **Release**: Click "Release" button to remove enforcement
- **Visual Indicator**: Enforced ads show red border + 📌 icon

---

## Troubleshooting

### Ads Not Showing

1. **Check Database**:
   ```sql
   SELECT * FROM ads WHERE is_active = TRUE;
   ```

2. **Verify Format**:
   - Ensure `format` matches: 'square', 'portrait', or 'banner'
   - Check `slot` field matches format

3. **Check App Logs**:
   - Look for "✅ Fetched X ads from server"
   - Check for "❌ Failed to fetch ads" errors

4. **Force Refresh**:
   - Restart app (fetches on startup)
   - Or wait 15 minutes for auto-refresh

### Admin Page Not Working

1. **Check API Key**:
   - Verify `SUPABASE_ANON_KEY` in admin.html
   - Ensure key has RLS read permissions

2. **Check Network**:
   - Open browser console (F12)
   - Look for CORS or 401 errors

3. **Verify RPC Function**:
   ```sql
   SELECT * FROM get_all_active_ads();
   ```

### Image Not Loading

1. **Check URL**:
   - Must be direct image URL (ends in .jpg, .png, etc.)
   - Must be HTTPS
   - Must allow CORS

2. **Test URL**:
   - Open image URL directly in browser
   - Should display image, not redirect

### Ad Click Not Working

1. **Check Click URL**:
   - Must be valid HTTPS URL
   - Should open in browser

2. **Verify Tracking**:
   - Check `clicks` column in database
   - Should increment on click

---

## Best Practices

### Image Guidelines

- **Square**: 300×300px minimum, 1:1 ratio
- **Portrait**: 300×533px minimum, 9:16 ratio
- **Banner**: 728×90px recommended, ~8:1 ratio
- **Format**: JPG or PNG
- **Size**: < 500KB for fast loading
- **Hosting**: Use CDN or reliable image hosting

### Ad Management

- **Naming**: Use descriptive names (shown in tooltip)
- **Priority**: Use 1-100 scale (50 = default)
- **Enforcement**: Use sparingly (prevents rotation)
- **Testing**: Test ads in admin preview before publishing

### Performance

- **Cache**: Ads cached locally for offline support
- **Refresh**: 15-minute refresh balances freshness vs. server load
- **Rotation**: 5-minute rotation keeps content dynamic

---

## Configuration

### App Configuration

**File**: `DivineLink/Services/SupabaseConfig.swift`

```swift
static let projectURL = URL(string: "https://qzjhjgkvvcamcqpdrgkf.supabase.co")!
static let anonKey = "your-anon-key-here"
```

### Admin Configuration

**File**: `divine-link-site/admin.html`

```javascript
const SUPABASE_URL = 'https://qzjhjgkvvcamcqpdrgkf.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-key-here';
```

### Database Configuration

Run `supabase-schema.sql` in Supabase SQL Editor to set up:
- `ads` table
- RLS policies
- RPC functions
- Indexes

---

## Security

### Row Level Security (RLS)

- **Public Read**: Anyone can read active ads (needed for app)
- **Admin Write**: Only authenticated admins can modify
- **API Key**: Uses Supabase Anon Key (read-only for public)

### Admin Access

- **Password**: Configured in admin.html JavaScript
- **No Backend Auth**: Simple password check (consider upgrading)
- **Recommendation**: Add Supabase Auth for production

---

## Future Enhancements

Potential improvements:

1. **Admin Authentication**: Supabase Auth integration
2. **Ad Scheduling**: Start/end dates for campaigns
3. **A/B Testing**: Built-in variant testing
4. **Analytics Dashboard**: Visual charts and graphs
5. **Bulk Operations**: Import/export ads
6. **Image Upload**: Direct upload to Supabase Storage
7. **Ad Templates**: Pre-configured formats
8. **Geographic Targeting**: Show ads by region

---

## Support

For issues or questions:

1. Check this documentation
2. Review app logs
3. Check Supabase dashboard
4. Verify database schema matches `supabase-schema.sql`

---

**Last Updated**: 2026-02-01
**Version**: 1.0.0
