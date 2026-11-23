-- =====================================================================
-- BENGS — Supabase/Postgres Schema
-- Version: 2.0 | 1 September 2026
--
-- CHANGES vs. BENGS_schema.sql (the MySQL/Laravel version):
--   1. snake_case throughout (was camelCase) — Postgres lowercases
--      unquoted identifiers, so camelCase requires quoting *everywhere,
--      forever*, including inside Supabase's auto-generated API. Not
--      worth the fragility. Dart-side models stay camelCase; the
--      conversion happens at fromJson/toJson, not in the database.
--   2. `authToken` and `session` tables DROPPED — Supabase Auth (GoTrue)
--      already handles OTP, password reset, sessions, and JWTs. Rebuilding
--      these ourselves would duplicate (less securely) what's already free.
--   3. `user` table renamed to `profiles`, with `id` (UUID) referencing
--      Supabase's own `auth.users(id)` — the standard Supabase pattern.
--   4. All other primary keys switched from app-generated prefixed
--      strings to native Postgres UUIDs (`gen_random_uuid()`), matching
--      how Supabase and its Flutter client expect IDs to work.
--   5. JSON -> JSONB (indexed, binary — the Postgres-recommended type).
--   6. TIMESTAMP -> TIMESTAMPTZ (timezone-aware; matters since BENGS
--      users won't all be in one UTC offset forever).
--   7. Postgres has no UNSIGNED types — replaced with CHECK constraints.
--   8. `updated_at` auto-update needs an explicit trigger in Postgres
--      (no `ON UPDATE CURRENT_TIMESTAMP` shorthand like MySQL) — one
--      reusable trigger function, applied per table.
--   9. Row Level Security (RLS) enabled with starter policies for the
--      access rules that actually matter (BR-05: passengers never see
--      driver KYC data).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Reusable trigger: auto-update updated_at on every row update
-- ---------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- =====================================================================
-- 1. PROFILES (extends Supabase auth.users — do not duplicate auth data)
-- =====================================================================

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name varchar(100) not null,
  surname varchar(100),
  gender varchar(10),
  date_of_birth date not null,                    -- drives BR-01/BR-02 age gating
  driver_count integer not null default 0 check (driver_count >= 0),
  driver_rating numeric(2,1),
  passenger_count integer not null default 0 check (passenger_count >= 0),
  passenger_rating numeric(2,1),
  parental_consent_status varchar(20) not null default 'not_required',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_profiles_updated_at before update on profiles
  for each row execute function set_updated_at();

comment on table profiles is 'Extends auth.users. Never holds KYC/KTP data — see driver_verification.';

-- =====================================================================
-- 2. PARENTAL CONSENT (BR-02 / FRD §5.2 — required only for users under 18)
-- =====================================================================

create table parental_consent (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles(id) on delete cascade,
  parent_name varchar(200) not null,
  parent_phone_number varchar(20) not null,
  parent_email varchar(100),
  consent_method varchar(20) not null,             -- otp_sms / otp_email / link
  status varchar(20) not null default 'pending',   -- pending / granted / revoked
  consented_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_parental_consent_updated_at before update on parental_consent
  for each row execute function set_updated_at();

-- =====================================================================
-- 3. DRIVER VERIFICATION (split from profiles — BR-03/BR-04)
-- =====================================================================

create table driver_verification (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles(id) on delete cascade,
  status varchar(20) not null default 'not_started', -- not_started/pending/verified/rejected
  submitted_at timestamptz,
  verified_at timestamptz,
  verified_by varchar(200),
  rejected_reason text,
  id_card_photo_url varchar(500),
  id_number varchar(50) unique,
  ktp_full_name varchar(200),
  ktp_date_of_birth date,
  ktp_gender varchar(10),
  address varchar(200),
  province varchar(100),
  city varchar(100),
  village varchar(100),
  district varchar(100),
  postcode varchar(20),
  additional_document_url varchar(500),
  id_card_selfie_url varchar(500),
  police_clearance_url varchar(500),
  is_disabled boolean not null default false,
  disability_type varchar(200),
  recommendation_letter_url varchar(500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_driver_verification_updated_at before update on driver_verification
  for each row execute function set_updated_at();

-- =====================================================================
-- 4. LICENSE & VEHICLE
-- =====================================================================

create table license (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles(id) on delete cascade,
  license_card_url varchar(500),
  license_number varchar(50),
  license_expiry_date date,
  license_class varchar(10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_license_updated_at before update on license
  for each row execute function set_updated_at();

create table vehicle (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  vehicle_type varchar(20) not null,               -- motor / mobil — BR-06
  vehicle_brand varchar(50),
  vehicle_model varchar(50),
  vehicle_license_plate varchar(15) not null unique,
  vehicle_registration_cert_url varchar(500),
  is_verified boolean not null default false,
  verified_at timestamptz,
  verified_by varchar(200),
  reject_reason text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_vehicle_profile on vehicle(profile_id);
create trigger trg_vehicle_updated_at before update on vehicle
  for each row execute function set_updated_at();

create table saved_location (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  location_label varchar(200) not null,
  location_name varchar(200) not null,
  location_latitude numeric(10,7) not null,
  location_longitude numeric(10,7) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_saved_location_profile on saved_location(profile_id);
create trigger trg_saved_location_updated_at before update on saved_location
  for each row execute function set_updated_at();

-- =====================================================================
-- 5. BENG (rides/routes) — scheduled + spontaneous
-- =====================================================================

create table beng (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references profiles(id) on delete cascade,
  vehicle_id uuid not null references vehicle(id) on delete restrict,
  mode varchar(20) not null default 'scheduled',   -- scheduled / spontaneous
  label varchar(50),
  origin_name varchar(200) not null,
  origin_latitude numeric(10,7) not null,
  origin_longitude numeric(10,7) not null,
  destination_name varchar(200),                   -- nullable: FR-SPN-12 open-destination offers
  destination_latitude numeric(10,7),
  destination_longitude numeric(10,7),
  price integer not null check (price >= 0),
  max_passenger smallint not null check (max_passenger > 0),  -- BR-09: concurrent-seat cap
  depart_time time not null,
  arrival_time time,
  repeat_frequency varchar(20),                    -- never/daily/weekly/monthly/yearly
  repeat_every smallint default 1,
  repeat_weekdays jsonb,                            -- e.g. ["SU","TH"]
  repeat_month_days jsonb,                          -- e.g. [17,18,24]
  repeat_months jsonb,                              -- e.g. [7,8,11]
  repeat_ordinal jsonb,                             -- e.g. [{"ordinal":3,"weekday":"TH"}]
  start_date date not null,
  end_date date,
  expires_at timestamptz,                           -- spontaneous only: FR-SPN-14
  status boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  delete_reason text
);
create index idx_beng_driver on beng(driver_id);
create index idx_beng_mode_status on beng(mode, status);
create trigger trg_beng_updated_at before update on beng
  for each row execute function set_updated_at();

create table beng_daily (
  id uuid primary key default gen_random_uuid(),
  beng_id uuid not null references beng(id) on delete cascade,
  date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancel_reason text,
  unique (beng_id, date)
);
create trigger trg_beng_daily_updated_at before update on beng_daily
  for each row execute function set_updated_at();

create table beng_route (
  id uuid primary key default gen_random_uuid(),
  beng_daily_id uuid not null references beng_daily(id) on delete cascade,
  location_name varchar(200) not null,
  location_latitude numeric(10,7) not null,
  location_longitude numeric(10,7) not null,
  stop_order smallint not null check (stop_order >= 0),
  passenger_id uuid not null references profiles(id) on delete cascade,
  passenger_state smallint not null,               -- 1 pick-up, -1 drop-off, 0 driver
  label varchar(100),
  eta timestamptz not null
);
create index idx_route_bengdaily_order on beng_route(beng_daily_id, stop_order);
create index idx_route_passenger on beng_route(passenger_id);

create table request (
  id uuid primary key default gen_random_uuid(),
  beng_daily_id uuid not null references beng_daily(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  mode varchar(20) not null default 'scheduled',
  status varchar(20) not null default 'pending',
  origin_name varchar(200) not null,
  origin_latitude numeric(10,7) not null,
  origin_longitude numeric(10,7) not null,
  destination_name varchar(200) not null,
  destination_latitude numeric(10,7) not null,
  destination_longitude numeric(10,7) not null,
  depart_time time not null,
  arrival_time time,
  response_deadline timestamptz,                    -- spontaneous only: FR-SPN-09
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancel_reason text
);
create index idx_request_bengdaily_status on request(beng_daily_id, status);
create index idx_request_profile on request(profile_id);
create trigger trg_request_updated_at before update on request
  for each row execute function set_updated_at();

-- =====================================================================
-- 6. SOCIAL (friends, blocks, ratings)
-- =====================================================================

create table friend (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  followed_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (profile_id, followed_id)
);
create index idx_friend_followed on friend(followed_id);

create table block (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (profile_id, blocked_id)
);

create table passenger_rating (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,  -- the driver rating
  rated_id uuid not null references profiles(id) on delete cascade,    -- the passenger rated
  beng_daily_id uuid not null references beng_daily(id) on delete cascade,
  score numeric(2,1) not null check (score between 0 and 5),
  review text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, rated_id, beng_daily_id)
);
create index idx_passenger_rating_rated on passenger_rating(rated_id);
create trigger trg_passenger_rating_updated_at before update on passenger_rating
  for each row execute function set_updated_at();

create table driver_rating (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,  -- the passenger rating
  rated_id uuid not null references profiles(id) on delete cascade,    -- the driver rated
  beng_daily_id uuid not null references beng_daily(id) on delete cascade,
  score numeric(2,1) not null check (score between 0 and 5),
  review text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, rated_id, beng_daily_id)
);
create index idx_driver_rating_rated on driver_rating(rated_id);
create trigger trg_driver_rating_updated_at before update on driver_rating
  for each row execute function set_updated_at();

-- =====================================================================
-- 7. NOTIFICATIONS
-- =====================================================================

create table notification (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  type varchar(100) not null,
  label varchar(200) not null,
  body text,
  related_url varchar(500),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notification_profile_read on notification(profile_id, is_read);

-- =====================================================================
-- 8. ROW LEVEL SECURITY — starter policies for the rules that matter
-- =====================================================================

alter table profiles enable row level security;
alter table driver_verification enable row level security;
alter table parental_consent enable row level security;
alter table license enable row level security;
alter table vehicle enable row level security;
alter table saved_location enable row level security;
alter table beng enable row level security;
alter table beng_daily enable row level security;
alter table beng_route enable row level security;
alter table request enable row level security;
alter table friend enable row level security;
alter table block enable row level security;
alter table passenger_rating enable row level security;
alter table driver_rating enable row level security;
alter table notification enable row level security;

-- Everyone can read basic profiles (needed for browsing drivers/passengers)
create policy "profiles are viewable by authenticated users"
  on profiles for select using (auth.role() = 'authenticated');

-- Users can only update their own profile
create policy "users update own profile"
  on profiles for update using (auth.uid() = id);

-- BR-05: driver_verification (KYC/KTP data) is visible ONLY to its owner —
-- this is the actual enforcement of "passengers never see driver KYC data"
create policy "driver_verification is private to owner"
  on driver_verification for select using (auth.uid() = profile_id);

create policy "driver_verification insert/update by owner"
  on driver_verification for all using (auth.uid() = profile_id);

-- parental_consent is private to the minor's own account
create policy "parental_consent is private to owner"
  on parental_consent for all using (auth.uid() = profile_id);

-- license is private to its owner (driving-license document data)
create policy "license is private to owner"
  on license for all using (auth.uid() = profile_id);

-- vehicle: browsable by anyone signed in (needed to show a beng's vehicle
-- info to a prospective passenger), but only the owner can create/edit/delete
create policy "vehicle is viewable by authenticated users"
  on vehicle for select using (auth.role() = 'authenticated');
create policy "vehicle is managed by owner"
  on vehicle for insert with check (auth.uid() = profile_id);
create policy "vehicle is updated by owner"
  on vehicle for update using (auth.uid() = profile_id);
create policy "vehicle is deleted by owner"
  on vehicle for delete using (auth.uid() = profile_id);

-- saved_location is private to its owner (personal address book)
create policy "saved_location is private to owner"
  on saved_location for all using (auth.uid() = profile_id);

-- beng: browsable by anyone signed in (Find-a-Beng needs this), but only
-- the driver who owns it can create/edit/delete
create policy "beng is viewable by authenticated users"
  on beng for select using (auth.role() = 'authenticated');
create policy "beng is managed by driver"
  on beng for insert with check (auth.uid() = driver_id);
create policy "beng is updated by driver"
  on beng for update using (auth.uid() = driver_id);
create policy "beng is deleted by driver"
  on beng for delete using (auth.uid() = driver_id);

-- beng_daily follows the same visibility as its parent beng, but only the
-- owning driver can modify it
create policy "beng_daily is viewable by authenticated users"
  on beng_daily for select using (auth.role() = 'authenticated');
create policy "beng_daily is managed by driver"
  on beng_daily for insert with check (
    exists (select 1 from beng where beng.id = beng_id and beng.driver_id = auth.uid())
  );
create policy "beng_daily is updated by driver"
  on beng_daily for update using (
    exists (select 1 from beng where beng.id = beng_id and beng.driver_id = auth.uid())
  );

-- beng_route holds per-passenger pickup/drop-off stops — visible only to
-- the driver of that route and the passenger assigned to that stop
create policy "beng_route is viewable by driver or the assigned passenger"
  on beng_route for select using (
    auth.uid() = passenger_id
    or exists (
      select 1 from beng_daily
      join beng on beng.id = beng_daily.beng_id
      where beng_daily.id = beng_daily_id and beng.driver_id = auth.uid()
    )
  );
create policy "beng_route is managed by driver"
  on beng_route for all using (
    exists (
      select 1 from beng_daily
      join beng on beng.id = beng_daily.beng_id
      where beng_daily.id = beng_daily_id and beng.driver_id = auth.uid()
    )
  );

-- request: visible to the requesting passenger and to the driver of the
-- beng being requested; only the passenger can create their own request
create policy "request is viewable by passenger or driver"
  on request for select using (
    auth.uid() = profile_id
    or exists (
      select 1 from beng_daily
      join beng on beng.id = beng_daily.beng_id
      where beng_daily.id = beng_daily_id and beng.driver_id = auth.uid()
    )
  );
create policy "request is created by passenger"
  on request for insert with check (auth.uid() = profile_id);
create policy "request is updated by passenger or driver"
  on request for update using (
    auth.uid() = profile_id
    or exists (
      select 1 from beng_daily
      join beng on beng.id = beng_daily.beng_id
      where beng_daily.id = beng_daily_id and beng.driver_id = auth.uid()
    )
  );

-- friend: visible to authenticated users (needed for friend lists/search),
-- but only the follower can create/remove their own follow
create policy "friend is viewable by authenticated users"
  on friend for select using (auth.role() = 'authenticated');
create policy "friend is managed by follower"
  on friend for insert with check (auth.uid() = profile_id);
create policy "friend is removed by follower"
  on friend for delete using (auth.uid() = profile_id);

-- block is private to the blocker — neither the blocked party nor anyone
-- else should be able to see who blocked whom
create policy "block is private to owner"
  on block for all using (auth.uid() = profile_id);

-- ratings: reviews are shown on public profiles (social-trust-first
-- matching), so select is open; only the rater can create/edit their own
create policy "passenger_rating is viewable by authenticated users"
  on passenger_rating for select using (auth.role() = 'authenticated');
create policy "passenger_rating is created by rater"
  on passenger_rating for insert with check (auth.uid() = profile_id);
create policy "passenger_rating is updated by rater"
  on passenger_rating for update using (auth.uid() = profile_id);

create policy "driver_rating is viewable by authenticated users"
  on driver_rating for select using (auth.role() = 'authenticated');
create policy "driver_rating is created by rater"
  on driver_rating for insert with check (auth.uid() = profile_id);
create policy "driver_rating is updated by rater"
  on driver_rating for update using (auth.uid() = profile_id);

-- notification is private to its owner
create policy "notification is private to owner"
  on notification for all using (auth.uid() = profile_id);
