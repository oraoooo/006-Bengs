-- Schema deltas surfaced by the UI/UX design pass (BENGS_UIUX_Screen_Spec.docx v1.0)
-- and flagged as [DELTA] / Open Items in FRD_Pembuatan_Aplikasi_BENGS.docx v3.0 §10/§13.
-- Every field below is load-bearing in an actual mockup, not speculative:
--   - KYC-S07 (SIM selfie capture) has nothing to write to today
--   - VEH-S04 (Vehicle Details) shows nickname/default passenger/default price
--   - SCHED-S01/S04, QUICK-S01 (Add a Beng / Add a Quick Beng) show title,
--     description, max distance, and max ETA fields the ORS lowerbound flow needs
--
-- [RESOLVED, 2026-09-08] "max ETA" is confirmed as the literal timestamp interpretation:
-- an absolute latest-arrival time, editable by the driver but floored (never allowed below)
-- the ORS-computed lowerbound. This is just beng.arrival_time under stricter application-level
-- gating (locked until vehicle+locations+departure are set, pre-filled with the ORS lowerbound,
-- floor-enforced on edit) -- NOT a new column. No max_eta_minutes exists in this schema.
-- (Superseded the duration interpretation this file originally shipped with.)

-- ---------------------------------------------------------------------------
-- license: KYC-04 / KYC-S07 requires "SIM + selfie" to verify, but the table
-- only ever had license_card_url for the SIM photo itself.
-- ---------------------------------------------------------------------------
alter table license add column if not exists selfie_url varchar(500);

-- ---------------------------------------------------------------------------
-- vehicle: VEH-01 / VEH-S04 collects a nickname and per-vehicle defaults that
-- Add-a-Beng (SCHED-S05) and Add-a-Quick-Beng (QUICK-S01) both pre-fill from.
-- Nullable: existing vehicle rows predate this screen and have none of this.
-- ---------------------------------------------------------------------------
alter table vehicle add column if not exists nickname varchar(100);
alter table vehicle add column if not exists default_max_passenger int;
alter table vehicle add column if not exists default_price int;

-- Postgres has no "ADD CONSTRAINT IF NOT EXISTS" -- wrap in DO blocks so this
-- migration stays safe to re-run, same intent as the "if not exists" columns above.
do $$ begin
  alter table vehicle add constraint vehicle_default_max_passenger_positive
    check (default_max_passenger is null or default_max_passenger > 0);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table vehicle add constraint vehicle_default_price_nonnegative
    check (default_price is null or default_price >= 0);
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- beng: SCHED-S01 (title, default "{name} {n}-th Beng!" is computed by the
-- app, not the DB), SCHED-S05 (description), and SCHED-S04/QUICK-S01 (max
-- distance -- max ETA is NOT a new column, see resolved note at top of file;
-- it reuses arrival_time with app-level floor-gating instead).
-- max_distance_km is pre-filled from an ORS-computed lowerbound and only
-- editable upward -- that floor rule is app-enforced, not a DB constraint,
-- since the lowerbound itself is recomputed per search and never stored.
-- title is NOT NULL with an empty-string default so existing rows and any
-- insert path that hasn't been updated yet don't break; the app should
-- always overwrite it with a real value before a beng is user-visible.
-- ---------------------------------------------------------------------------
alter table beng add column if not exists title text not null default '';
alter table beng add column if not exists description text;
alter table beng add column if not exists max_distance_km numeric(6,2);

do $$ begin
  alter table beng add constraint beng_max_distance_km_nonnegative
    check (max_distance_km is null or max_distance_km >= 0);
exception when duplicate_object then null;
end $$;
