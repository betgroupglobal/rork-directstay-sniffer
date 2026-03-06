# NoPays Stays — Deep Search Tool for Direct Holiday Rentals

## Features

- **Deep search by criteria** — Enter location (with MapKit autocomplete), dates, guests, bedrooms, bathrooms, pet-friendly, whole-home, max price, and search radius
- **Multi-platform link generation** — Generates ~30 targeted search URLs across alternative platforms, classifieds, search engines, social media, forums, and tourism directories
- **Categorized results** — Results grouped by: Direct Booking, Alternative Platforms, Classifieds, Search Engines, Social & Forums, Tourism Directories
- **OTA exclusion queries** — Google/Bing/DuckDuckGo deep queries that exclude Airbnb, Booking.com, Expedia etc. to surface owner-direct listings
- **Save finds** — Bookmark interesting links found during hunting, with title, platform, URL, price, and notes
- **Search history** — Re-run past searches with one tap, persisted locally
- **Platform fee indicators** — Each platform link shows its fee percentage (0% for direct, varies for others)

## Design

- **Warm sunset palette** — Primary accent in burnt orange/coral transitioning to warm amber, with dusty purple accents
- **MeshGradient hero** — Animated mesh gradient in sunset tones on the search screen
- **Category color coding** — Green = direct booking, orange = alternative platform, amber = classifieds, coral = search engines, purple = social, blue = tourism
- **Warm typography** — SF Pro with bold weights for headlines
- **Haptic feedback** — Subtle haptics on search launch, copy URL, save actions
- **Spring animations** — Staggered list loading in history and saved finds

## Screens

1. **Search** — Location input with autocomplete, date picker (optional), guest/bedroom/bathroom steppers, pet-friendly & whole-home toggles, max price, radius — MeshGradient header
2. **Search Results** — Categorized platform links with expand/collapse, each link opens in Safari with context menu (open, save, copy URL)
3. **Saved Finds** — List of bookmarked links found during hunting, swipe-to-delete, manual add
4. **History** — Past searches with one-tap re-run, swipe-to-delete, clear all
5. **Settings** — Search stats, how-it-works guide, platforms list, about

## Tab Bar

- **Search** (magnifying glass) — Criteria input + deep search
- **Saved** (bookmark) — Bookmarked finds
- **History** (clock) — Past searches
- **Settings** (gear) — Info & stats

## Platforms Searched

### Alternative Platforms (9)
Stayz, Vrbo, OwnerDirect, Youcamp, Riparide, Holidaypaws, Hometime, Holiday Houses, Fairbnb

### Classifieds (4)
Gumtree, Facebook Marketplace, Domain Holiday, REA Holiday

### Search Engines (7)
Google deep queries (direct booking, owner direct, local agents, pet-friendly, no-OTA filter), Bing, DuckDuckGo

### Social & Forums (3)
Facebook Groups, Reddit, Whirlpool Forums

### Tourism Directories (5)
Visit NSW, Visit Victoria, Queensland.com, WA Tourism, Local Council directories

### Direct Booking (2+)
Owner contact finder, owner microsite finder

## Data

- All search link generation happens on-device — no backend required
- Local persistence for search history and saved finds using UserDefaults
- MapKit autocomplete for Australian location search
