-- 0002: pub golf games.
-- The organiser (an auth user, anonymous sign-in is fine) owns the game and is the only one who
-- writes to it. Anyone who joins with the 6 character code becomes a follower and can read it live.
-- Players are names on the scorecard, not accounts.

create type public.game_status as enum ('lobby', 'live', 'finished');

create table public.games (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  name text not null check (char_length(name) between 1 and 60),
  organiser_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  status public.game_status not null default 'lobby',
  current_hole_index integer not null default 0 check (current_hole_index >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.holes (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  position integer not null check (position >= 0),
  pub_name text not null check (char_length(pub_name) between 1 and 80),
  address text not null default '' check (char_length(address) <= 200),
  drink text not null default '' check (char_length(drink) <= 60),
  par integer not null check (par between 1 and 30),
  unique (game_id, position)
);

create table public.penalty_rules (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  strokes integer not null check (strokes between 1 and 10)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  created_at timestamptz not null default now()
);
create unique index teams_game_name_key on public.teams (game_id, lower(name));

create table public.players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  team_id uuid references public.teams (id) on delete set null,
  name text not null check (char_length(name) between 1 and 40),
  created_at timestamptz not null default now()
);
create unique index players_game_name_key on public.players (game_id, lower(name));

create table public.scores (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  hole_id uuid not null references public.holes (id) on delete cascade,
  sips integer not null check (sips between 1 and 99),
  penalty_ids uuid[] not null default '{}',
  updated_at timestamptz not null default now(),
  unique (player_id, hole_id)
);

create table public.game_followers (
  game_id uuid not null references public.games (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (game_id, user_id)
);

create index holes_game_id_idx on public.holes (game_id);
create index penalty_rules_game_id_idx on public.penalty_rules (game_id);
create index players_team_id_idx on public.players (team_id);
create index scores_game_id_idx on public.scores (game_id);
create index scores_hole_id_idx on public.scores (hole_id);
create index games_organiser_id_idx on public.games (organiser_id);
create index game_followers_user_id_idx on public.game_followers (user_id);

create trigger games_touch_updated_at
  before update on public.games
  for each row execute function public.touch_updated_at();

create trigger scores_touch_updated_at
  before update on public.scores
  for each row execute function public.touch_updated_at();

-- Access helpers. Security definer so policies can check membership without recursing into RLS.
create function public.is_game_organiser(target_game uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.games g
    where g.id = target_game and g.organiser_id = (select auth.uid())
  );
$$;

create function public.can_view_game(target_game uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_game_organiser(target_game) or exists (
    select 1 from public.game_followers f
    where f.game_id = target_game and f.user_id = (select auth.uid())
  );
$$;

-- Scores can only be written while the round is live, for holes the group has reached.
create function public.can_score(target_game uuid, target_hole uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.games g
    join public.holes h on h.game_id = g.id
    where g.id = target_game
      and h.id = target_hole
      and g.organiser_id = (select auth.uid())
      and g.status = 'live'
      and h.position <= g.current_hole_index
  );
$$;

alter table public.games enable row level security;
alter table public.holes enable row level security;
alter table public.penalty_rules enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.scores enable row level security;
alter table public.game_followers enable row level security;

-- games
create policy "Organisers and followers can read games"
  on public.games for select to authenticated
  using (public.can_view_game(id));
create policy "Organisers can update their games"
  on public.games for update to authenticated
  using ((select auth.uid()) = organiser_id)
  with check ((select auth.uid()) = organiser_id);
create policy "Organisers can delete their games"
  on public.games for delete to authenticated
  using ((select auth.uid()) = organiser_id);

-- holes, penalty rules, teams, players: readable by viewers, writable by the organiser.
create policy "Viewers can read holes" on public.holes for select to authenticated
  using (public.can_view_game(game_id));
create policy "Organisers manage holes" on public.holes for all to authenticated
  using (public.is_game_organiser(game_id)) with check (public.is_game_organiser(game_id));

create policy "Viewers can read penalty rules" on public.penalty_rules for select to authenticated
  using (public.can_view_game(game_id));
create policy "Organisers manage penalty rules" on public.penalty_rules for all to authenticated
  using (public.is_game_organiser(game_id)) with check (public.is_game_organiser(game_id));

create policy "Viewers can read teams" on public.teams for select to authenticated
  using (public.can_view_game(game_id));
create policy "Organisers manage teams" on public.teams for all to authenticated
  using (public.is_game_organiser(game_id)) with check (public.is_game_organiser(game_id));

create policy "Viewers can read players" on public.players for select to authenticated
  using (public.can_view_game(game_id));
create policy "Organisers manage players" on public.players for all to authenticated
  using (public.is_game_organiser(game_id)) with check (public.is_game_organiser(game_id));

-- scores
create policy "Viewers can read scores" on public.scores for select to authenticated
  using (public.can_view_game(game_id));
create policy "Organisers add scores" on public.scores for insert to authenticated
  with check (public.can_score(game_id, hole_id));
create policy "Organisers edit scores" on public.scores for update to authenticated
  using (public.can_score(game_id, hole_id)) with check (public.can_score(game_id, hole_id));
create policy "Organisers delete scores" on public.scores for delete to authenticated
  using (public.is_game_organiser(game_id));

-- followers: a user sees and removes their own follows. Joining goes through join_game().
create policy "Users see their own follows" on public.game_followers for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can unfollow" on public.game_followers for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Players and scores must belong to the same game as their team / hole.
create function public.check_player_team()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.team_id is not null
     and not exists (select 1 from public.teams t where t.id = new.team_id and t.game_id = new.game_id) then
    raise exception 'team belongs to a different game';
  end if;
  return new;
end;
$$;

create function public.check_score_game()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select 1 from public.players p where p.id = new.player_id and p.game_id = new.game_id)
     or not exists (select 1 from public.holes h where h.id = new.hole_id and h.game_id = new.game_id) then
    raise exception 'player or hole belongs to a different game';
  end if;
  return new;
end;
$$;

create trigger players_check_team
  before insert or update on public.players
  for each row execute function public.check_player_team();

create trigger scores_check_game
  before insert or update on public.scores
  for each row execute function public.check_score_game();

-- Create a game with its route and penalties in one call. Returns the new game id.
-- holes: [{"pub_name", "address", "drink", "par"}], penalties: [{"name", "strokes"}]
create function public.create_game(
  game_name text,
  holes jsonb,
  penalties jsonb default '[]',
  organiser_player_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code text;
  new_game uuid;
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'sign in first';
  end if;
  if jsonb_typeof(holes) <> 'array' or jsonb_array_length(holes) = 0 then
    raise exception 'add at least one hole';
  end if;

  loop
    select string_agg(substr(alphabet, 1 + floor(random() * length(alphabet))::integer, 1), '')
      into new_code
      from generate_series(1, 6);
    exit when not exists (select 1 from public.games g where g.code = new_code);
  end loop;

  insert into public.games (code, name, organiser_id)
  values (new_code, btrim(game_name), uid)
  returning id into new_game;

  insert into public.holes (game_id, position, pub_name, address, drink, par)
  select new_game,
         (h.ordinality - 1)::integer,
         btrim(h.value ->> 'pub_name'),
         coalesce(btrim(h.value ->> 'address'), ''),
         coalesce(btrim(h.value ->> 'drink'), ''),
         (h.value ->> 'par')::integer
  from jsonb_array_elements(holes) with ordinality as h (value, ordinality);

  insert into public.penalty_rules (game_id, name, strokes)
  select new_game, btrim(p.value ->> 'name'), (p.value ->> 'strokes')::integer
  from jsonb_array_elements(coalesce(penalties, '[]'::jsonb)) as p (value)
  where coalesce(btrim(p.value ->> 'name'), '') <> '';

  if coalesce(btrim(organiser_player_name), '') <> '' then
    insert into public.players (game_id, name) values (new_game, btrim(organiser_player_name));
  end if;

  return new_game;
end;
$$;

-- Follow a game by its code. Returns the game id.
create function public.join_game(game_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid;
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'sign in first';
  end if;
  select g.id into target
  from public.games g
  where g.code = upper(regexp_replace(game_code, '[\s-]', '', 'g'));
  if target is null then
    raise exception 'no game with that code';
  end if;
  insert into public.game_followers (game_id, user_id)
  values (target, uid)
  on conflict do nothing;
  return target;
end;
$$;

revoke execute on function public.create_game(text, jsonb, jsonb, text) from public, anon;
revoke execute on function public.join_game(text) from public, anon;
grant execute on function public.create_game(text, jsonb, jsonb, text) to authenticated;
grant execute on function public.join_game(text) to authenticated;

-- Live updates for followers.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.games, public.teams, public.players, public.scores;
  end if;
end;
$$;
