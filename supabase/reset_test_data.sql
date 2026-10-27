-- Full data reset for fresh testing.
-- Wipes: clients, client_transactions, income_expenses, reminders.
-- Keeps: profiles, categories (the app needs these to keep working —
-- categories are seeded once at signup and there's no re-seed screen yet).
--
-- Runs as the Supabase SQL Editor's postgres role, which bypasses RLS —
-- this deletes data for EVERY user in the project, not just one account.
-- Fine for a solo test project; if you ever add real users, scope each
-- DELETE with `where user_id = '<uuid>'` instead.

begin;

delete from public.reminders;
delete from public.income_expenses;
delete from public.client_transactions;
delete from public.clients;

commit;

-- Sanity check — should all read 0 after running the block above.
select
  (select count(*) from public.clients) as clients,
  (select count(*) from public.client_transactions) as client_transactions,
  (select count(*) from public.income_expenses) as income_expenses,
  (select count(*) from public.reminders) as reminders;
