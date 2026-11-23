-- Resolves the six "quick decision" open items from FRD v3.0 §13 (2026-09-08):
--   1. Auto-reject: pg_cron (built-in Supabase, free) -- not an external job.
--   2. Date-overlap: enforced here as a trigger (can't be bypassed via direct REST/RPC calls),
--      in addition to whatever client-side check the app shows for immediate UX feedback.
--   4. friend.is_mutual: materialized as a maintained column, not computed on-the-fly.
--   5. Lookup tables for vehicle brand/model and disability_type (bounded, known sets).
--      job_title/workplace_name stay free text -- genuinely open-ended, a lookup doesn't fit.
--      neighbourhood becomes a lookup FK into indonesia_region, scoped nationally (not
--      Jakarta-only) per the decision to plan for BENGS expanding beyond Jakarta eventually.
--      Saved/unsaved location autocomplete is NOT a lookup table -- that's what ORS's
--      geocoding endpoint is for; ../saved_location stays as user favorites only, unrelated
--      to this table.
--   6. No in-app payment -- no schema change, decision confirmed as-is (BR-07 unchanged).

-- ===========================================================================
-- 1. LOOKUP TABLES
-- ===========================================================================

create table if not exists vehicle_brand (
  id uuid primary key default gen_random_uuid(),
  name varchar(80) not null unique
);

-- vehicle_type on the MODEL, not the brand: several brands (Honda, Suzuki, Yamaha)
-- sell both motor and mobil in Indonesia, so the brand itself can't be typed --
-- only individual models can. This lets Add Vehicle filter the model dropdown by
-- whichever type (motor/mobil) the user already picked, without also having to
-- filter the brand list (a brand stays selectable regardless of type; its model
-- list just narrows).
create table if not exists vehicle_model (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references vehicle_brand(id) on delete restrict,
  name varchar(80) not null,
  vehicle_type varchar(10) not null check (vehicle_type in ('motor', 'mobil')),
  unique (brand_id, name, vehicle_type)
);
create index if not exists idx_vehicle_model_type on vehicle_model (vehicle_type);

-- Seeded for the Indonesian market -- covers the large majority of what's actually
-- on the road (per common brand-share reporting: Toyota/Daihatsu/Honda/Mitsubishi/
-- Suzuki dominate mobil; Honda/Yamaha dominate motor, with Kawasaki/Suzuki/Vespa/
-- Viar covering most of the rest). Not exhaustive -- that's what the "Other, not
-- listed" fallback below is for (see the follow-up migration) -- but big enough
-- that most users should find their actual vehicle without needing it.
insert into vehicle_brand (name) values
  -- mobil-leaning or mixed
  ('Toyota'), ('Daihatsu'), ('Honda'), ('Mitsubishi'), ('Suzuki'), ('Nissan'),
  ('Mazda'), ('Hyundai'), ('Kia'), ('Wuling'), ('Isuzu'), ('DFSK'), ('Chery'),
  ('BYD'), ('Mercedes-Benz'), ('BMW'), ('Ford'), ('Chevrolet'),
  -- motor-only or motor-leaning
  ('Yamaha'), ('Kawasaki'), ('Vespa'), ('Viar'), ('KTM'), ('Royal Enfield'), ('TVS'), ('Benelli')
on conflict (name) do nothing;

insert into vehicle_model (brand_id, name, vehicle_type)
select b.id, m.name, m.vtype from vehicle_brand b
join (values
  -- Toyota
  ('Toyota','Avanza','mobil'), ('Toyota','Veloz','mobil'), ('Toyota','Innova','mobil'),
  ('Toyota','Rush','mobil'), ('Toyota','Calya','mobil'), ('Toyota','Agya','mobil'),
  ('Toyota','Fortuner','mobil'), ('Toyota','Yaris','mobil'),
  -- Daihatsu
  ('Daihatsu','Xenia','mobil'), ('Daihatsu','Ayla','mobil'), ('Daihatsu','Terios','mobil'),
  ('Daihatsu','Sigra','mobil'), ('Daihatsu','Gran Max','mobil'),
  -- Honda (mobil)
  ('Honda','Brio','mobil'), ('Honda','Mobilio','mobil'), ('Honda','HR-V','mobil'),
  ('Honda','CR-V','mobil'), ('Honda','BR-V','mobil'),
  -- Honda (motor)
  ('Honda','Vario','motor'), ('Honda','Beat','motor'), ('Honda','Scoopy','motor'),
  ('Honda','PCX','motor'), ('Honda','Supra','motor'), ('Honda','Genio','motor'),
  ('Honda','ADV160','motor'), ('Honda','CBR150R','motor'),
  -- Mitsubishi
  ('Mitsubishi','Xpander','mobil'), ('Mitsubishi','Pajero Sport','mobil'), ('Mitsubishi','Outlander','mobil'),
  -- Suzuki (mobil)
  ('Suzuki','Ertiga','mobil'), ('Suzuki','XL7','mobil'), ('Suzuki','Carry','mobil'),
  -- Suzuki (motor)
  ('Suzuki','Nex','motor'), ('Suzuki','Address','motor'), ('Suzuki','Satria F150','motor'),
  -- Nissan / Mazda / Hyundai / Kia / Wuling / Isuzu / DFSK / Chery / BYD (mobil only)
  ('Nissan','Livina','mobil'), ('Nissan','Magnite','mobil'),
  ('Mazda','CX-5','mobil'), ('Mazda','2','mobil'),
  ('Hyundai','Creta','mobil'), ('Hyundai','Stargazer','mobil'), ('Hyundai','Ioniq 5','mobil'),
  ('Kia','Seltos','mobil'), ('Kia','Sonet','mobil'),
  ('Wuling','Confero','mobil'), ('Wuling','Almaz','mobil'), ('Wuling','Air ev','mobil'),
  ('Isuzu','Panther','mobil'), ('Isuzu','D-Max','mobil'),
  ('DFSK','Gelora','mobil'), ('DFSK','Glory','mobil'),
  ('Chery','Tiggo','mobil'), ('BYD','Atto 3','mobil'), ('BYD','Seal','mobil'),
  ('Mercedes-Benz','C-Class','mobil'), ('BMW','3 Series','mobil'),
  ('Ford','Everest','mobil'), ('Chevrolet','Spin','mobil'),
  -- Yamaha
  ('Yamaha','NMAX','motor'), ('Yamaha','Aerox','motor'), ('Yamaha','Mio','motor'),
  ('Yamaha','Vixion','motor'), ('Yamaha','Xmax','motor'), ('Yamaha','Fazzio','motor'),
  -- Kawasaki / Vespa / Viar / KTM / Royal Enfield / TVS / Benelli (motor only)
  ('Kawasaki','Ninja','motor'), ('Kawasaki','KLX','motor'),
  ('Vespa','Primavera','motor'), ('Vespa','Sprint','motor'),
  ('Viar','Karisma','motor'), ('KTM','Duke','motor'),
  ('Royal Enfield','Classic 350','motor'), ('TVS','Ntorq','motor'), ('Benelli','Motobi','motor')
) as m(brand, name, vtype)
  on b.name = m.brand
on conflict (brand_id, name, vehicle_type) do nothing;

create table if not exists disability_type (
  id uuid primary key default gen_random_uuid(),
  name varchar(100) not null unique
);

insert into disability_type (name) values
  ('Disabilitas Rungu'), ('Disabilitas Wicara'), ('Disabilitas Rungu dan Wicara'),
  ('Disabilitas Fisik')
on conflict (name) do nothing;

-- National scope (all Indonesia, not Jakarta-only) per decision. This table's STRUCTURE is
-- created here; populating all ~83,000 kelurahan/desa is a data-import task, not something to
-- hand-write into a migration -- bulk-load from an open source (e.g. Kemendagri/BPS wilayah
-- administrasi datasets) via a CSV import script, separately from this file.
create table if not exists indonesia_region (
  id uuid primary key default gen_random_uuid(),
  province varchar(100) not null,
  city varchar(100) not null,        -- kabupaten/kota
  district varchar(100) not null,    -- kecamatan
  village varchar(100) not null,     -- kelurahan/desa
  unique (province, city, district, village)
);
create index if not exists idx_indonesia_region_village on indonesia_region (village);

-- ---------------------------------------------------------------------------
-- Wire the lookups into existing tables. Old free-text columns are dropped in
-- favor of FKs -- safe because these features (VEH-01 vehicle add, PROF-02
-- enrichment) haven't shipped to real users yet per the current build status.
--
-- [FIXED] The columns being dropped are vehicle.vehicle_brand / vehicle.vehicle_model
-- (confirmed against the live schema by Claude Code's audit) -- the original version
-- of this migration incorrectly dropped columns named brand/model, which don't
-- exist, so the DROP silently no-op'd and the old free-text columns survived
-- alongside the new unused brand_id/model_id. That was a transcription error in
-- the FRD's data entity table, carried into this migration; fixed here.
-- Note the deliberate naming overlap: the new lookup TABLE is also called
-- vehicle_brand, distinct from the vehicle TABLE's now-dropped vehicle_brand
-- COLUMN -- no actual SQL collision (different namespaces), but worth being
-- careful reading this file.
-- ---------------------------------------------------------------------------
alter table vehicle add column if not exists brand_id uuid references vehicle_brand(id);
alter table vehicle add column if not exists model_id uuid references vehicle_model(id);
alter table vehicle drop column if exists vehicle_brand;
alter table vehicle drop column if exists vehicle_model;

alter table driver_verification add column if not exists disability_type_id uuid references disability_type(id);
alter table driver_verification drop column if exists disability_type;

alter table profiles add column if not exists neighbourhood_id uuid references indonesia_region(id);
alter table profiles drop column if exists neighbourhood;

-- ===========================================================================
-- 2. MATERIALIZED is_mutual ON friend
-- ===========================================================================

alter table friend add column if not exists is_mutual boolean not null default false;

create or replace function refresh_friend_mutual_status()
returns trigger as $$
begin
  -- On a new follow: if the reverse row already exists, both rows become mutual.
  if tg_op = 'INSERT' then
    update friend set is_mutual = true
      where (profile_id = new.followed_id and followed_id = new.profile_id);
    if found then
      update friend set is_mutual = true where id = new.id;
    end if;
  end if;

  -- On an unfollow (row deleted): the reverse row (if any) is no longer mutual.
  if tg_op = 'DELETE' then
    update friend set is_mutual = false
      where profile_id = old.followed_id and followed_id = old.profile_id;
  end if;

  return null; -- AFTER trigger, return value ignored
end;
$$ language plpgsql security definer;

drop trigger if exists trg_friend_mutual_insert on friend;
create trigger trg_friend_mutual_insert
  after insert on friend
  for each row execute function refresh_friend_mutual_status();

drop trigger if exists trg_friend_mutual_delete on friend;
create trigger trg_friend_mutual_delete
  after delete on friend
  for each row execute function refresh_friend_mutual_status();

-- ===========================================================================
-- 3. AUTO-REJECT STALE REQUESTS -- pg_cron, not an external job
-- ===========================================================================

create extension if not exists pg_cron;

create or replace function auto_reject_stale_requests()
returns void as $$
begin
  update request
  set status = 'auto-rejected', updated_at = now()
  where status = 'pending'
    and created_at < now() - interval '7 days';
  -- existing notify_request_status_change() trigger (20260903000000) already fires on this
  -- UPDATE and notifies the passenger -- no separate notification logic needed here.
end;
$$ language plpgsql security definer;

select cron.schedule(
  'auto-reject-stale-requests',
  '*/30 * * * *',              -- every 30 minutes; tune once real request volume is known
  $$select auto_reject_stale_requests()$$
) where not exists (
  select 1 from cron.job where jobname = 'auto-reject-stale-requests'
);

-- ===========================================================================
-- 4. DATE-OVERLAP ENFORCEMENT -- trigger, not just app-side validation
-- ===========================================================================
-- Enforced at the DB level so it can't be bypassed by calling Supabase's REST/RPC
-- API directly. The app should still show its own overlap check immediately for UX
-- (the red "the date overlaps" banner, FINDS-S05) -- this trigger is the real backstop,
-- not a replacement for that.
--
-- Scheduled bengs: a passenger may hold multiple pending/accepted requests as long as
-- their [depart_time, arrival_time] windows don't overlap (resolved rule, supersedes the
-- old "1 active request" assumption). Quick bengs: max 1 pending at a time, checked
-- separately (not a date-range overlap, since quick bengs are always "now").

create or replace function check_request_overlap()
returns trigger as $$
declare
  conflicting_count int;
begin
  if new.status not in ('pending', 'accepted') then
    return new; -- only pending/accepted requests count as "active" for overlap purposes
  end if;

  select count(*) into conflicting_count
  from request r
  join beng_daily bd on bd.id = r.beng_daily_id
  join beng b on b.id = bd.beng_id
  where r.profile_id = new.profile_id
    and r.id is distinct from new.id
    and r.status in ('pending', 'accepted')
    and b.mode = 'scheduled'
    and tstzrange(r.depart_time, r.arrival_time) && tstzrange(new.depart_time, new.arrival_time);

  if conflicting_count > 0 then
    raise exception 'Request overlaps an existing pending or accepted request for this passenger'
      using errcode = '23514'; -- check_violation, so Supabase surfaces it as a client-catchable error
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_request_overlap_check on request;
create trigger trg_request_overlap_check
  before insert or update on request
  for each row execute function check_request_overlap();
