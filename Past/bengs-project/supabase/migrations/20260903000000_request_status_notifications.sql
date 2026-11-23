-- =====================================================================
-- Notify a passenger when their request is accepted/rejected.
--
-- The client can't do this insert itself: "notification is private to
-- owner" (auth.uid() = profile_id) correctly stops a driver's own client
-- from inserting a notification row owned by the passenger. A trigger
-- running as the function owner (security definer) is the right way to
-- cross that boundary — same pattern as the existing set_updated_at()
-- trigger, just doing more than touching one column.
-- =====================================================================

create or replace function notify_request_status_change()
returns trigger as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    insert into notification (profile_id, type, label, body)
    values (new.profile_id, 'request_accepted', 'Your request was accepted', 'Check your Schedule tab for the details.');
  elsif new.status = 'rejected' and old.status is distinct from 'rejected' then
    insert into notification (profile_id, type, label, body)
    values (new.profile_id, 'request_rejected', 'Your request was declined', null);
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_request_status_notify
  after update on request
  for each row execute function notify_request_status_change();
