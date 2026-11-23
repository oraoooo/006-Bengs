# BENGS Route-Matching Algorithm — v2.0 (supersedes v1.0's Held-Karp DP)

## Decision (revised)

**v1.0 of this doc recommended full Held-Karp DP recomputed from scratch on every change.
That was solving a problem BENGS doesn't have and has been dropped.**

The actual product invariant: a driver only ever accepts **one** pending request at a time
(`REQ-03`). There is no flow where multiple new passengers get optimized in simultaneously.
Given that, the route is never really "recomputed" — it's always "we already have a valid,
settled sequence; insert exactly one more person's pickup+dropoff into it optimally." That's a
strictly cheaper problem than general PDP-DP, and solving it as insertion (not full re-solve) also
avoids a real UX bug the DP approach had: reshuffling already-confirmed passengers' pickup order
every time someone new joins, silently changing a promise you already made them.

**New approach: single-passenger optimal insertion, O(n²) time, O(n²) space**, where `n` is the
number of stops already in the sequence (still bounded under 10 per the existing product cap).

## Where Held-Karp still doesn't belong

There is no "re-optimize my whole route" driver action anywhere in the current flow — `REQ-05`
(Edit Route) is manual drag-and-drop, driver-authored, not an optimizer call. If that changes
later, full DP (or a proper PDPTW solver) would be the right tool then — but it's not needed for
anything in scope today. Don't build it speculatively.

## Problem framing (unchanged)

- Fixed endpoints: driver's origin and destination bound the sequence.
- Existing `sequence` = ordered list of `2k` stops (pickup/dropoff pairs for `k` currently
  confirmed passengers), already valid: respects precedence (pickup before its dropoff) and
  capacity (never exceeds `vehicle` capacity at any point) — see BR-09.
- Task: given one new candidate passenger (`candidatePickup`, `candidateDropoff`), find the
  cheapest way to splice both into `sequence` without disturbing the relative order of anyone
  already in it.

## Algorithm

```
insertPassenger(sequence, driverOrigin, driverDest, candidatePickup, candidateDropoff, capacity, edgeMatrix):
    # sequence = existing valid stop order (2k stops), already respects precedence + capacity
    best = null

    # Precompute running occupancy at each existing gap once — O(n) — reused across all (i,j) checks.
    occupancyAtGap = runningOccupancy(sequence)   # occupancyAtGap[g] = people in car in gap g

    for i in 0..len(sequence):              # candidate gap to insert the pickup
        if occupancyAtGap[i] + 1 > capacity:
            continue                        # inserting a pickup here would overflow the car
        for j in i..len(sequence):          # candidate gap to insert the dropoff (must be >= i)
            # every gap strictly between i and j gains +1 occupant while the new rider is aboard
            if max(occupancyAtGap[i..j]) + 1 > capacity:
                continue
            addedCost = costOfInsertingAt(sequence, i, j, candidatePickup, candidateDropoff, edgeMatrix)
            if best is null or addedCost.distance < best.cost.distance:
                best = { pickupGap: i, dropoffGap: j, cost: addedCost }

    return best   # null if no valid (i,j) exists at all -> request is infeasible (REQ-03: disable, don't hide)
```

`costOfInsertingAt(sequence, i, j, pickup, dropoff, edgeMatrix)` is **O(1)** given a precomputed
pairwise edge matrix for the current stop set (fetched from ORS once per recompute, not once per
`(i, j)` pair): inserting at a gap breaks one existing edge and adds two, so the delta is a fixed
small number of matrix lookups regardless of `i, j`.

**Complexity**: outer loop `i` is O(n), inner loop `j` is O(n), each iteration O(1) → **O(n²) time**.
Space is O(n²) for the edge matrix (dominates the O(n) sequence/occupancy arrays). At the
product-enforced cap of `2k < 10`, this is at most ~100 iterations — trivial, well under a
millisecond.

## Feasibility check (used by REQ-01, REQ-03) — updated for `arrival_time` as an absolute timestamp

Per the resolved open item: `max_distance` and `arrival_time` (formerly a separate `max_eta`
duration field — see the migration notes below, that column was dropped) are both **driver-set
preferences with a floor, not a ceiling**: the driver can push them looser than the ORS-computed
lowerbound, never tighter.

```
result = insertPassenger(...)
feasible = result is not null
       and result.cost.distance <= beng.max_distance_km
       and (beng.depart_time + result.cost.totalTravelTime) <= beng.arrival_time
```

If either bound is violated, the request is infeasible — shown disabled per `REQ-03`, never
silently hidden.

## When to run it

| Trigger | What's computed |
|---|---|
| Passenger submits a request (`REQ-01`) | `insertPassenger` against the current confirmed sequence — feasibility check only, doesn't commit |
| Driver accepts a request (`REQ-03`) | Commit the winning `(i, j)` insertion to `beng_route`. Then re-run the feasibility check (not a fresh insertion search, just re-validate) for every other still-pending request against the new sequence — disable any that no longer fit |
| Driver manually edits route (`REQ-05`, drag-and-drop) | No algorithm runs — the driver's manual order is authoritative. Compute the cost of that fixed order directly (sum edges in sequence), then re-run feasibility checks for pending requests against it |
| Passenger cancels / is removed | Splice their pickup/dropoff out of `sequence` directly (no search needed — their position is already known) |

## Implementation notes for Claude Code

- Pure function, no I/O inside: `insertPassenger(sequence, ..., edgeMatrix) -> {pickupGap, dropoffGap, cost} | null`. Fetch the ORS edge matrix separately so this is unit-testable without network calls.
- `runningOccupancy(sequence)` is a simple O(n) prefix scan: +1 at each pickup, -1 at each dropoff.
- Write unit tests with small hand-checkable cases (2–3 existing passengers, a known-optimal insertion point) before trusting it against real ORS data.
- The old v1.0 recommendation to sanity-check against Google OR-Tools no longer applies in the same way — OR-Tools solves general PDP optimally, which isn't the same problem as single-insertion. If you want a sanity check, compare against brute-force over all `(i, j)` pairs (which is literally what this algorithm already is — there's no shortcut being taken that needs independent verification).
