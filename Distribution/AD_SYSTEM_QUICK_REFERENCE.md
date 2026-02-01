# Ad System - Quick Reference Guide

## For Developers

### Key Files

```
DivineLink/
├── Services/
│   ├── DynamicAdService.swift      # Main ad service singleton
│   └── SupabaseConfig.swift        # Supabase configuration
└── Features/Ads/
    ├── AdViews.swift                # UI components (sidebar, banner)
    └── AdManager.swift              # Ad display manager
```

### Common Tasks

#### Fetch Ads Manually
```swift
await DynamicAdService.shared.fetchAds()
```

#### Force Refresh (After Admin Adds Ad)
```swift
DynamicAdService.shared.forceRefresh()
```

#### Get Ad for Display
```swift
let squareAd = DynamicAdService.shared.ad(for: .square)
let portraitAd = DynamicAdService.shared.ad(for: .portrait)
let bannerAd = DynamicAdService.shared.ad(for: .banner)
```

#### Check Available Ads
```swift
let squares = DynamicAdService.shared.ads(for: .square)
let hasPortrait = DynamicAdService.shared.hasPortraitAd
```

### Ad Format Enum

```swift
enum AdFormat {
    case square    // 1:1 ratio
    case portrait  // 9:16 ratio
    case banner    // 728×90 ratio
}
```

### Database Queries

#### Get All Active Ads
```sql
SELECT * FROM ads 
WHERE is_active = TRUE 
  AND (start_date IS NULL OR start_date <= NOW())
  AND (end_date IS NULL OR end_date >= NOW())
ORDER BY is_enforced DESC, priority DESC;
```

#### Record Impression
```sql
SELECT record_ad_event('ad-uuid-here', 'impression');
```

#### Record Click
```sql
SELECT record_ad_event('ad-uuid-here', 'click');
```

### Admin Dashboard URLs

- **Admin**: https://divinelink.netlify.app/admin.html
- **Password**: Configured in admin.html JavaScript

### Refresh Intervals

- **Rotation**: 5 minutes (between cached ads)
- **Server Refresh**: 15 minutes (fetch new ads)
- **On App Start**: Always fetches fresh ads

### Troubleshooting Commands

#### Check Ads in Database
```sql
SELECT id, name, format, is_active, is_enforced, priority 
FROM ads 
ORDER BY created_at DESC;
```

#### Test RPC Function
```sql
SELECT * FROM get_all_active_ads();
```

#### Check Ad Events
```sql
SELECT * FROM ad_events 
ORDER BY created_at DESC 
LIMIT 100;
```

### Testing Checklist

- [ ] Admin page loads and shows preview
- [ ] Can create ad with all formats
- [ ] Ad appears in app within 15 minutes
- [ ] Ad tooltip shows on hover
- [ ] Ad click opens URL
- [ ] Impression/click tracking works
- [ ] Enforced ads show first
- [ ] Rotation works for non-enforced ads
- [ ] Placeholders show when no ads
- [ ] Layout adjusts based on ad count

---

**See**: [AD_SYSTEM.md](./AD_SYSTEM.md) for complete documentation
