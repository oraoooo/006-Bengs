# BENGS Routing & Matching — Microservice Architecture (response to change01.md)

## Correction 1: Supabase already IS Postgres + PostGIS

The original diagram assumed a self-hosted "PostgreSQL + PostGIS" box on your own VPS. BENGS
already runs on Supabase, and **Supabase's database is Postgres** — PostGIS is available as a
standard extension (Database \u2192 Extensions in the Supabase dashboard), not something you lose by
using Supabase instead of self-hosting. Nothing about the diagram's spatial storage/queries
(`POINT(lat, lon)`, distance queries) needs to change — same engine, managed instead of
self-managed, plus you keep everything already built (Auth, Storage for KYC docs, Realtime,
RLS, `pg_cron` for auto-reject, the existing 15+ tables and triggers).

**Supabase is not one of your microservices.** It's a managed external dependency every service
below talks to — don't try to co-locate it inside your own Docker network, and don't build a
separate "database service" wrapping it; use Supabase's client libraries / REST API directly from
whichever service needs data.

## Correction 2: two different problems were bundled into one pipeline

| | Problem shape | Where it applies |
|---|---|---|
| **Insertion** (current MVP scope) | Insert one new passenger into ONE already-known, already-confirmed route. No citywide search — the passenger already chose which beng to request. | REQ-01, REQ-03 — already fully speced as O(n\u00b2) single-passenger insertion, no OR-Tools/H3/interval-trees needed at all. |
| **Discovery** (future scope) | Scan across MANY simultaneous active bengs/requests city-wide to surface possibilities the passenger didn't explicitly search for. | change01.md #2 (near-miss suggestions: "30 min earlier / 1km more") and #7 (detect two mergeable bengs, notify drivers) |

Building the full H3 + interval-tree + OR-Tools apparatus for MVP would be solving Discovery's
problem to serve Insertion's use case — over-engineered for what ships first. Split into two
services so MVP stays lean and Discovery can be built later without a rewrite.

## Microservice boundaries

Each is independently deployable (own Docker container), with a narrow, single responsibility,
talking to Supabase directly and to each other over a small internal HTTP API — not one Python
monolith holding everything in one process's RAM.

```
                    ┌─────────────────────────────┐
                    │   Supabase (managed)         │
                    │   Postgres + PostGIS          │
                    │   Auth / Storage / Realtime   │
                    │   RLS / pg_cron / Edge Fns    │
                    └───────────┬─────────────────┘
                                │  (every service below reads/writes here directly)
        ┌───────────────┬──────┴───────┬────────────────────┐
        │               │              │                    │
┌───────▼──────┐ ┌──────▼───────┐ ┌────▼─────────────┐ ┌────▼──────────────────┐
│ Routing      │ │ Safety/POI    │ │ Matching Service  │ │ Discovery/Merge Engine │
│ Engine       │ │ Filter Service│ │ (MVP, ships now)   │ │ (future, NOT MVP)      │
│ Service      │ │               │ │                    │ │                        │
│ OSRM+Valhalla│ │ Overpass API  │ │ Single-passenger   │ │ H3 spatial pre-filter  │
│ (self-hosted,│ │ (self-hosted) │ │ O(n\u00b2) insertion   │ │ Interval trees (time)  │
│ Jabodetabek  │ │               │ │ (BENGS_Route_      │ │ OR-Tools VRP solver    │
│ extract)     │ │               │ │ Matching_Algo.md)  │ │ Redis (shared index    │
│              │ │               │ │                    │ │ across workers, only   │
│ /matrix      │ │ /safe-points  │ │ Calls Routing       │ │ needed once this runs  │
│ /isochrone   │ │               │ │ Engine for edge     │ │ continuously)          │
└──────────────┘ └───────────────┘ │ weights            │ └────────────────────────┘
                                    └────────────────────┘
```

### 1. Routing Engine Service
Wraps self-hosted OSRM (driving time/distance matrices) and Valhalla (walking isochrones,
multimodal). Stateless compute — the only thing it "owns" is the processed OSM road-graph files
on local disk (Jabodetabek extract per the earlier sizing discussion, ~$10\u201320/mo VPS tier).
Exposes `/matrix` and `/isochrone` internally. Nothing here talks to Supabase directly \u2014 it's a
pure computation service other services call.

### 2. Safety/POI Filter Service
Wraps a self-hosted Overpass API instance (don't depend on the public shared instance in
production \u2014 rate-limited, not meant for sustained automated traffic). Resolves a walking
isochrone polygon into vetted safe meeting points (bus stops, marked crossings, lit corners).
Exposes `/safe-points?polygon=...`. Also stateless compute.

### 3. Matching Service \u2014 ships with MVP
The actual insertion algorithm from `BENGS_Route_Matching_Algorithm.md` v2.0. Reads the current
confirmed stop sequence from Supabase, calls the Routing Engine Service for the edge-weight
matrix of the relevant stops, runs the O(n\u00b2) insertion search, writes the result back to
`beng_route` in Supabase. No OR-Tools, no H3, no interval trees, no Redis \u2014 genuinely doesn't
need them for this problem size (max 10 stops per route). This is what REQ-01/REQ-03 actually
call.

### 4. Discovery/Merge Engine Service \u2014 explicitly deferred, not MVP
This is where the original diagram's heavier machinery belongs:
- **H3 spatial index + interval trees**: pre-filter which of the city's currently-open
  bengs/requests are even worth considering (same grid cell, overlapping time window) before
  running anything expensive \u2014 this only matters once you're scanning many bengs at once, which
  Insertion never does.
- **OR-Tools**: a real VRP solver is justified here because merge-detection (change01.md #7) is
  actually a harder combinatorial problem than single-passenger insertion \u2014 you're deciding
  whether to combine two independent routes and vehicles, not just where to slot one stop.
- **Redis**: only becomes relevant once this service runs continuously across multiple worker
  instances and needs a shared live view of "everyone currently searching" \u2014 not needed for a
  request-scoped computation.
- **Navigation links** (`google.com/maps/dir/?...`, genuinely free, no API key): small enough to
  be a shared utility function called by whichever service produces a final stop sequence \u2014 not
  worth its own microservice.

Build this when you're ready to scope change01.md #2 and #7 as real features with their own
FRD entries \u2014 not before, and not as part of finishing MVP matching.

## What this means for change01.md's other items

- **#1 (walk tolerance before/after)** \u2014 fits inside the existing Matching Service: shifts the
  effective pickup/dropoff point before insertion runs, using the Routing Engine's isochrone
  endpoint. No new service needed.
- **#6 (avoid tolls/highways)** \u2014 a routing-profile parameter passed to the Routing Engine Service's
  `/matrix` call. No new service needed.
- **#5 (edit approved request)** \u2014 application-level (Supabase + client), doesn't touch this
  architecture at all.
- **#3/#4 (shareable links, browse public bengs)** \u2014 application-level (Supabase RLS + a
  visibility column), doesn't need the Discovery Engine \u2014 keep separate from #2/#7 in planning,
  they're not the same size of problem despite being adjacent in the same list.
