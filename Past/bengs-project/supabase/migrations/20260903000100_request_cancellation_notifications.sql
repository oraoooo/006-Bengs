-- =====================================================================
-- Extends notify_request_status_change() (20260903000000) to also notify
-- a passenger when their already-accepted request gets cancelled — e.g.
-- BR-10's "Cancel The Day" action, which cascades an accepted request to
-- status = 'cancelled'.
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
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    insert into notification (profile_id, type, label, body)
    values (new.profile_id, 'request_cancelled', 'Your ride was cancelled', new.cancel_reason);
  end if;
  return new;
end;
$$ language plpgsql security definer;
