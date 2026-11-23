-- Prep only, per bengs Draft.pdf's ADDITIONAL FEEDBACK section — the
-- optional profile-enrichment fields that would drive "cool person"/"cool
-- friend" matching tags (same age, same school, shared interests, etc.)
-- and their per-field public/cool-friends-only privacy toggles. This adds
-- the storage for that data; it does NOT implement any matching, tagging,
-- filtering, or scoring logic — that's real algorithm/design work still
-- to be scoped, not something to guess at here.
--
-- One JSONB visibility map rather than a boolean column per field: the doc
-- lists 6 independent toggles today and says "you can add more" — a map
-- keyed by field name scales without a migration per new field.

alter table profiles add column if not exists bio text;
alter table profiles add column if not exists interests jsonb not null default '[]'::jsonb;
alter table profiles add column if not exists job_title varchar(200);
alter table profiles add column if not exists workplace_name varchar(200);
alter table profiles add column if not exists neighbourhood varchar(200);
alter table profiles add column if not exists instagram_handle varchar(100);

-- Per bengs Draft.pdf: "default privacy is public" for bio/interests,
-- "default privacy is cool friends" for job_title/workplace_name/
-- neighbourhood/instagram_handle. Age has no visibility key at all here —
-- the doc treats "don't check it" (i.e. leave date_of_birth out of this
-- map) as the only way to hide it, since date_of_birth itself is not
-- nullable (BR-01/02 age gating depends on it always being set).
alter table profiles add column if not exists profile_visibility jsonb not null default
  '{"bio": "public", "interests": "public", "job_title": "cool_friends", "workplace_name": "cool_friends", "neighbourhood": "cool_friends", "instagram_handle": "cool_friends"}'::jsonb;

-- "Profile also has a toggle whether they want to let their cool friends
-- can text them (currently through whatsapp) or not" — reuses the
-- phone_number column added in 20260904000200; this just gates whether
-- BR-11's WhatsApp button shows for non-mutual "cool friends".
alter table profiles add column if not exists allow_cool_friends_whatsapp boolean not null default true;
