# BENGS — Path to Production

*Honest framing up front: given TMUA/UCAS deadlines are ~6 weeks out, a full public launch in that window is unlikely to be realistic alongside test prep. Treat Stages 1–2 as the "have something real to demo/discuss" milestone for admissions purposes. Stages 3–7 are the real path to an actual public launch, and can continue after — there's no reason BENGS has to be "done" by an application deadline; "here's a working app, here's my launch plan" is itself a strong thing to say.*

---

## Stage 1 — Finish the core build (Claude Code, per CLAUDE.md)

- Supabase project created, schema loaded
- Home tab wired to real Supabase calls (not `debugPrint` stubs)
- Remaining screens built per the "required changes" list in CLAUDE.md
- v1 route-matching heuristic implemented and running
- **Milestone:** the app runs on your own phone, end to end, for the scheduled-beng core loop at minimum

## Stage 2 — Dogfooding (you + a handful of real people)

- Run it on real devices, not just an emulator — emulators lie about GPS, camera, and performance
- Walk through every user journey yourself: sign up as a minor (test the parental consent flow), sign up as an adult, become a verified driver, post a beng, request one, accept, cancel, rate
- Get 3–5 real friends to actually use it, not just look at it — bugs surface differently when someone else's fat-fingering is involved
- **Milestone:** the core loop survives real, unscripted use without crashing or corrupting data

## Stage 3 — Legal & compliance basics (genuinely non-trivial — don't skip this)

This is the stage most side projects skip, and it's the one that actually matters most once real people's ID documents are involved:

- **Privacy Policy and Terms & Conditions** — real ones, not filler text. You're collecting KTP photos, selfies, NIK (national ID numbers), phone numbers, and location data. That's not casual user data.
- **Indonesia's UU PDP (Personal Data Protection Law, 2022)** — processing NIK/KTP data is regulated "specific personal data" under this law, with real obligations around consent, data minimization, and security. I'm not a lawyer and this isn't legal advice — but I'd treat this as a genuine blocker to public launch, not a checkbox. Worth looking into free resources: some Indonesian universities run legal aid clinics for student projects, and this is exactly the kind of thing worth a real consultation before you have KTP photos from strangers sitting in your database.
- **Minors' data** — the parental consent flow adds a second compliance layer on top of the above, since you're knowingly handling data from users under 18.
- **Honest scope check:** for a *closed* beta among people you know (Stage 2/4), this risk is much lower. For a *public* app store listing anyone can download, it's real, and worth resolving before Stage 5.

## Stage 4 — Closed beta

- **iOS**: TestFlight, internal or external testing group
- **Android**: Google Play's internal testing track
- Recruit beta testers from a real community — given BENGS's whole design is trust-network-first, your own campus or friend group is the natural first cohort, the same way Nebengers itself started as a small Twitter community before growing
- Watch for: does the matching actually feel fast enough, does the KYC gate feel like a wall people bounce off, does anyone actually use the spontaneous Home tab or does everyone default to scheduling ahead

## Stage 5 — App store submission

- **Apple Developer Program**: $99/year, required for any App Store listing including TestFlight external testing
- **Google Play Console**: $25 one-time
- Store listing assets: screenshots (per device size), description, **privacy policy URL** (from Stage 3 — Apple specifically checks this), age rating questionnaire, content rating
- Budget real time for Apple's review process — apps handling ID verification and location data draw more scrutiny, not less; expect possible back-and-forth, not instant approval

## Stage 6 — Infrastructure hardening

- **Supabase free tier limits** (500 MB database, auto-pause after 7 days idle) are fine for Stages 1–4, not for real public traffic — plan the upgrade to a paid tier *before* you need it, not after an outage
- **Error monitoring**: Sentry has a free tier and a Flutter SDK — set this up before launch, not after your first bug report with no stack trace
- **Backups**: confirm what Supabase's plan actually gives you here before assuming it's covered
- **Basic analytics**: enough to know if people are actually completing the request→accept flow, without collecting more than you need (data minimization cuts both ways — good practice and good compliance)

## Stage 7 — Launch and iterate

- Soft launch to the Stage 4 community first, not a cold public launch — smaller blast radius if something's wrong
- Then the post-MVP roadmap that's been deferred throughout this whole build: in-app payments, real-time tracking, in-app chat (BR-07/BR-11) — all deliberately out of scope until the core loop is proven with real users

---

**The realistic near-term goal, given your actual deadline:** get through Stage 2 solidly — a working, demoable app you personally understand end to end — and be able to speak honestly about Stages 3–7 as "here's my actual launch plan" in an interview or personal statement, rather than rushing a real public launch with real people's ID documents before you've thought through the compliance step properly.
