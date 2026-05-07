alter table public.users
  add column if not exists display_name text not null default '',
  add column if not exists shop_name text not null default '',
  add column if not exists phone text not null default '',
  add column if not exists member_plan text not null default 'free',
  add column if not exists member_status text not null default 'active',
  add column if not exists plan_started_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_member_plan_check'
  ) then
    alter table public.users
      add constraint users_member_plan_check
      check (member_plan in ('free', 'pro'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_member_status_check'
  ) then
    alter table public.users
      add constraint users_member_status_check
      check (member_status in ('active', 'inactive'));
  end if;
end;
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_touch_updated_at on public.users;

create trigger users_touch_updated_at
  before update on public.users
  for each row execute function public.touch_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    email,
    display_name,
    shop_name,
    phone,
    member_plan,
    member_status,
    created_at,
    updated_at
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(new.raw_user_meta_data ->> 'shop_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    'free',
    'active',
    new.created_at,
    now()
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(
          nullif(public.users.display_name, ''),
          excluded.display_name
        ),
        shop_name = coalesce(
          nullif(public.users.shop_name, ''),
          excluded.shop_name
        ),
        phone = coalesce(
          nullif(public.users.phone, ''),
          excluded.phone
        ),
        updated_at = now();

  return new;
end;
$$;
