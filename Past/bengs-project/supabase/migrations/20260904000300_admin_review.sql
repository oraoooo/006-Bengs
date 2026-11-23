-- Admin approval for driver_verification/vehicle — until now the only way
-- to move a KYC submission from 'pending' to 'verified' was hand-editing
-- the row in Supabase's table editor. This adds a minimal is_admin flag
-- and the RLS an admin actually needs to review and act on OTHER people's
-- pending submissions (their existing owner-only policies correctly block
-- this — an admin is a deliberate, narrow exception, not a relaxation).
--
-- After running this, flip your own account to admin once by hand:
--   update profiles set is_admin = true where id = '<your auth uid>';

alter table profiles add column if not exists is_admin boolean not null default false;

-- driver_verification: owner-only select already exists (BR-05) — add an
-- admin-only exception rather than widen the owner policy.
create policy "admins can view all driver verifications"
  on driver_verification for select
  to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));

create policy "admins can update any driver verification"
  on driver_verification for update
  to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));

-- vehicle already has a public select policy; update was owner-only.
create policy "admins can update any vehicle"
  on vehicle for update
  to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));

-- storage.objects' existing policies (20260904000000) only let the
-- uploader read/write their own "<uid>/..." prefix — an admin reviewing
-- someone else's KTP/selfie/STNK photo needs a matching exception there.
create policy "admins can read any driver document"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'driver-documents'
    and exists (select 1 from profiles where id = auth.uid() and is_admin)
  );
