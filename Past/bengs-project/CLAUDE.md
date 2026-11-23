# BENGS — Project Brief for Claude Code

*Drop this file as `CLAUDE.md` in your project root. Claude Code reads it automatically for persistent context, so you shouldn't need to re-explain any of this.*

## What this app is

BENGS is a social carpooling app for Jakarta — "nebeng" (Indonesian: tag along for a ride) between people who mostly already have some social connection, not anonymous ride-hailing. Two roles: **Driver** (posts a route, offers seats) and **Passenger** (requests to join). Honest competitive context: this product category already exists in Indonesia (Nebengers since 2011, NEBENG.com since 2005, NebengAja recently) — the differentiator is engineering depth (real route optimization, verified schema, social-trust-first matching) and specific new features (see Spontaneous Home below), not category novelty. Don't oversell "first of its kind" anywhere in copy or docs.

## Source material

- `bengs01.pdf` — the ORIGINAL 23-screen design (splash, onboarding, auth, calendar/list home, Add-a-Beng, Find-a-Beng, beng detail/review, notifications, friends, profile, account). This predates every decision below — treat it as the starting visual language (colors, layout patterns), not the final spec.
- Verified brand colors, sampled directly from the design at 300dpi: primary blue `#1D5BFE`, icon blue `#153DB9`, amber `#E0A800`/`#FAC829`, map pin red `#FF383D`, navy text `#0F1330`, sheet lavender `#E7ECFF`.

## Planning documents (source of truth, Sep 2026 restart — FRD v4.0)
- docs/FRD_Pembuatan_Aplikasi_BENGS.docx — functional requirements. Req IDs
  (AUTH-01, SCHED-02, REQ-05, etc.) are canonical; cite them in commits/PRs.
- docs/BENGS_UIUX_Screen_Spec.docx — screen-by-screen spec. Screen IDs
  (AUTH-S04, SCHED-S04, etc.) map 1:1 to the FRD's Req IDs.
- docs/BENGS_App_Mockup.html — interactive visual/behavior reference, 58
  screens. Open it in a browser, or read the source directly for exact hex
  values and state logic (e.g. the accordion in reg('SCHED-ACC', ...) opens
  only one cell at a time — replicate that behavior, not just the div
  structure). It's a cross-platform mockup, NOT a port target — build real
  Flutter widgets/state, don't translate the HTML/JS literally.
- docs/BENGS_Route_Matching_Algorithm.md — the ONLY route algorithm to
  implement. Single-passenger O(n²) insertion. Do not implement Held-Karp
  or any full-route DP — it was deliberately dropped, not a stepping stone.
- docs/BENGS_Cool_Friend_Scoring.md — scoring rubric for SOC-03. Respect the
  privacy-gating rule inside it: a field only counts toward a non-friend's
  score if BOTH users have it set to public visibility.
- docs/BENGS_Landing_Page_Copy.md — landing page copy, ready to use as-is.
- supabase/migrations/20260908000000_design_pass_deltas.sql and
  20260908000100_lookups_mutual_cron_overlap.sql — run in that order against
  a DEV Supabase project first, not production. The second one needs the
  pg_cron extension enabled — verify via Database → Extensions in the
  Supabase dashboard, don't assume the migration alone turns it on.

These supersede any earlier notes, mockups, or assumptions already in this
codebase — including an earlier static BENGS_Design_Reference.html if it's
still in the repo; delete it, don't keep it alongside the interactive one.
If existing code contradicts these docs (e.g. shows a Facebook login
button, treats max_eta as a duration, computes is_mutual on the fly,
recommends Held-Karp), the docs win — flag the conflict and fix the code,
don't silently keep both.

## Guardrails from the FRD v4.0 restart

- **Flutter, not HTML.** The mockup is a cross-platform visual/behavior spec, not markup to translate line-by-line. Use it for hex values, layout proportions, field ordering, and interaction states (accordion single-open, locked-until-prerequisites fields) — not for literal divs.
- **RLS-first.** Every new table/column touched (including the lookup tables) should be checked against existing Supabase RLS policies before writing client code that reads/writes it.
- **One algorithm, not two.** Route-matching is single-passenger O(n²) insertion, full stop. Don't implement Held-Karp "for later" — it was evaluated and deliberately rejected, not deferred.
- **Privacy-gating in scoring is not optional.** Cool Person scoring must check `profile_visibility` before using a field — this was a real design decision (most matching signals are invisible to non-friends by default), not an edge case to skip for MVP.
- **Don't invent business logic.** If a screen needs a decision neither the FRD nor these docs cover, stop and ask rather than guessing.
- **One Req ID area per session where possible.** Resist "while I'm in here" scope creep.

## Stack (decided, don't re-litigate)

- **Frontend:** Flutter (one codebase, iOS + Android)
- **Backend:** Supabase (Postgres + Auth + Storage + auto-generated API + Row Level Security). NOT Laravel — that was considered and deliberately dropped in favor of Supabase to avoid running/maintaining a separate server as a solo builder.
- **Database naming:** snake_case in Postgres (`user_id`, `created_at`), camelCase in Dart (`userId`) via explicit `fromJson`/`toJson` — Postgres lowercases unquoted identifiers, so camelCase in the DB itself is fragile. This is a boundary conversion, not an inconsistency.
- **Routing/maps:** OpenRouteService or Geoapify free tier for MVP; OSRM self-hosted if it ever outgrows free tier. Not Google Maps routing (cost), though Google's map-tile/autocomplete free tier is fine if visual polish matters later.

## Database — already built and verified

Full schema: `BENGS_supabase_schema.sql` (15 tables, UUID primary keys, RLS enabled). This was loaded into a real local Postgres 16 instance and verified with actual inserts — trigger-based `updated_at`, cascading deletes through `auth.users`, JSONB recurrence fields, and duplicate-rating rejection all confirmed working, not just written and assumed correct. Use this file as-is; don't regenerate it from the PDF.

Key structural decisions baked into it:
- `profiles` extends Supabase's own `auth.users` — no separate password/session tables (Supabase Auth handles that entirely)
- `driver_verification` (KYC/KTP data) is a **separate table from `profiles`**, RLS-locked to be visible only to its owner — passengers never carry or see driver-only data
- `parental_consent` table for minors 13–17, RLS-locked to its owner
- `beng.mode` distinguishes `scheduled` vs `spontaneous` (see Spontaneous Home below)
- Recurrence (`repeat_frequency`, `repeat_weekdays`, `repeat_month_days`, `repeat_months`, `repeat_ordinal` — all JSONB) matches the **native iOS Reminders/Calendar recurrence pattern** exactly (Repeat list → Custom screen → Frequency + Every N + a multi-select whose shape depends on frequency: weekdays for Weekly, dates for Monthly, months + optional ordinal-weekday for Yearly). This was reverse-engineered from an actual screen recording, not guessed.
- `passenger_rating`/`driver_rating` are tied to a specific `beng_daily_id` (a specific completed ride) with a uniqueness constraint — the original design let ratings float free with no ride reference; this was a deliberate fix.
- `beng.max_passenger` is a **concurrent-seat cap, not a per-trip headcount cap** — a 2-seat car can serve 3+ distinct passengers on one route as long as no two are in the car simultaneously (A picked up → A dropped off → B picked up). Route-building logic must track running occupancy at each stop, not just total passengers.

## Business rules (resolved — apply to every screen/feature, not just new ones)

| ID | Rule |
|---|---|
| BR-01 | Driver minimum age: 18 |
| BR-02 | Passenger minimum age: 13, with parental consent required under 18 |
| BR-03/04 | KYC (KTP + selfie) required ONLY to unlock Driver mode — browsing/requesting as Passenger never requires it, even for minors |
| BR-05 | Because of BR-03, minors are gated by parental consent, not document verification |
| BR-06 | Both motor (motorcycle) and mobil (car) supported at launch — not phased |
| BR-07 | No in-app payment. Do not add a payment-method field anywhere. Settlement happens via WhatsApp after matching. |
| BR-08 | Auth providers: email, Google, Apple, phone. No Facebook — remove it from any screen that still shows it (the original design does). |
| BR-09 | See max_passenger note above |
| BR-10 | Reject (never agreed, no reason needed) / Cancel (unwinding an already-accepted deal, needs reason + confirmation) / Delete (driver removes the whole beng or a day of it) are three distinct actions with distinct UI, not one "cancel" button |
| BR-11 | WhatsApp deep-link handoff for MVP. In-app chat is an explicit fast-follow, not MVP scope. |

## Required changes to the original 23-screen design

**Remove:**
- "Continue with Facebook" from Log In / Sign Up (BR-08)
- Any implied payment-method field (BR-07)

**Add (net new, don't exist in the original 23 screens):**
- Date-of-birth field in Sign Up (top-level, independent of any later KTP scan — needed because passengers never do KYC per BR-03, so age-gating can't rely on KTP data)
- Age-gate / parental-consent screen, triggered inline during signup when DOB indicates under 18 (see mockup already built — matches BR-02/05)
- The KYC/KTP screen must be re-scoped: only reachable when a user opts into Driver mode (e.g., taps "Offer a ride"), never a universal onboarding step
- Vehicle field in Add-a-Beng must be an explicit Motor/Mobil selector pulling from saved vehicles, not free text "Car" (BR-06 — mockup already built)
- Repeat field must follow the iOS-style Repeat-list → Custom-screen pattern described above, not a single dropdown (mockup already built)
- **New "Home" tab** — a genuinely new feature, not a revision: a spontaneous, on-the-spot "find a ride now" / "offer a ride now" screen (map + role toggle + bottom sheet), replacing the current 4-tab bottom nav with 5 tabs (Schedule / Friends / **Home, center, visually elevated** / Inbox / Profile). The old Home (calendar/list) becomes the "Schedule" tab — same content, just relabeled. Full functional requirements (FR-SPN-01 through FR-SPN-20) are in the FRD; ask for that file's content if Claude Code needs the detail level.

**Unchanged, carry over as-is:** splash, onboarding, forgot password, verify OTP, Find-a-Beng/Search-the-Bengs, beng detail + route views, Friends, the accept/reject "Reviewing" screens, Notification, profile, Account/Settings.

## Flutter code already built and verified

A working Home tab (Find/Offer toggle, map placeholder, bottom sheet forms) already exists — brace-balance and import-path checked, though not run through an actual `flutter analyze` (no Flutter SDK was available in the sandbox it was built in). Structure:
```
lib/
  main.dart
  theme/app_colors.dart
  models/home_mode.dart
  models/leave_within_option.dart
  widgets/main_scaffold.dart          (5-tab nav, elevated center Home button)
  widgets/beng_map_placeholder.dart   (stand-in map — swap for a real map package here)
  screens/home/home_tab.dart
  screens/home/widgets/find_ride_sheet.dart
  screens/home/widgets/offer_ride_sheet.dart
```
All backend calls in this code are `TODO` + `debugPrint` stubs — wiring these to real `supabase_flutter` calls is the next concrete step, not a redesign.

## Route-matching algorithm (backend logic, not yet implemented in code)

- v1: cheapest-insertion heuristic + 2-opt local search (polynomial, "good enough," matches the existing 10-minute recompute cooldown already specified)
- v2 (fast-follow): exact Held-Karp DP — legitimately tractable since stops per route are capped under 10
- Benchmark whichever gets built against Google OR-Tools' pickup-and-delivery solver as a sanity check, not as the production dependency

## What NOT to do

- Don't reintroduce Laravel, custom auth tables, or session tables — Supabase Auth replaces all of that
- Don't add payment processing (BR-07)
- Don't build in-app chat (BR-11 — WhatsApp only for now)
- Don't claim novelty for the core carpooling concept anywhere in user-facing copy or research write-ups — the honest differentiators are the engineering (real schema, real algorithm) and specific features (Spontaneous Home, social-trust-first matching), not "first app of its kind"

## Suggested execution order

1. Create Supabase project, run `BENGS_supabase_schema.sql`
2. Wire `supabase_flutter` into the existing Home tab's stub callbacks
3. Build the remaining screens per the "required changes" list above, reusing the original design's visual language (colors above) for anything not explicitly called out as changed
4. Implement the v1 route-matching heuristic
5. Everything else (ratings polish, friends, notifications, in-app payments/chat) is explicitly post-MVP
