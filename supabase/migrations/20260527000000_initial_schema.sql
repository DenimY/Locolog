-- ==========================================
-- NOTES
-- ==========================================
create table public.notes (
  id            uuid primary key,
  user_id       uuid references auth.users(id) on delete cascade not null,
  content       text not null default '',
  category_id   uuid,
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  location_lat  double precision,
  location_lng  double precision,
  location_name text,
  location_poi  text,
  reminder_at   timestamptz,
  is_deleted    boolean not null default false,
  is_public     boolean not null default false
);

-- ==========================================
-- CATEGORIES
-- ==========================================
create table public.categories (
  id          uuid primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  color_hex   text not null default '#4A90E2',
  icon        text,
  position    integer not null default 0,
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

-- ==========================================
-- TAGS
-- ==========================================
create table public.tags (
  id         uuid primary key,
  user_id    uuid references auth.users(id) on delete cascade not null,
  name       text not null,
  created_at timestamptz not null default now(),
  unique(user_id, name)
);

create table public.note_tags (
  note_id uuid references public.notes(id) on delete cascade,
  tag_id  uuid references public.tags(id) on delete cascade,
  primary key (note_id, tag_id)
);

-- ==========================================
-- SMART FOLDERS
-- ==========================================
create table public.smart_folders (
  id          uuid primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  filter_json jsonb not null default '{}',
  position    integer not null default 0,
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

-- ==========================================
-- TEAMS
-- ==========================================
create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 팀 멤버 (owner / admin / member)
create table public.team_members (
  team_id   uuid references public.teams(id) on delete cascade,
  user_id   uuid references auth.users(id) on delete cascade,
  role      text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- 카테고리 ↔ 팀 연결 (카테고리 단위 팀 공유)
create table public.team_categories (
  team_id     uuid references public.teams(id) on delete cascade,
  category_id uuid references public.categories(id) on delete cascade,
  added_by    uuid references auth.users(id) on delete set null,
  permission  text not null default 'read' check (permission in ('read', 'write')),
  added_at    timestamptz not null default now(),
  primary key (team_id, category_id)
);

-- ==========================================
-- NOTE SHARES (개별 메모 공유 + 링크 공유)
-- ==========================================
create table public.note_shares (
  id                  uuid primary key default gen_random_uuid(),
  note_id             uuid references public.notes(id) on delete cascade not null,
  owner_id            uuid references auth.users(id) on delete cascade not null,
  shared_with_user_id uuid references auth.users(id) on delete set null,
  shared_link_token   text unique,
  permission          text not null default 'read' check (permission in ('read', 'write')),
  created_at          timestamptz not null default now(),
  expires_at          timestamptz
);

-- ==========================================
-- RLS
-- ==========================================
alter table public.notes           enable row level security;
alter table public.categories      enable row level security;
alter table public.tags            enable row level security;
alter table public.note_tags       enable row level security;
alter table public.smart_folders   enable row level security;
alter table public.teams           enable row level security;
alter table public.team_members    enable row level security;
alter table public.team_categories enable row level security;
alter table public.note_shares     enable row level security;

-- Notes: 본인 + 직접 공유 + 공개 + 팀 카테고리
create policy "own notes" on public.notes for all using (auth.uid() = user_id);
create policy "read accessible notes" on public.notes for select using (
  is_public = true
  or exists (
    select 1 from public.note_shares ns
    where ns.note_id = notes.id
      and ns.shared_with_user_id = auth.uid()
      and (ns.expires_at is null or ns.expires_at > now())
  )
  or exists (
    select 1 from public.team_categories tc
    join public.team_members tm on tm.team_id = tc.team_id
    where tc.category_id = notes.category_id
      and tm.user_id = auth.uid()
  )
);
create policy "team write members can edit notes" on public.notes for update using (
  exists (
    select 1 from public.team_categories tc
    join public.team_members tm on tm.team_id = tc.team_id
    where tc.category_id = notes.category_id
      and tm.user_id = auth.uid()
      and tc.permission = 'write'
  )
);

-- Categories
create policy "own categories" on public.categories for all using (auth.uid() = user_id);
create policy "team members read categories" on public.categories for select using (
  exists (
    select 1 from public.team_categories tc
    join public.team_members tm on tm.team_id = tc.team_id
    where tc.category_id = categories.id and tm.user_id = auth.uid()
  )
);

-- Tags / Note Tags
create policy "own tags"      on public.tags      for all using (auth.uid() = user_id);
create policy "own note tags" on public.note_tags for all using (
  exists (select 1 from public.notes where notes.id = note_tags.note_id and notes.user_id = auth.uid())
);

-- Smart Folders
create policy "own smart folders" on public.smart_folders for all using (auth.uid() = user_id);

-- Teams
create policy "team members view"  on public.teams for select using (
  exists (select 1 from public.team_members where team_id = teams.id and user_id = auth.uid())
);
create policy "anyone create team" on public.teams for insert with check (true);
create policy "admin update team"  on public.teams for update using (
  exists (select 1 from public.team_members where team_id = teams.id and user_id = auth.uid() and role in ('owner', 'admin'))
);
create policy "owner delete team"  on public.teams for delete using (
  exists (select 1 from public.team_members where team_id = teams.id and user_id = auth.uid() and role = 'owner')
);

-- Team Members
create policy "members view team"    on public.team_members for select using (
  exists (select 1 from public.team_members tm2 where tm2.team_id = team_members.team_id and tm2.user_id = auth.uid())
);
create policy "admin manage members" on public.team_members for all using (
  exists (select 1 from public.team_members tm2 where tm2.team_id = team_members.team_id and tm2.user_id = auth.uid() and tm2.role in ('owner', 'admin'))
);
create policy "member can leave"     on public.team_members for delete using (auth.uid() = user_id);

-- Team Categories
create policy "members view team cats" on public.team_categories for select using (
  exists (select 1 from public.team_members where team_id = team_categories.team_id and user_id = auth.uid())
);
create policy "admin manage team cats" on public.team_categories for all using (
  exists (select 1 from public.team_members where team_id = team_categories.team_id and user_id = auth.uid() and role in ('owner', 'admin'))
);

-- Note Shares
create policy "owner manages shares" on public.note_shares for all    using (auth.uid() = owner_id);
create policy "shared user reads"    on public.note_shares for select using (auth.uid() = shared_with_user_id);
