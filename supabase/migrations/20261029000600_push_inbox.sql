-- NT-2 push tokens and in-app inbox (06_SUPABASE_SCHEMA_PROPOSAL §7, D-19,
-- L-D30). Local reminders (NT-1) stay on the phone and use none of this.
--
-- * A device token belongs to one account at a time: registering it moves
--   it to the signed-in user, signing out removes it.
-- * send-push (service role) writes the inbox row first, then pushes only
--   a short title and the repcoach:// link (the N-2a router input), never
--   personal data. The app holds pushes during a live workout (D-19).
-- * Clients read their own inbox and mark items read; nothing else.

create table if not exists public.push_tokens (
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null check (char_length(token) between 8 and 512),
  platform text not null check (platform in ('apns', 'fcm')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
create unique index if not exists push_tokens_token on public.push_tokens (token);

create table if not exists public.inbox_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in
    ('friend_request', 'race', 'invite', 'billing', 'system')),
  link text not null check (link like 'repcoach://%' and char_length(link) <= 300),
  title text not null check (char_length(title) between 1 and 120),
  body text check (char_length(body) <= 500),
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists inbox_items_user on public.inbox_items (user_id, created_at desc);

create or replace trigger push_tokens_updated_at before update on public.push_tokens
  for each row execute function public.set_updated_at();

alter table public.push_tokens enable row level security;
alter table public.inbox_items enable row level security;
revoke all on public.push_tokens, public.inbox_items from public, anon, authenticated;
grant select on public.push_tokens, public.inbox_items to authenticated;
grant select, insert, update, delete on public.push_tokens, public.inbox_items
  to service_role;

create policy "push_tokens: owner can read"
  on public.push_tokens for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "inbox_items: owner can read"
  on public.inbox_items for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.push_me() returns uuid
language plpgsql stable set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return v_user;
end $$;

create or replace function public.inbox_item_json(i public.inbox_items)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('id', i.id, 'kind', i.kind, 'link', i.link,
    'title', i.title, 'body', i.body, 'created_at', i.created_at,
    'read_at', i.read_at)
$$;

-- App: register / refresh this device's token for the signed-in user.
create or replace function public.push_register_token(p_platform text, p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.push_me();
begin
  if p_platform not in ('apns', 'fcm')
     or char_length(coalesce(p_token, '')) not between 8 and 512 then
    raise exception 'invalid_argument' using errcode = '22023';
  end if;
  delete from public.push_tokens where token = p_token and user_id <> v_me;
  insert into public.push_tokens as t (user_id, token, platform)
  values (v_me, p_token, p_platform)
  on conflict (user_id, token) do update set platform = excluded.platform,
    updated_at = now();
  return jsonb_build_object('ok', true);
end $$;

-- App: sign-out on this device.
create or replace function public.push_unregister_token(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  delete from public.push_tokens
    where user_id = public.push_me() and token = p_token;
  return jsonb_build_object('ok', true);
end $$;

-- App: my inbox, newest first (at most 100).
create or replace function public.inbox_list(p_limit int default 50)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(public.inbox_item_json(x.i) order by (x.i).created_at desc),
    '[]'::jsonb)
  from (
    select i from public.inbox_items i
    where i.user_id = public.push_me()
    order by i.created_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
  ) x
$$;

create or replace function public.inbox_mark_read(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  update public.inbox_items set read_at = now()
    where id = p_id and user_id = public.push_me() and read_at is null;
  return jsonb_build_object('ok', true);
end $$;

-- send-push (service role): the inbox row first, then the tokens to push to.
create or replace function public.inbox_create(
  p_user uuid, p_kind text, p_link text, p_title text, p_body text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_item public.inbox_items;
begin
  insert into public.inbox_items (user_id, kind, link, title, body)
  values (p_user, p_kind, p_link, p_title, p_body)
  returning * into v_item;
  return jsonb_build_object(
    'item', public.inbox_item_json(v_item),
    'tokens', coalesce((select jsonb_agg(jsonb_build_object(
        'token', t.token, 'platform', t.platform))
      from public.push_tokens t where t.user_id = p_user), '[]'::jsonb));
end $$;

-- send-push (service role): forget a token the push service rejected.
create or replace function public.push_drop_token(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.push_tokens where token = p_token
$$;

revoke execute on function
  public.push_me(),
  public.inbox_item_json(public.inbox_items),
  public.push_register_token(text, text),
  public.push_unregister_token(text),
  public.inbox_list(int),
  public.inbox_mark_read(uuid),
  public.inbox_create(uuid, text, text, text, text),
  public.push_drop_token(text)
from public, anon, authenticated;

grant execute on function
  public.push_register_token(text, text),
  public.push_unregister_token(text),
  public.inbox_list(int),
  public.inbox_mark_read(uuid)
to authenticated;
grant execute on function
  public.inbox_create(uuid, text, text, text, text),
  public.push_drop_token(text)
to service_role;
