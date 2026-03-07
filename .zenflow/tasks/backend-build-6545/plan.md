# Auto

## Configuration
- **Artifacts Path**: {@artifacts_path} → `.zenflow/tasks/{task_id}`

---

## Agent Instructions

Ask the user questions when anything is unclear or needs their input. This includes:
- Ambiguous or incomplete requirements
- Technical decisions that affect architecture or user experience
- Trade-offs that require business context

Do not make assumptions on important decisions — get clarification first.

---

## Workflow Steps

### [x] Step: Implementation
<!-- chat-id: 49adff96-252e-4ca3-a088-f80b569620f9 -->

**Debug requests, questions, and investigations:** answer or investigate first. Do not create a plan upfront — the user needs an answer, not a plan. A plan may become relevant later once the investigation reveals what needs to change.

**For all other tasks**, before writing any code, assess the scope of the actual change (not the prompt length — a one-sentence prompt can describe a large feature). Scale your approach:

- **Trivial** (typo, config tweak, single obvious change): implement directly, no plan needed.
- **Small** (a few files, clear what to do): write 2–3 sentences in `plan.md` describing what and why, then implement. No substeps.
- **Medium** (multiple components, design decisions, edge cases): write a plan in `plan.md` with requirements, affected files, key decisions, verification. Break into 3–5 steps.
- **Large** (new feature, cross-cutting, unclear scope): gather requirements and write a technical spec first (`requirements.md`, `spec.md` in `{@artifacts_path}/`). Then write `plan.md` with concrete steps referencing the spec.

**Skip planning and implement directly when** the task is trivial, or the user explicitly asks to "just do it" / gives a clear direct instruction.

To reflect the actual purpose of the first step, you can rename it to something more relevant (e.g., Planning, Investigation). Do NOT remove meta information like comments for any step.

Rule of thumb for step size: each step = a coherent unit of work (component, endpoint, test suite). Not too granular (single function), not too broad (entire feature). Unit tests are part of each step, not separate.

Update `{@artifacts_path}/plan.md`.

### [x] Step: Resolve merge divergence and complete backend-build-6545 merge into origin/main
- Reconciled local/remote divergence constraints in worktree setup.
- Merged `backend-build-6545` into a branch based on `origin/main`.
- Pushed merge result to `origin/main` and verified ancestry.

### [x] Step: Launch crawl backend on Vercel and provide API base URL
- Added Vercel function adapter and routing for `/health`, `/api/v1/crawl`, and `/api/v1/webhooks/guesty`.
- Fixed serverless runtime write-path issue by setting crawler DB path to `/tmp/crawler.db` before backend import.
- Deployed successfully and validated health + crawl endpoints on production alias.

### [x] Step: Add Airbnb API source integration
- Added a new `AirbnbApiSource` and wired it into crawler source discovery.
- Plumbed `AIRBNB_API_BASE` and `AIRBNB_API_KEY` into crawler construction.
- Added unit tests for Airbnb API mapping/filtering and verified backend test suite passes.

### [x] Step: Replace Airbnb API with AirROI/SearchApi provider integration
- Replaced deprecated Airbnb API source with `AirbnbProviderSource` supporting `searchapi` and `airroi` providers.
- Added dedicated endpoint `/api/v1/airbnb/search` in both local server and Vercel Flask adapter.
- Added env support: `AIRBNB_PROVIDER`, `AIRBNB_API_KEY` (or `SEARCHAPI_API_KEY` / `AIRROI_API_KEY` fallback).
- Removed old source file, updated tests, redeployed, and verified `/api/v1/airbnb/search` returns 200.

### [x] Step: Build browser version of the app
- Created a standalone web UI in `web/` with search form, mode switch (crawl/airbnb), and clickable result cards.
- Wired browser requests to deployed backend endpoints (`/api/v1/crawl` and `/api/v1/airbnb/search`).
- Verified JavaScript syntax and smoke-tested backend endpoints used by the browser app.

### [x] Step: Launch browser app on Vercel
- Deployed `web/` as a standalone Vercel project.
- Confirmed production alias is live and serving the browser UI.

### [x] Step: Enhance crawl progress loading animation in browser UI
- Added a custom scan loader block with pulse/orbit animation and progress meter in `web/index.html` and `web/styles.css`.
- Wired phased, mode-aware progress updates in `web/app.js` during active crawl/API requests.
- Validated updated browser script syntax (`node --check web/app.js`).

### [x] Step: Add direct hunter feature to browser mode selector
- Added `Direct Hunter` as a dedicated search mode option in `web/index.html`.
- Wired `direct_hunter` mode in `web/app.js` to use crawl endpoint with stronger defaults (`crawl_depth`, `max_pages_per_source`, `whole_home`).
- Updated mode-specific phase messaging and source labels for direct hunter results.

### [x] Step: Deploy updated browser app to Vercel production
- Deployed `web/` with Vercel CLI and updated production alias.
- Verified alias `https://nopays-stays-web.vercel.app` is serving the updated UI.

### [x] Step: Enhance hunter results with image/cost enrichment and direct-only filtering
- Added backend enrichment fields (`image_url`, `image_description`, `estimated_cost`) and extraction heuristics for crawl results.
- Added direct-hunter OTA exclusion support via `exclude_ota` in crawl requests.
- Updated browser result rendering to show image, image description, and estimated stay cost when available.
- Enforced direct hunter filtering to suppress OTA domains (Airbnb/Booking/etc.) and validated with backend tests + JS syntax check.

### [x] Step: Push new branch and deploy latest backend/web to Vercel
- Created and pushed branch `feature/hunter-enrichment-direct-only` to origin.
- Deployed backend alias `https://directstay-crawl-api.vercel.app` and verified `/health` response is `{"status":"ok"}`.
- Deployed web alias `https://nopays-stays-web.vercel.app` and verified updated UI is live.

### [x] Step: Add provided background image to browser app
- Copied provided image asset into `web/background.jpg`.
- Updated `web/styles.css` body background to use the image with an overlay for readability.

### [x] Step: Replace browser background with updated provided image
- Copied updated provided asset into `web/background.png`.
- Updated `web/styles.css` background URL to use `background.png`.

### [x] Step: Deploy latest browser update to Vercel
- Deployed `web/` to production with Vercel CLI.
- Verified alias `https://nopays-stays-web.vercel.app` is serving successfully.

### [x] Step: Revert browser background to first provided image
- Updated `web/styles.css` background URL from `background.png` back to `background.jpg`.

### [x] Step: Deploy background revert to Vercel production
- Deployed `web/` to production with Vercel CLI after background reversion.
- Verified `https://nopays-stays-web.vercel.app` responds successfully.

### [x] Step: Add short description and price fields to search result cards
- Updated `web/app.js` result rendering to show labeled `Description` and `Price` fields with fallback values.
- Styled new result metadata rows in `web/styles.css`.
- Validated browser script syntax (`node --check web/app.js`).

### [x] Step: Deploy result card update to Vercel production
- Deployed `web/` to Vercel production after adding Description/Price fields.
- Verified alias `https://nopays-stays-web.vercel.app` responds successfully.

### [x] Step: Update background asset to f72481ee-9783-419d-91bb-ed3d29951a73.jpg
- Refreshed `web/background.jpg` using the provided source image from `.zenflow-images`.

### [x] Step: Add "Direct Hunt" action button after full search
- Updated `web/index.html` to place a `Direct Hunt` button beside `Full Search`.
- Wired `web/app.js` so clicking `Direct Hunt` sets mode to `direct_hunter` and submits the form.
- Updated button-state handling and styling in `web/app.js` and `web/styles.css`.
- Validated script syntax with `node --check web/app.js`.

### [x] Step: Add provided logos to header
- Copied provided logo assets into `web/logo-primary.png` and `web/logo-secondary.png`.
- Updated `web/index.html` header to render both logos above the title.
- Added responsive header-logo styling in `web/styles.css`.

### [x] Step: Add basic logo header bar and deploy
- Added a simple dedicated `brand-header` bar in `web/index.html` for logo display.
- Updated `web/styles.css` with basic header-bar styling and responsive logo spacing.
- Deployed web app to `https://nopays-stays-web.vercel.app` and verified response.

### [x] Step: Replace header with single provided logo
- Removed additional logo references and switched header to a single logo image in `web/index.html`.
- Added `web/logo-main.png` from the provided source and updated responsive logo sizing in `web/styles.css`.

### [x] Step: Refine and optimize existing search flow without adding capabilities
- Refactored `web/app.js` search flow into focused helpers (`executeSearch`, state handling, payload/default handling, endpoint resolution).
- Preserved existing functionality while improving robustness (safe response parsing and HTML escaping for rendered result fields).
- Kept Direct Hunt behavior unchanged and retained existing mode endpoints and filtering logic.
- Validated script syntax with `node --check web/app.js`.

### [x] Step: Parse each discovered result URL for results and direct hunter enrichment
- Updated crawler result generation to parse each individual result URL and extract page title, description, image details, and estimated cost.
- Added per-request enrichment cache to avoid duplicate parsing for repeated result URLs.
- Applied the same enriched result pipeline for standard results and Direct Hunter output.
- Updated crawler tests and validated with `PYTHONPATH=backend python3 -m unittest discover -s backend/tests`.
