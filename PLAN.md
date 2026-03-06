# NoPays Stays — Find Direct Holiday Rentals & Skip the Fees

## Features

- **Search by location** — Type an Australian town, suburb, or postcode and set dates, guest count, and filters (pet-friendly, whole home, etc.)
- **Interactive map view** — Browse properties on a map with color-coded pins: green = direct booking available, amber = alternative platform only (e.g. Stayz), red = mainstream OTA only
- **Price comparison cards** — Each property shows the OTA price vs. the cheapest alternative, with a savings badge (e.g. "Save 28%")
- **Property detail screen** — Full photo gallery, amenities, all booking links ranked by price, and extracted owner contact info (phone/email) when available
- **Saved searches** — Save location + filter combos and get notified when new direct-booking properties appear
- **Favorites collection** — Heart properties to save them for later, organized in a personal collection
- **Alerts feed** — A notification-style feed showing new high-value drops matching your saved searches
- **Filter chips** — Quick filters for property type, guest count, pet-friendly, price range, and "direct booking only"

## Design

- **Warm sunset palette** — Primary accent in burnt orange/coral transitioning to warm amber, with a dark background option using deep navy/charcoal for contrast
- **MeshGradient hero** — The search screen uses a subtle animated mesh gradient in sunset tones (peach → coral → amber → soft purple) as a background behind the search bar
- **Photo-forward property cards** — Large hero images with a gradient overlay at the bottom showing property name, location, price, and savings badge
- **Map + bottom sheet layout** — The Explore tab shows a full-bleed map with a draggable bottom sheet listing properties (Apple Maps style)
- **Color-coded map pins** — Custom map annotations: green circle = direct/owner booking, amber = alternative platform, red = OTA only
- **Savings badges** — Bold green pill badges showing percentage saved vs. mainstream OTA price
- **Warm typography** — SF Pro with bold weights for headlines, creating a premium travel-app feel
- **Haptic feedback** — Subtle haptics when favoriting, filtering, and receiving new alerts
- **Spring animations** — Bouncy card reveals, smooth sheet transitions, and staggered list loading

## Screens

1. **Explore (Map + List)** — Full-screen map with property pins, draggable bottom sheet with scrollable property cards, filter chips at top
2. **Search** — Location input with autocomplete, date picker, guest stepper, filter toggles (pet-friendly, whole home, direct only), beautiful sunset mesh gradient background
3. **Property Detail** — Hero image carousel, price comparison table (OTA vs. alternatives), amenities grid, "Book Direct" prominent button, owner contact section, share button
4. **Favorites** — Grid of saved properties with photo cards, swipe-to-remove, empty state with illustration
5. **Alerts** — Timeline feed of new property discoveries matching saved searches, each with photo thumbnail, savings highlight, and direct link
6. **Settings** — Notification preferences, saved searches management, about section

## Tab Bar

- **Explore** (map pin icon) — Map + property list
- **Search** (magnifying glass) — New search with filters
- **Favorites** (heart) — Saved properties
- **Alerts** (bell with badge) — New discoveries feed
- **Settings** (gear) — Preferences

## Data

- The app connects to your external Vercel backend API for all property data, search, and alerts
- Local persistence for favorites and saved searches using on-device storage
- Mock/sample data included so the app is fully functional for demo before the backend is connected

## App Icon

- Sunset gradient background (coral to amber to soft purple) with a white house silhouette and a subtle price-tag or checkmark overlay — communicating "find your stay, skip the fees"
