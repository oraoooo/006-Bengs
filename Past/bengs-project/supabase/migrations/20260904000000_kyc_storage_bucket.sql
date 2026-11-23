-- KYC/vehicle document photo storage — was called for by driver_verification
-- and vehicle's *_url columns (schema had the columns since the start) but
-- no bucket ever existed for them, so those fields were always written as
-- null. Private bucket: KTP/selfie/vehicle-registration photos are exactly
-- the kind of document that must never be publicly readable by URL guessing.
--
-- Path convention enforced by the policies below: "<auth.uid()>/<filename>"
-- — every object's first path segment must be the uploader's own user id.

insert into storage.buckets (id, name, public)
values ('driver-documents', 'driver-documents', false)
on conflict (id) do nothing;

create policy "Users can upload their own driver documents"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'driver-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can read their own driver documents"
on storage.objects for select
to authenticated
using (
  bucket_id = 'driver-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can replace their own driver documents"
on storage.objects for update
to authenticated
using (
  bucket_id = 'driver-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'driver-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete their own driver documents"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'driver-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);
