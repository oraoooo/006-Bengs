-- Fallback for vehicle brand/model when the driver's actual vehicle isn't in
-- vehicle_brand/vehicle_model yet. The lookup tables (20260908000100) are seeded
-- generously for the Indonesian market but will never be exhaustive -- rather
-- than blocking Add Vehicle on "your brand isn't listed," VEH-01/VEH-S02 gets an
-- explicit "Other" option that falls through to free text, captured here instead
-- of silently corrupting the lookup with one-off values.
--
-- Design: brand_id/model_id stay nullable (already true -- they were added
-- without NOT NULL in 20260908000100). When the user picks "Other," the app
-- writes to vehicle_brand_other/vehicle_model_other instead and leaves the FK
-- null. A check constraint enforces exactly one of (FK, free text) per field --
-- never both null (nothing entered), never both set (ambiguous which is correct).

alter table vehicle add column if not exists vehicle_brand_other varchar(80);
alter table vehicle add column if not exists vehicle_model_other varchar(80);

-- [FIXED] 20260908000100 dropped the old free-text vehicle_brand/vehicle_model
-- columns without backfilling brand_id/model_id or this migration's _other
-- columns, so any vehicle row that predates that migration is left with
-- neither side of the pair set -- which the xor constraints below would
-- then reject outright, blocking this migration from ever applying.
-- Confirmed against the live project: exactly one such orphaned row (a
-- pre-restart test vehicle); the original brand/model text is unrecoverable
-- since the old columns are already gone. Backfilled here as an explicit
-- 'Unknown (pre-migration)' placeholder rather than left inconsistent --
-- honest about the loss instead of fabricating a real-looking value. This
-- also makes the migration idempotent-safe: once backfilled, re-running it
-- is a no-op since no row is left with both sides null.
update vehicle set vehicle_brand_other = 'Unknown (pre-migration)'
  where brand_id is null and vehicle_brand_other is null;
update vehicle set vehicle_model_other = 'Unknown (pre-migration)'
  where model_id is null and vehicle_model_other is null;

do $$ begin
  alter table vehicle add constraint vehicle_brand_xor_other
    check (
      (brand_id is not null and vehicle_brand_other is null)
      or (brand_id is null and vehicle_brand_other is not null)
    );
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table vehicle add constraint vehicle_model_xor_other
    check (
      (model_id is not null and vehicle_model_other is null)
      or (model_id is null and vehicle_model_other is not null)
    );
exception when duplicate_object then null;
end $$;

-- Admin-facing signal: vehicles submitted via the "Other" free-text path are
-- exactly the ones worth reviewing for addition to the real lookup tables --
-- surfaced as a simple view rather than a new status field, since it's an
-- ops/curation concern, not a user-facing state.
create or replace view vehicle_other_submissions as
select id, profile_id, vehicle_brand_other, vehicle_model_other, created_at
from vehicle
where vehicle_brand_other is not null or vehicle_model_other is not null
order by created_at desc;
