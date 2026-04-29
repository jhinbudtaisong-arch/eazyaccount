create or replace function public.create_entry_with_items(
  p_raw_text text,
  p_items jsonb
)
returns table (
  entry_id uuid,
  raw_text text,
  type public.entry_kind,
  income_total numeric,
  expense_total numeric,
  created_at timestamptz
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  inserted_entry_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required';
  end if;

  if p_raw_text is null or btrim(p_raw_text) = '' then
    raise exception 'raw_text is required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'items must be a non-empty array';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_items) as item(value)
    where coalesce(btrim(item.value ->> 'name'), '') = ''
      or (item.value ->> 'amount') is null
      or not (item.value ->> 'amount' ~ '^[0-9]+(\.[0-9]+)?$')
      or (item.value ->> 'amount')::numeric < 0
      or item.value ->> 'type' not in ('income', 'expense')
  ) then
    raise exception 'items contain invalid values';
  end if;

  insert into public.entries (user_id, raw_text)
  values ((select auth.uid()), btrim(p_raw_text))
  returning id into inserted_entry_id;

  insert into public.entry_items (entry_id, name, amount, type)
  select
    inserted_entry_id,
    btrim(item.value ->> 'name'),
    (item.value ->> 'amount')::numeric,
    (item.value ->> 'type')::public.entry_item_kind
  from jsonb_array_elements(p_items) as item(value);

  return query
  select
    entries.id,
    entries.raw_text,
    entries.type,
    entries.income_total,
    entries.expense_total,
    entries.created_at
  from public.entries
  where entries.id = inserted_entry_id;
end;
$$;
