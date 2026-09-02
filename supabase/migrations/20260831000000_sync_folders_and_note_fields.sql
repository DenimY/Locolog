-- ==========================================
-- 동기화 보완: 즐겨찾기 / 폴더 / 노트 타입 / Realtime
-- ==========================================

alter table public.notes
  add column if not exists is_favorited boolean not null default false;

alter table public.notes
  add column if not exists folder_id uuid;

alter table public.notes
  add column if not exists note_type text not null default 'markdown';

alter table public.notes
  add column if not exists icon_emoji text;

-- 기존 category_id를 folder_id로 복사 (비어 있는 행만)
update public.notes
set folder_id = category_id
where folder_id is null and category_id is not null;

-- ==========================================
-- FOLDERS (트리형, 로컬 Folder 모델과 대응)
-- ==========================================
create table if not exists public.folders (
  id          uuid primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  parent_id   uuid,
  position    integer not null default 0,
  color_hex   text,
  icon_emoji  text,
  updated_at  timestamptz not null default now()
);

create index if not exists folders_user_id_idx on public.folders (user_id, position);

alter table public.folders enable row level security;

drop policy if exists "own folders" on public.folders;
create policy "own folders" on public.folders for all using (auth.uid() = user_id);

-- ==========================================
-- Realtime (이미 등록되어 있으면 무시)
-- ==========================================
do $$ begin
  alter publication supabase_realtime add table public.notes;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.folders;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.smart_folders;
exception when duplicate_object then null;
end $$;
