# BENGS Landing Page Copy — v1.0

Resolves the FRD §13 open item: "Isi Landing Page belum ditentukan." Structure follows the unused
sitemap (Landing → How it works / Sign up-Sign in / About BENGS). Voice matches the existing
onboarding intro tone already shipped in the app ("Explore now to experience the benefits") —
casual, direct, English. Swap to Bahasa Indonesia if you want localized copy instead; ping me and
I'll write that pass separately rather than guess at a translation here.

**Hard constraint carried over from CLAUDE.md: never claim "first of its kind" or novelty of the
core carpooling concept anywhere below.** The differentiator is engineering depth and specific
features, stated honestly.

---

## Hero

**Headline:**
> Nebeng with people you'd actually want to ride with.

**Subheadline:**
> BENGS matches you with drivers and passengers who share your route — and increasingly, your
> circle. Schedule ahead, or find a ride in the next five minutes.

**Primary CTA:** `Get Started`
**Secondary link:** `Already have an account? Log in`

---

## How it works (3 steps)

**1. Set your route**
> Add a beng if you're driving, or search for one if you're not. Works for your daily commute or
> a one-off trip — whichever you need right now.

**2. Match with people, not just a car**
> See who's on your route before you commit — mutual friends, shared interests, same
> neighbourhood. Cool Friends get a fixed rate and a direct line on WhatsApp once you're both in.

**3. Ride, then settle up**
> Confirm the ride in-app, track it live, and handle payment directly with your driver or
> passenger over WhatsApp — no in-app payment, no extra fees taken out.

---

## Why BENGS (differentiators — keep this honest)

> Carpooling apps aren't new in Indonesia, and we're not pretending BENGS is the first. What's
> different is what's under the hood: real route optimization that actually finds the shortest
> combined trip for everyone in the car, identity verification that keeps KYC and vehicle checks
> independent so nothing blocks you unnecessarily, and matching that's built around people you'd
> actually want to share a ride with — not just whoever's nearest.

Three short supporting lines (can render as icon + text blocks):

- **Real optimization.** Multi-stop routes are computed exactly, not guessed — pickups and
  drop-offs are ordered to add the least time for everyone already in the car.
- **Verified, not just claimed.** Driver identity and vehicle registration are checked
  independently, so a verified car doesn't wait on a slow ID review and vice versa.
- **Built for people you know (or want to).** Follow, see mutuals, and build a small circle of
  regular riders — carpooling that's social first, transactional second.

---

## Trust / safety line (short, placed near CTA or footer)

> Every driver is identity-verified before they can offer a ride. Passengers can always browse and
> request without submitting any documents.

---

## Footer CTA (repeat near page bottom)

**Headline:** `Ready to find your first beng?`
**CTA:** `Get Started`
**Small print:** `Free to use. Settle rides directly with your driver or passenger — BENGS doesn't
take a cut.`

---

## About BENGS (separate page/section, per sitemap)

> BENGS is a social carpooling app built for Jakarta — nebeng between people who mostly already
> know each other, or are one ride away from it. Two roles, one account: ride as a passenger from
> day one, or verify your identity and a vehicle to start offering rides too. Support for both
> motorcycles and cars, from the start.

---

## Notes for whoever builds this screen

- Every claim above is checkable against something already shipped (route DP, independent
  KYC/vehicle tracks, follow/mutuals) — don't add differentiator copy for anything not actually
  built yet (e.g. don't imply payment happens in-app; BR-07 explicitly says it doesn't).
- No pricing/fee language beyond "BENGS doesn't take a cut" — there's no monetization model
  decided yet (FRD §3.2 lists in-app payment/fees as Future Enhancement, not current).
