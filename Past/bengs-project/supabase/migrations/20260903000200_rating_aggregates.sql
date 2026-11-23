-- =====================================================================
-- Keeps profiles.driver_rating/driver_count and passenger_rating/
-- passenger_count in sync with the driver_rating/passenger_rating tables.
--
-- This was a known gap: those profiles columns existed but nothing wrote
-- to them, so they'd have silently drifted from day one. Needed now that
-- rating submission is an actual feature (RatingRepository) — otherwise
-- submitting a rating would have no visible effect on the rated person's
-- profile. security definer because a rater updating someone ELSE's
-- profiles row (the rated person's aggregate) is correctly blocked by
-- "users update own profile" RLS otherwise — same cross-user-boundary
-- pattern as the request-status notification trigger.
-- =====================================================================

create or replace function refresh_driver_rating_aggregate()
returns trigger as $$
begin
  update profiles
  set driver_rating = (select round(avg(dr.score), 1) from driver_rating dr where dr.rated_id = new.rated_id),
      driver_count = (select count(*) from driver_rating dr where dr.rated_id = new.rated_id)
  where id = new.rated_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_driver_rating_aggregate
  after insert or update on driver_rating
  for each row execute function refresh_driver_rating_aggregate();

create or replace function refresh_passenger_rating_aggregate()
returns trigger as $$
begin
  update profiles
  set passenger_rating = (select round(avg(pr.score), 1) from passenger_rating pr where pr.rated_id = new.rated_id),
      passenger_count = (select count(*) from passenger_rating pr where pr.rated_id = new.rated_id)
  where id = new.rated_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_passenger_rating_aggregate
  after insert or update on passenger_rating
  for each row execute function refresh_passenger_rating_aggregate();
