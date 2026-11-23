# BENGS Cool Person / Cool Friend Scoring — v1.0

## Scope

Resolves the Future Enhancement flagged in FRD §3.2/§13 (SOC-03): the data model existed
(`profiles` enrichment fields, migration `20260904000400`) but no scoring/tagging logic did.
This defines it.

## Tag definitions (unchanged from FRD, now made precise)

- **Cool Friend**: `friend` table shows mutual follow (SOC-01). This is a graph fact, not a score —
  always overrides Cool Person/None regardless of profile similarity.
- **Cool Person**: not yet mutual-followed, but profile similarity score ≥ threshold (see below).
- **None**: below threshold, not a friend.

## A real constraint the original notes missed: privacy gates most of the signal

`profile_visibility` defaults to **public** for `bio`/`interests` but **cool_friends-only** for
`job_title`/`workplace_name`/`neighbourhood`/`instagram_handle`. Since Cool Person matching by
definition happens *between non-friends*, any field set to `cool_friends`-only is invisible to the
matching engine for that pair — using it anyway would leak private data to a stranger.

**Rule: a field only contributes to a Cool Person score if its visibility is `public` for the
profile being scored.** Under default settings, this means most users' out-of-the-box Cool Person
matches will run on interests + bio + age only, since workplace/neighbourhood start locked down.
This is intentional (privacy-first) and expected to produce sparser matches than a naive read of
the field list would suggest — don't treat this as a bug to "fix" by loosening defaults.

## Missing field: "school"

FRD/UI-UX text mentions "Goes to same school!" as a special tag, but **no school/education field
exists anywhere in the schema** — only `job_title` and `workplace_name`. Two options, pick one
before implementing:

- (a) Drop the "same school" tag from the UI until a real field is added, or
- (b) Repurpose `job_title` loosely as a proxy (e.g. matching "Product Designer" free-text against
  another user's free-text) — low signal, not recommended, free text won't match reliably.

**Recommendation: (a).** Don't fake a signal you don't have data for.

## Scoring weights

| Signal | Condition | Points | Notes |
|---|---|---|---|
| Same neighbourhood | Exact match, case/whitespace-normalized, both `public` | 30 | Highest weight — directly relevant to carpooling proximity |
| Shared interests | Jaccard similarity of interest-tag sets × 25, both `public` | 0–25 | `bio`/`interests` default public, so usually available |
| Same workplace | Exact match, normalized, both `public` | 20 | Locked by default privacy — often unavailable |
| Same age | `date_of_birth` within ±1 year | 10 | Age has no visibility toggle (always usable per earlier FRD note) |
| Cool mutuals | `min(mutual_count × 3, 15)` | 0–15 | Computed on-the-fly (intersect follower/following, per the open item on `is_mutual`) |

Total possible: 100. **Cool Person threshold: score ≥ 40.** (Tuned low deliberately, since privacy
defaults already suppress two of the five signals for most user pairs — a high threshold would
make the tag nearly unreachable out of the box.)

## Tag chips shown in UI (FIND-03, SOC-03)

Each chip is a pass/fail on one signal, independent of the aggregate score/threshold — a user can
see "Same neighbourhood" even if their total score doesn't clear the Cool Person bar:

- `Same age!` — DOB within ±1 year
- `From the same neighbourhood!` — exact match, both public
- `Work in the same office!` — exact match, both public (workplace_name)
- `Shared same interests!` — Jaccard ≥ 0.3 (tune after real data)
- `Have N cool mutuals!` — N ≥ 1, shows literal count

## Sort/filter integration (FIND-02)

The existing "cool tag" filter (Cool Person / Cool Friend / None) becomes a simple categorical
filter on the computed tag. "Sort by matching" sorts by the numeric score (Cool Friends always
first regardless of score, since they're not scored).

## Implementation notes for Claude Code

- Compute server-side (Postgres function or edge function), not client-side — the inputs include
  another user's data the client shouldn't need to fetch in full just to compute a score.
- Cache nothing initially — compute on read for search results (small result sets, cheap per FRD's
  N<10 kind of scale). Revisit only if profile-heavy list views measurably slow down.
- `mutual_count`: `SELECT count(*) FROM friend f1 JOIN friend f2 ON f1.followed_id = f2.profile_id AND f2.followed_id = f1.profile_id WHERE ...` intersected against both users' follow lists — same on-the-fly approach already decided for `is_mutual`, don't build a separate materialization just for this.
