# NoPays Stays — Automated Direct Booking Hunter

## Core Purpose

Remove the manual effort of finding direct holiday bookings. The app hunts 30+ sources automatically — you just set your criteria, hit hunt, and the app walks you through each platform in-app until you've checked them all.

## Features

- [x] **Deep search by criteria** — Location (MapKit autocomplete), dates, guests, bedrooms, bathrooms, pet-friendly, whole-home, max price, search radius
- [x] **Multi-platform link generation** — ~30 targeted search URLs across alternative platforms, classifieds, search engines, social media, forums, and tourism directories
- [x] **Auto-Hunt mode** — Automatically opens each unchecked source in-app via SFSafariViewController; close the browser to advance to the next source
- [x] **In-app browser** — All links open inside the app (SFSafariViewController) so you never leave the app
- [x] **Progress tracking** — Visual progress bar and per-link checkmarks showing which sources you've reviewed
- [x] **Categorized results** — Grouped by: Direct Booking, Alternative Platforms, Classifieds, Search Engines, Social & Forums, Tourism Directories
- [x] **OTA exclusion queries** — Google/Bing/DuckDuckGo deep queries excluding Airbnb, Booking.com, Expedia to surface owner-direct listings
- [x] **Save finds** — Bookmark links found during hunting, with title, platform, URL, price, and notes
- [x] **Search history** — Re-run past searches with one tap, persisted locally
- [x] **Platform fee indicators** — Each link shows fee percentage (0% for direct, varies for others)

## Design

- **Warm sunset palette** — Burnt orange/coral with warm amber, dusty purple accents
- **MeshGradient hero** — Animated mesh gradient on search screen
- **Category color coding** — Green = direct booking, orange = alternative, amber = classifieds, coral = search engines, purple = social, blue = tourism
- **Hunt progress bar** — Green progress bar at top of results showing completion
- **Checked state dimming** — Reviewed links fade to show progress visually
- **Haptic feedback** — On hunt launch, save, copy, completion
- **Spring animations** — Staggered list loading

## Screens

1. **Search** — Criteria input with MeshGradient header, "Hunt Direct Bookings" action
2. **Hunt Results** — Auto-Hunt button, progress tracking, categorized links with in-app browser, save/copy/mark actions
3. **Saved Finds** — Bookmarked links with in-app browser opening
4. **History** — Past searches with one-tap re-run
5. **Settings** — Stats, how-it-works, platforms list

## Tab Bar

- **Search** (magnifying glass) — Criteria input + hunt
- **Saved** (bookmark) — Bookmarked finds
- **History** (clock) — Past searches
- **Settings** (gear) — Info & stats

## Platforms Searched

### Direct Booking (2+)
Owner contact finder, owner microsite finder

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

## Data

- All search link generation happens on-device — no backend required
- Local persistence for search history and saved finds using UserDefaults
- MapKit autocomplete for Australian location search
- In-app browsing via SFSafariViewController
