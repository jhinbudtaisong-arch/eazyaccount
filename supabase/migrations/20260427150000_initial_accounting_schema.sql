create type public.entry_kind as enum ('income', 'expense', 'mixed');
create type public.entry_item_kind as enum ('income', 'expense');

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now()
);

create table public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  raw_text text not null,
  type public.entry_kind not null default 'mixed',
  income_total numeric(12, 2) not null default 0,
  expense_total numeric(12, 2) not null default 0,
  created_at timestamptz not null default now(),
  constraint entries_totals_non_negative check (
    income_total >= 0 and expense_total >= 0
  )
);

create table public.entry_items (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.entries (id) on delete cascade,
  name text not null,
  amount numeric(12, 2) not null,
  type public.entry_item_kind not null,
  created_at timestamptz not null default now(),
  constraint entry_items_amount_non_negative check (amount >= 0)
);

create table public.daily_summary (
  user_id uuid not null references public.users (id) on delete cascade,
  date date not null,
  income_total numeric(12, 2) not null default 0,
  expense_total numeric(12, 2) not null default 0,
  net_total numeric(12, 2) not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, date)
);

create table public.monthly_summary (
  user_id uuid not null references public.users (id) on delete cascade,
  month date not null,
  income_total numeric(12, 2) not null default 0,
  expense_total numeric(12, 2) not null default 0,
  net_total numeric(12, 2) not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, month),
  constraint monthly_summary_month_start check (
    month = date_trunc('month', month)::date
  )
);

create index entries_user_created_id_idx
  on public.entries (user_id, created_at desc, id desc);

create index entries_user_type_created_idx
  on public.entries (user_id, type, created_at desc);

create index entry_items_entry_id_idx
  on public.entry_items (entry_id);

create index entry_items_entry_type_idx
  on public.entry_items (entry_id, type);

create index daily_summary_user_date_desc_idx
  on public.daily_summary (user_id, date desc);

create index monthly_summary_user_month_desc_idx
  on public.monthly_summary (user_id, month desc);

alter table public.users enable row level security;
alter table public.entries enable row level security;
alter table public.entry_items enable row level security;
alter table public.daily_summary enable row level security;
alter table public.monthly_summary enable row level security;

create policy users_select_own
  on public.users for select
  to authenticated
  using (id = (select auth.uid()));

create policy users_update_own
  on public.users for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy entries_select_own
  on public.entries for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy entries_insert_own
  on public.entries for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy entries_update_own
  on public.entries for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy entries_delete_own
  on public.entries for delete
  to authenticated
  using (user_id = (select auth.uid()));

create policy entry_items_select_own
  on public.entry_items for select
  to authenticated
  using (
    exists (
      select 1
      from public.entries
      where entries.id = entry_items.entry_id
        and entries.user_id = (select auth.uid())
    )
  );

create policy entry_items_insert_own
  on public.entry_items for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.entries
      where entries.id = entry_items.entry_id
        and entries.user_id = (select auth.uid())
    )
  );

create policy entry_items_update_own
  on public.entry_items for update
  to authenticated
  using (
    exists (
      select 1
      from public.entries
      where entries.id = entry_items.entry_id
        and entries.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.entries
      where entries.id = entry_items.entry_id
        and entries.user_id = (select auth.uid())
    )
  );

create policy entry_items_delete_own
  on public.entry_items for delete
  to authenticated
  using (
    exists (
      select 1
      from public.entries
      where entries.id = entry_items.entry_id
        and entries.user_id = (select auth.uid())
    )
  );

create policy daily_summary_select_own
  on public.daily_summary for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy monthly_summary_select_own
  on public.monthly_summary for select
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, created_at)
  values (new.id, coalesce(new.email, ''), new.created_at)
  on conflict (id) do update
    set email = excluded.email;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create or replace function public.rebuild_daily_summary(
  target_user_id uuid,
  target_date date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  next_date date := target_date + 1;
  totals record;
begin
  select
    coalesce(sum(income_total), 0) as income_total,
    coalesce(sum(expense_total), 0) as expense_total
  into totals
  from public.entries
  where user_id = target_user_id
    and created_at >= target_date::timestamptz
    and created_at < next_date::timestamptz;

  if totals.income_total = 0 and totals.expense_total = 0 then
    delete from public.daily_summary
    where user_id = target_user_id and date = target_date;
  else
    insert into public.daily_summary (
      user_id,
      date,
      income_total,
      expense_total,
      net_total,
      updated_at
    )
    values (
      target_user_id,
      target_date,
      totals.income_total,
      totals.expense_total,
      totals.income_total - totals.expense_total,
      now()
    )
    on conflict (user_id, date) do update
      set income_total = excluded.income_total,
          expense_total = excluded.expense_total,
          net_total = excluded.net_total,
          updated_at = excluded.updated_at;
  end if;
end;
$$;

create or replace function public.rebuild_monthly_summary(
  target_user_id uuid,
  target_month date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  month_start date := date_trunc('month', target_month)::date;
  next_month date := (date_trunc('month', target_month) + interval '1 month')::date;
  totals record;
begin
  select
    coalesce(sum(income_total), 0) as income_total,
    coalesce(sum(expense_total), 0) as expense_total
  into totals
  from public.entries
  where user_id = target_user_id
    and created_at >= month_start::timestamptz
    and created_at < next_month::timestamptz;

  if totals.income_total = 0 and totals.expense_total = 0 then
    delete from public.monthly_summary
    where user_id = target_user_id and month = month_start;
  else
    insert into public.monthly_summary (
      user_id,
      month,
      income_total,
      expense_total,
      net_total,
      updated_at
    )
    values (
      target_user_id,
      month_start,
      totals.income_total,
      totals.expense_total,
      totals.income_total - totals.expense_total,
      now()
    )
    on conflict (user_id, month) do update
      set income_total = excluded.income_total,
          expense_total = excluded.expense_total,
          net_total = excluded.net_total,
          updated_at = excluded.updated_at;
  end if;
end;
$$;

create or replace function public.refresh_entry_summaries()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.rebuild_daily_summary(new.user_id, new.created_at::date);
    perform public.rebuild_monthly_summary(new.user_id, date_trunc('month', new.created_at)::date);
  end if;

  if tg_op in ('UPDATE', 'DELETE') then
    perform public.rebuild_daily_summary(old.user_id, old.created_at::date);
    perform public.rebuild_monthly_summary(old.user_id, date_trunc('month', old.created_at)::date);
  end if;

  return coalesce(new, old);
end;
$$;

create trigger entries_refresh_summaries
  after insert or update or delete on public.entries
  for each row execute function public.refresh_entry_summaries();

create or replace function public.rebuild_entry_totals(target_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  totals record;
  next_type public.entry_kind;
begin
  select
    coalesce(sum(amount) filter (where type = 'income'), 0) as income_total,
    coalesce(sum(amount) filter (where type = 'expense'), 0) as expense_total
  into totals
  from public.entry_items
  where entry_id = target_entry_id;

  next_type := case
    when totals.income_total > 0 and totals.expense_total > 0 then 'mixed'::public.entry_kind
    when totals.income_total > 0 then 'income'::public.entry_kind
    when totals.expense_total > 0 then 'expense'::public.entry_kind
    else 'mixed'::public.entry_kind
  end;

  update public.entries
  set income_total = totals.income_total,
      expense_total = totals.expense_total,
      type = next_type
  where id = target_entry_id;
end;
$$;

create or replace function public.refresh_entry_totals_from_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.rebuild_entry_totals(new.entry_id);
  end if;

  if tg_op in ('UPDATE', 'DELETE') then
    perform public.rebuild_entry_totals(old.entry_id);
  end if;

  return coalesce(new, old);
end;
$$;

create trigger entry_items_refresh_entry_totals
  after insert or update or delete on public.entry_items
  for each row execute function public.refresh_entry_totals_from_items();

create or replace function public.get_entries_page(
  page_size int default 20,
  before_created_at timestamptz default null,
  before_id uuid default null
)
returns table (
  id uuid,
  raw_text text,
  type public.entry_kind,
  income_total numeric,
  expense_total numeric,
  created_at timestamptz
)
language sql
security invoker
stable
set search_path = public
as $$
  select
    entries.id,
    entries.raw_text,
    entries.type,
    entries.income_total,
    entries.expense_total,
    entries.created_at
  from public.entries
  where entries.user_id = (select auth.uid())
    and (
      before_created_at is null
      or (entries.created_at, entries.id) < (before_created_at, before_id)
    )
  order by entries.created_at desc, entries.id desc
  limit least(greatest(page_size, 1), 100);
$$;
