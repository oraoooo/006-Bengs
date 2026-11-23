# change01.md v1

## current:
1. check on the data structure and how to use it with database
2. ⁠use valhala, OR, and gmaps interface

## expand:
1. allow them to have flexibility by walking beforehand and afterhand
2. ⁠despite having small amount of similar route, shows other possibilities if: they went 30 min earlier atleast or walk 1 km more atleast from origin or destination
3. ⁠shareable link/route, can set public unlisted or private to invite people join beng, then the person create a request afterwards (auto join)
4. ⁠allow to find public bengs without searching, then proceed to create request based on it
5. allow to edit request
6. ⁠allow to create restrictions on the route (avoid tolls, highways, etc)
7. ⁠if there are two bengs in which they could be merge together alongside with the passenger, notify the drivers, and let them become cool friends


# change01.md v2 — Expansion Features, Implementation-Ready

Supersedes change01.md v1 for this feature batch. This document is self-contained: flow, module
ownership, data model, and screen notes are all here so this batch can be implemented WITHOUT
editing FRD_Pembuatan_Aplikasi_BENGS.docx, BENGS_UIUX_Screen_Spec.docx, or BENGS_App_Mockup.html.
New Req IDs here (`EXP-01` etc.) are a separate numbering track from the FRD's existing IDs —
don't renumber anything in the FRD to make room for these.

**Ground rule for all of this: additive only.** Every migration adds columns/tables; nothing here
redefines what an existing column means. Every new capability is either a new microservice or new
application logic against Supabase — never a code change forced onto the Matching Service
(`BENGS_Route_Matching_Algorithm.md`) or the Routing/Safety services described in
`BENGS_Routing_Microservices_Architecture.md`. That's what keeps this expandable instead of a
rewrite each time.

---

## ⚠️ Status: none of this is built yet — this is the plan for AFTER current MVP ships

To be completely explicit, since this document exists precisely to avoid ambiguity later: **the
current FRD-scoped MVP (FRD v4.1, UIUX v2.0, BENGS_App_Mockup.html) is what's being implemented
right now, on today's stack** — Flutter + Supabase + ORS only, no self-hosted routing engines, no
microservices, no H3/OR-Tools/Redis/Overpass anywhere in the codebase. Nothing in this document
should be started before that ships. This file exists so that when you *do* come back to this
batch, the planning work is already done — not so it gets pulled forward into the current sprint.

## New Tools Inventory — what's genuinely new, and when it's actually needed

Corrected from the earlier architecture doc, which over-scoped a few items. Sorted by whether
today's stack (Flutter + Supabase + ORS) already covers it:

| Tool | Needed for | New tool, or already have it? |
|---|---|---|
| ORS isochrones + avoid_features | EXP-01, EXP-06 | **Already have it** — same ORS integration in use today, just different API calls on it. No new infrastructure. |
| Additive Supabase columns/tables (this doc's SQL snippets) | EXP-01, EXP-03/04, EXP-05, EXP-08 | **Already have it** — same Supabase project, same migration pattern already established (`...000000` through `...000200`). |
| **H3** (Uber's spatial indexing library) | EXP-02, EXP-07 only | New — but it's a plain library, not a service. No hosting cost, just a dependency. |
| **Interval trees** (time-window overlap) | EXP-02, EXP-07 only | New — a data structure you implement/import, not a service. No hosting cost. |
| **OR-Tools** (Google's VRP solver) | EXP-07 only (merge feasibility) | New — self-run library, free, but this is the one place a *real* combinatorial solver is justified (deciding whether to merge two independent routes is harder than single-passenger insertion). |
| **Discovery Engine** (new microservice housing the three above) | EXP-02, EXP-07 | New service to stand up — see architecture note below on language choice. |
| **Self-hosted Overpass API** | Optional polish on EXP-01 (safe meeting points), not required for v1 | New, and deferrable — don't build this until the ORS-only version of EXP-01 is live and you've decided the safety-filter layer is worth adding. |
| **Self-hosted OSRM/Valhalla** | Only if ORS's free-tier volume is actually exceeded once Discovery Engine is running (higher query volume than the current per-request MVP pattern) | New, and conditional — don't pre-provision this; ORS may simply remain sufficient even with Discovery Engine running, since Discovery Engine's own H3 pre-filter is specifically there to keep the number of expensive routing calls small. |
| **Redis** | Only if Discovery Engine becomes a continuously-running service across multiple workers, rather than a periodic batch job | New, and deferrable — a first Discovery Engine can be a `pg_cron`-triggered hourly batch job (EXP-07's merge scan) with no live index at all. |
| **Docker / docker-compose** | Packaging the Discovery Engine (and later, Overpass/OSRM/Valhalla if those become needed) | New, but standard — every tool above ships an official Docker image. |

**One practical note on language/runtime:** H3 and OR-Tools both have their most mature, best-
documented bindings in Python (and reasonably good ones in Node). The Discovery Engine should
almost certainly be a small Python (or Node) service, not Dart — there's no reason to fight for
Flutter/Dart bindings to these libraries when the service is backend-only and never touches the
Flutter client directly (it only talks to Supabase and gets called by the Matching Service or a
scheduled job).

**Bottom line on cost, restated for this expanded scope:** EXP-01 through EXP-06 and EXP-08 need
zero new infrastructure — they're built entirely on what you already have. Only EXP-02 and EXP-07
(the Discovery Engine batch) introduce anything new to host, and even then, H3/OR-Tools/interval-
trees themselves are free libraries — the only real new spend is a small VPS for the Discovery
Engine container, sized modestly (a periodic batch job, not a live high-traffic service) unless
usage proves otherwise.

---

## Sequencing (unchanged from prior recommendation, restated for completeness)

| Order | Item | Why here |
|---|---|---|
| 1 | EXP-06 (route restrictions) | Cheapest — an existing ORS parameter, no new tool at all |
| 2 | EXP-01 (walk flexibility, two sliders) | Cheap — existing ORS isochrones, no new tool at all |
| 3 | EXP-08 (recommended route revert) | Small — one column, zero new tools, pure Matching Service + app logic |
| 4 | EXP-05 (edit approved request) | Small, app-level only |
| 5 | EXP-03 + EXP-04 (shareable links + public feed) | One decision needed (below), then straightforward |
| 6 | EXP-02 (near-miss discovery) | First item needing the Discovery Engine to exist |
| 7 | EXP-07 (merge detection) | Needs the Discovery Engine; build last, on real usage data |

---

## EXP-06 — Route Restrictions (avoid tolls/highways)

**Correction from the prior architecture doc: this needs NO new tool.** ORS's existing Directions
API already supports `options.avoid_features` (`highways`, `tollways`, `ferries`) — this is a
parameter on the exact API call you're already making, not a reason to stand up self-hosted
OSRM/Valhalla. Build this entirely against today's ORS integration.

**Flow:** Driver, in the Distance cell of SCHED-ACC (or QUICK-S01), sees two new toggles: "Avoid
tolls" / "Avoid highways." Toggling either re-calls ORS's existing directions/matrix call with the
`avoid_features` parameter set, which changes the ORS-lowerbound values shown in Max Distance /
Latest Arrival.

**Module:** Matching Service only (today's existing Flutter+Supabase+ORS call path). No new
service, no new table beyond two booleans.

**Data model (additive):**
```sql
alter table beng add column if not exists avoid_tolls boolean not null default false;
alter table beng add column if not exists avoid_highways boolean not null default false;
```

**Screen note (no UIUX doc edit needed):** Add two toggle rows inside the existing "Distance"
cell's expanded body in SCHED-ACC/QUICK-S01 (the accordion cell already described in UIUX v2.0
§3.4) — this is a field addition inside an existing cell, not a new screen or cell.

**Design note:** Toggles use the same visual pattern as the existing WhatsApp-reachability toggle
in Settings (PROF-S09) — reuse that component, don't invent a new toggle style.

---

## EXP-01 — Flexible Walking, Two Independent Sliders (revised)

**Revision note:** the original spec used one combined time-based tolerance (chips: 0 / 0–5 /
5–10 min). Replaced per updated direction: **two independent distance sliders** — how far the
passenger is willing to walk from their true origin to the pickup point, and separately, from the
drop-off point to their true destination. These are deliberately decoupled: someone might happily
walk further leaving home (no time pressure) but want dropping off closer to work (arriving neat,
on time) — or the reverse. One combined value can't express that asymmetry.

**Also needs no new tool for a first version.** ORS's isochrones endpoint (same API family as the
avoid-features call above) can generate the walking reachability area directly — the fuller
Overpass "safety filter" (snapping to an actual bus stop / marked crossing rather than an
arbitrary road point) is a real quality improvement but is a **separable, deferrable layer**, not
a hard requirement for v1. Ship the ORS-only version first; add Overpass later as polish once
you've confirmed people actually use the walk-flexibility feature enough to justify it.

**Flow:** Passenger, when requesting a beng (FINDS-S04) or driver when publishing one
(SCHED-ACC), sees two sliders: "Walk to pickup" and "Walk from drop-off," each 0–2 km (tune the
max once you see real usage). Matching Service calls ORS's isochrone endpoint for each true
address, and treats any point within that reachable area as a valid insertion target instead of
requiring exact door-to-door — potentially saving the driver a detour.

**Module:** Matching Service only, calling ORS's existing integration. (If/when Overpass is later
added as the safety-filter polish layer, that becomes the Safety/POI Filter Service from the
Discovery Engine architecture — but that's a v2 addition to this item, not required now.)

**Data model (additive, replaces the single walk_tolerance_minutes column from the prior
revision of this document — nothing has shipped yet, so this is a clean replacement, not a
migration-on-a-migration):**
```sql
alter table request add column if not exists walk_distance_origin_m int not null default 0
  check (walk_distance_origin_m >= 0 and walk_distance_origin_m <= 2000);
alter table request add column if not exists walk_distance_destination_m int not null default 0
  check (walk_distance_destination_m >= 0 and walk_distance_destination_m <= 2000);
```

**Screen note:** Two slider rows (not chips) inside FINDS-S04's request flow and SCHED-ACC's
Location cell — reuse the exact slider component already built for FINDS-S03 (Filter & Sort),
same visual pattern, not a new component.

---

## EXP-08 — "Recommended Route" Revert Button (new)

**Flow:** Once a driver has manually rearranged stops via drag-and-drop (`DEC-S04`, `REQ-05`),
that manual order becomes authoritative — the Matching Service correctly never overwrites it on
its own (per `BENGS_Route_Matching_Algorithm.md`'s explicit rule: manual edits are driver-owned).
This adds a way to *deliberately* go back to what the algorithm last computed, without re-deriving
it from scratch or losing the ability to re-customize afterward.

**How "recommended" stays available without recomputing anything:** every time the Matching
Service actually runs `insertPassenger` (on accept) or removes a passenger (on cancel) — the only
two events that legitimately change what's optimal — it now also stamps each stop with what
position the algorithm placed it at, alongside the stop's currently-active position. A manual
drag-and-drop only changes the active position; the algorithm's stamp stays untouched until the
next real insertion/removal event. "Recommended Route" is then just: copy the stamped position
back into the active position. No recomputation, no new algorithm run — a plain revert.

**Data model (additive, one column, no new table):**
```sql
alter table beng_route add column if not exists recommended_stop_order int;
-- populated by the Matching Service whenever insertPassenger runs; NULL until the first
-- passenger is actually inserted, since there's nothing to "recommend" before that.
```

**Module:** Matching Service (writes `recommended_stop_order` on every real insertion/removal) +
application-level (the revert action itself is a plain `UPDATE ... SET stop_order =
recommended_stop_order`, no service call needed).

**Screens:** Add a "Use Recommended Route" button to `SCHED-S11` (Beng Detail, driver view) and
`DEC-S04` (Edit Route) — not a new screen, a new action on two existing ones. When
`stop_order != recommended_stop_order` for any stop, show a small inline indicator ("Your route
isn't the shortest possible — tap to use the recommended order") so the driver knows the option
is actually relevant right now, rather than showing a button that does nothing.

---

## EXP-05 — Edit an Approved Request

**Flow:** Currently, changing anything about an accepted request means Cancel (REQ-06) then
re-request from scratch. This adds a true edit path for a narrow set of fields — the ones that
don't require re-running feasibility from zero: `walk_tolerance_minutes` (once EXP-01 ships), and
a passenger's stated pickup/dropoff sub-address within an already-agreed area.

**Important boundary:** Editing origin/destination to somewhere the Matching Service hasn't
already validated is NOT "edit" — that's functionally a new request. Only expose Edit for fields
that can change without re-running `insertPassenger`. Anything else stays Cancel + Request Again.

**Module:** Application-level (Supabase + Flutter), no service changes.

**Data model:** No new columns — this is an `UPDATE` on existing `request` fields already covered
by the overlap trigger (`check_request_overlap`, migration `20260908000100`), which re-validates
on every `UPDATE` already, not just `INSERT`. Confirm this before building — the trigger already
listens on `before insert or update`, so it should just work, but verify with a test case.

**Screen note:** Add an "Edit" action alongside Cancel on `FINDS-S06` (My Requests). Opens a
reduced version of `FINDS-S04` with only the editable fields unlocked.

---

## EXP-03 + EXP-04 — Shareable Beng Links + Public Discovery Feed

**Decision made here (confirm before building, don't treat as silently settled):** A beng gets a
`visibility` of `private` (default, current behavior — must be found via search), `unlisted` (has
a shareable link; anyone with the link can view/request, but it's not in any public feed), or
`public` (has a shareable link AND appears in the discovery feed, EXP-04).

**"Auto-join" semantics — this is the part that needed an actual decision, not just a UI flag:**
- A request submitted through an **`unlisted` or `public`** link still goes through the normal
  driver accept/reject flow (`REQ-03`/`REQ-04`) — visibility alone doesn't imply consent to any
  specific rider.
- **True auto-join is scoped narrower than "any shared link":** only when a driver generates a
  link explicitly marked "auto-accept" at creation time (a separate, opt-in toggle, defaulting
  off) does a request through that link skip manual review and go straight to `accepted`, up to
  `max_passenger` capacity. This preserves `BR-10`'s three-distinct-actions principle — auto-accept
  isn't a new fourth action, it's Accept happening automatically under a condition the driver
  explicitly pre-authorized, which is meaningfully different from silently bypassing consent for
  every public link.

**Module:** Application-level (Supabase + Flutter). No new microservice.

**Data model (additive):**
```sql
alter table beng add column if not exists visibility varchar(10) not null default 'private'
  check (visibility in ('private', 'unlisted', 'public'));
alter table beng add column if not exists share_token uuid default gen_random_uuid();
alter table beng add column if not exists auto_accept boolean not null default false;
create unique index if not exists idx_beng_share_token on beng (share_token) where share_token is not null;
```
RLS: add a policy allowing `select` on `beng` where `visibility in ('unlisted','public')`
regardless of the requester's relationship to the driver (currently select is already open to all
authenticated users per the existing schema, so this may already work as-is — verify against the
current policy before assuming a new one is needed).

**Screens (new — not in UIUX v2.0, described here instead):**
- **EXP-S01 "Share Beng"** — reachable from `SCHED-S11` (Beng Detail) via a new "Share" icon.
  Visibility radio (Private/Unlisted/Public), Auto-accept toggle (only enabled if visibility ≠
  private), "Copy link" button generating a URL like `bengs.app/b/{share_token}`.
- **EXP-S02 "Shared Beng Landing"** — what opens when someone taps a share link. Same layout as
  `FINDS-S04` (Beng Detail, passenger view), with the Request button behaving per the auto-accept
  rule above.
- **EXP-S03 "Public Bengs Feed"** — new tab section or a card on `NAV-S02`/`NAV-S03` listing
  `visibility='public'` bengs without requiring a search. Same card component as `FINDS-S02`
  (Results List) — reuse, don't design a new card style.

---

## EXP-02 — Near-Miss Discovery ("30 min earlier / 1km more shows other possibilities")

**Requires the Discovery Engine microservice** (`BENGS_Routing_Microservices_Architecture.md` §4)
to exist first — this is not an extension of the Matching Service.

**Flow:** When `FINDS-S02` (Results List) comes back empty or sparse, show a secondary section:
"Nothing exact — but N more open up if you leave 30 min earlier, or walk 1 km more." Tapping it
re-runs the search with loosened parameters and shows the expanded result set, clearly labeled as
loosened (not silently merged into the primary list).

**Module:** Discovery Engine (H3 pre-filter to cheaply find candidates within the loosened
window/distance before doing anything expensive) → Matching Service (per-candidate feasibility
check, same `insertPassenger` logic, no duplication) → returned to Flutter.

**Data model:** No new persistent tables needed for a first version — this can be a stateless
query-time computation (Discovery Engine reads current `beng`/`beng_daily`/`request` rows,
computes H3 cells on the fly, filters, hands candidates to Matching Service). Add caching (Redis)
only if latency becomes a real, measured problem — don't build the cache speculatively.

**Screen note:** New section appended to the bottom of `FINDS-S02`, same card style, with a
distinct header ("Loosen your search") so it doesn't read as part of the exact-match results.

---

## EXP-07 — Merge Detection (two bengs could combine, notify drivers, nudge cool-friend)

**Requires the Discovery Engine.** Build this last, and only once you have real ride volume —
there's no way to validate a merge-recommendation engine is worth its complexity without
observing whether route overlap actually happens often in practice.

**Flow (background job, not a client-triggered action):**
1. Discovery Engine periodically (e.g. hourly, via a scheduled job — `pg_cron` calling an Edge
   Function, or the Discovery Engine's own scheduler) scans active `beng_daily` rows for pairs
   whose routes substantially overlap in space (H3 cell overlap) and time (interval-tree overlap
   on departure/arrival windows).
2. For a candidate pair, run OR-Tools (this is the one place in the whole system that genuinely
   needs a real VRP solver, not the lean insertion algorithm) to check: could one driver's vehicle
   feasibly absorb the other's passengers within capacity/distance/arrival constraints?
3. If feasible, notify BOTH drivers (a new notification type — `NOTIF-01`'s catalogue needs an
   entry for this, but that's additive to the existing `notification.type` enum, not a schema
   change) with a proposed merge and an estimated benefit (shorter combined distance, one fewer
   car on the road).
4. If both drivers accept, one beng's passengers get transferred to the other's route (via the
   existing Matching Service's insertion logic, run once per transferred passenger) and the
   now-empty beng is cancelled with an auto-generated reason. The two drivers are prompted to
   follow each other (reuses the existing "Follow Recommendation Prompt," `WA-S01`, already
   speced in UIUX v2.0 §3.14 — no new screen needed for the cool-friend nudge itself).

**Module:** Discovery Engine (detection + OR-Tools feasibility) → Matching Service (executing the
actual passenger transfer, reusing insertion) → Supabase notification trigger (additive, new
`notification.type` value: `merge_proposed`).

**Data model (additive):**
```sql
create table if not exists beng_merge_proposal (
  id uuid primary key default gen_random_uuid(),
  beng_daily_a uuid not null references beng_daily(id),
  beng_daily_b uuid not null references beng_daily(id),
  estimated_distance_saved_km numeric(6,2),
  status varchar(20) not null default 'proposed'
    check (status in ('proposed','accepted_a','accepted_b','both_accepted','rejected','expired')),
  created_at timestamptz not null default now()
);
```

**Screen (new):** **EXP-S04 "Merge Proposal"** — driver-facing card (reached from a
`merge_proposed` notification) showing both routes, the estimated benefit, Accept/Decline. Both
drivers must accept before anything executes.

**Cost note:** this is the one item where "free" needs the fullest caveat — it's the only feature
that justifies running OR-Tools continuously as a background job rather than on-demand, which
means the Discovery Engine's hosting tier should account for periodic CPU bursts, not just
request-response latency. Still no licensing cost, still a modest VPS line item, just worth
sizing separately from the always-idle Routing/Safety services once this ships.

---

## What NOT to do with this file

- **Don't start any of this before the current FRD-scoped MVP ships.** This document is a plan to
  return to, not a queue to pull work from early.
- Don't touch `FRD_Pembuatan_Aplikasi_BENGS.docx`, `BENGS_UIUX_Screen_Spec.docx`, or
  `BENGS_App_Mockup.html` for this batch — this document is the complete spec for `EXP-01`
  through `EXP-08`. If a real conflict with those documents surfaces during implementation
  (not just an absence — those docs simply don't cover this batch yet), flag it, don't silently
  resolve it.
- Don't stand up self-hosted OSRM, Valhalla, or Overpass speculatively — per the tools inventory
  above, EXP-01 and EXP-06 need none of them, and EXP-02/EXP-07 might not either if ORS's free
  tier remains sufficient once Discovery Engine's H3 pre-filter keeps routing-call volume low.
- Don't build the Discovery Engine microservice until EXP-02 or EXP-07 is actually being
  implemented — no speculative infrastructure.
- Don't let EXP-03's auto-accept toggle default to on, or apply to plain `unlisted`/`public`
  visibility without the explicit separate toggle — that's the one place in this whole batch
  where getting the default wrong means silently bypassing driver consent.