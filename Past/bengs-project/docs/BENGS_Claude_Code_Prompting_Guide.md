# BENGS — Claude Code Prompting Guide (v2, updated for FRD v4.0)

You now have eight documents that are the source of truth. Claude Code hasn't seen any of them
yet, so the first job is getting them into its hands the right way — not dumping all eight into
one giant prompt.

| # | File | What it's for |
|---|------|----------------|
| 1 | `FRD_Pembuatan_Aplikasi_BENGS.docx` (v4.0) | Functional requirements, Req IDs (e.g. `SCHED-02`), business rules, data model |
| 2 | `BENGS_UIUX_Screen_Spec.docx` (v1.0) | Every screen, its fields/states/nav, Screen IDs (e.g. `SCHED-S04`) |
| 3 | `BENGS_App_Mockup.html` | **Interactive** visual/behavior reference, 58 screens, real navigation and state. Replaces the earlier static `BENGS_Design_Reference.html` — don't keep both in the repo, the static one has bugs (mismatched Quick/Scheduled forms, floating nav bars) that are already fixed here. |
| 4 | `BENGS_Route_Matching_Algorithm.md` (v2.0) | Single-passenger O(n²) insertion algorithm — full pseudocode. Not Held-Karp DP; that was considered and dropped. |
| 5 | `BENGS_Cool_Friend_Scoring.md` | Cool Person/Cool Friend scoring rubric, weights, privacy-gating rule |
| 6 | `BENGS_Landing_Page_Copy.md` | Hero/how-it-works/CTA copy — no code dependency, hand off any time |
| 7 | `20260908000000_design_pass_deltas.sql` | Migration: KYC/vehicle/beng columns the design pass surfaced |
| 8 | `20260908000100_lookups_mutual_cron_overlap.sql` | Migration: lookup tables, materialized `is_mutual`, `pg_cron` auto-reject, overlap trigger |

---

## Step 0 — Put the docs where Claude Code can find them, and update CLAUDE.md

Copy all eight files into the repo (`docs/` for the six non-SQL files, `supabase/migrations/` for
the two `.sql` files, in that filename order — `...000000...` before `...000100...`). Then
**rewrite `CLAUDE.md`** so every future session picks this up automatically. Add a block like:

```md
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
```

This one step is what prevents every future Claude Code session from re-litigating decisions you
already made.

---

## Step 1 — Audit before writing any code (re-run this, don't skip it even if you did it before)

If Claude Code already did a gap-report pass against FRD v3.0, that report is now stale — v4.0
changed six real things (auto-reject mechanism, overlap enforcement, `max_eta`'s meaning,
`is_mutual`, three lookup tables, the route-matching algorithm entirely). Re-run:

> Read docs/FRD_Pembuatan_Aplikasi_BENGS.docx (v4.0), docs/BENGS_Route_Matching_Algorithm.md (v2.0), and docs/BENGS_Cool_Friend_Scoring.md. Then go through the current codebase and produce a gap report: for each Req ID in the FRD's §6, state whether it's (a) implemented and correct, (b) implemented but contradicts the FRD, or (c) not implemented at all. Specifically call out anywhere the code assumes `max_eta` is a duration, computes friend mutuality on the fly instead of reading `is_mutual`, uses free-text vehicle brand/model instead of the lookup tables, or implements/plans Held-Karp DP for routing. Don't fix anything yet — just report.

---

## Step 2 — Fix/build in small, scoped passes, not one mega-prompt

Updated order — route-matching and scoring moved up because they're small, self-contained, and
easy to unit-test in isolation before wiring them into any screen:

1. **Run both migrations** against a dev Supabase project, in filename order. Verify `pg_cron` is actually active afterward (dashboard, not just migration success).
2. **Route-matching v2** (`insertPassenger`, O(n²)) — implement and unit-test as a pure function first, per `BENGS_Route_Matching_Algorithm.md`'s implementation notes. No UI wiring yet.
3. **Cool Person/Cool Friend scoring** — implement server-side per `BENGS_Cool_Friend_Scoring.md`, respecting the privacy-gating rule. Unit-test with a pair of profiles where fields are deliberately set to `cool_friends`-only, and confirm those fields are excluded from the score.
4. **Auth corrections** — remove Facebook, confirm only email/Google/phone remain (`AUTH-01`, `AUTH-S03/S04/S08`)
5. **Vehicle picker + brand/model lookup + Add-a-Beng distance/latest-arrival fields** (`VEH-01`, `SCHED-02`, `SCHED-S04`) — note `arrival_time` is the existing column, re-gated, not a new one
6. **Repeat pattern sub-flow** (`SCHED-S06`–`S09`)
7. **Filter/Sort sliders** (`FIND-02`, `FINDS-S03`)
8. **WhatsApp gating + cool tags display** (`WA-01`, `SOC-S06`) — now backed by real scoring (step 3) and materialized `is_mutual`, not placeholders
9. **Settings additions** (`PROF-S09`)
10. **Quick Beng** end-to-end (`SPN-01`–`SPN-07`, `FINDQ-S01`–`S03`) — reuses the same accordion component as Add-a-Beng (`SCHED-ACC`/`QUICK-S01` share one implementation in the mockup; build it that way in Flutter too, not as two divergent forms)
11. **KYC/Vehicle verification flow** (`KYC-01`–`KYC-06`, `VEH-S01`–`S05`), including disability-type lookup
12. **Admin review queues** (`ADM-01`–`ADM-03`)

Template prompt per step:

> Implement `[area name]` per FRD §6 Req IDs `[list]` and UI/UX spec Screen IDs `[list]`. Reference docs/BENGS_App_Mockup.html's `[SCREEN-ID]` screen for layout/colors/state behavior — match it, don't port its HTML/JS literally, this is Flutter. If anything in the current codebase conflicts with these docs, fix it and tell me what changed.

---

## Step 3 — Guardrails worth stating once, not per-prompt

Put these in CLAUDE.md too:

- **Flutter, not HTML.** The mockup is a cross-platform visual/behavior spec, not markup to translate line-by-line. Use it for hex values, layout proportions, field ordering, and interaction states (accordion single-open, locked-until-prerequisites fields) — not for literal divs.
- **RLS-first.** Every new table/column touched (including the new lookup tables) should be checked against existing Supabase RLS policies before writing client code that reads/writes it.
- **One algorithm, not two.** Route-matching is single-passenger O(n²) insertion, full stop. Don't implement Held-Karp "for later" — it was evaluated and deliberately rejected, not deferred.
- **Privacy-gating in scoring is not optional.** Cool Person scoring must check `profile_visibility` before using a field — this was a real design decision (most matching signals are invisible to non-friends by default), not an edge case to skip for MVP.
- **Don't invent business logic.** If a screen needs a decision neither the FRD nor these docs cover, stop and ask rather than guessing.
- **One Req ID area per session where possible.** Resist "while I'm in here" scope creep — it's exactly how the codebase got messy the first time.

---

## Open items — none blocking implementation anymore

The `max_eta` duration-vs-timestamp question that used to block Step 2 has been resolved
(absolute timestamp, reusing `arrival_time`) and is reflected throughout FRD v4.0 and the
migration. The one remaining non-blocking item: `indonesia_region` (the neighbourhood lookup) has
its table structure but no data — populating ~83,000 kelurahan/desa rows is a separate data-import
task (source from an open Kemendagri/BPS administrative-region dataset). `PROF-02`'s neighbourhood
field will work mechanically before that import runs, it'll just have an empty dropdown — fine to
build the UI first and backfill data before shipping to real users.
