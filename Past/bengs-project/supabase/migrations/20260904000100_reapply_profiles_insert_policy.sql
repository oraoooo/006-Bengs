-- Re-apply idempotently: a Google-OAuth account hit "new row violates
-- row-level security policy for table profiles" (code 42501) on the
-- CompleteProfileScreen insert, meaning 20260902000000's policy either
-- never actually landed on this project or was somehow lost. This is
-- safe to run any number of times.

drop policy if exists "users insert own profile" on profiles;

create policy "users insert own profile"
  on profiles for insert
  to authenticated
  with check (auth.uid() = id);
