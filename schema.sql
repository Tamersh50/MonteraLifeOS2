-- ============================================================================
-- Montera Life OS — Supabase Schema
-- نظام تشغيل شخصي: مجالات، مشاريع، مهام، اجتماعات، قرارات، بانتظار، ملاحظات
-- شغّل هذا الملف كاملاً مرة واحدة في: Supabase → SQL Editor → New query → Run
-- ============================================================================

-- امتدادات مفيدة
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- دالة تحديث updated_at تلقائياً
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================================
-- 1) AREAS — المجالات (الوحدة المرنة: كل شركة/كلية/قسم/بحث = صف واحد)
-- ============================================================================
create table if not exists public.areas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name_ar     text not null,
  name_en     text,
  kind        text not null default 'custom',   -- university | quality | company | research | personal | custom
  icon        text default '📁',
  color       text default '#4C6EF5',
  sort        int  default 0,
  archived    boolean default false,
  created_at  timestamptz default now()
);

-- ============================================================================
-- 2) PROJECTS — المشاريع
-- ============================================================================
create table if not exists public.projects (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  area_id     uuid references public.areas(id) on delete set null,
  name        text not null,
  description text,
  status      text default 'active',    -- planning | active | on_hold | done
  priority    text default 'medium',    -- low | medium | high | urgent
  progress    int  default 0,           -- 0..100
  start_date  date,
  end_date    date,
  budget      numeric,
  archived    boolean default false,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ============================================================================
-- 3) MEETINGS — الاجتماعات
-- ============================================================================
create table if not exists public.meetings (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  area_id       uuid references public.areas(id) on delete set null,
  title         text not null,
  meeting_date  timestamptz,
  location      text,
  agenda        text,
  minutes       text,
  attendees     text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ============================================================================
-- 4) TASKS — المهام
-- ============================================================================
create table if not exists public.tasks (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  area_id         uuid references public.areas(id) on delete set null,
  project_id      uuid references public.projects(id) on delete set null,
  meeting_id      uuid references public.meetings(id) on delete set null,
  title           text not null,
  notes           text,
  status          text default 'todo',    -- todo | in_progress | blocked | done
  priority        text default 'medium',  -- low | medium | high | urgent
  progress        int  default 0,
  estimated_hours numeric,
  actual_hours    numeric,
  subtasks        jsonb default '[]'::jsonb,
  start_date      date,
  due_date        date,
  reminder_at     timestamptz,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ============================================================================
-- 5) DECISIONS — القرارات (مرتبطة بالاجتماعات)
-- ============================================================================
create table if not exists public.decisions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  meeting_id  uuid references public.meetings(id) on delete set null,
  area_id     uuid references public.areas(id) on delete set null,
  title       text not null,
  responsible text,
  due_date    date,
  status      text default 'open',    -- open | in_progress | done
  priority    text default 'medium',
  notes       text,
  created_at  timestamptz default now()
);

-- ============================================================================
-- 6) WAITING_FOR — بانتظار رد
-- ============================================================================
create table if not exists public.waiting_for (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  area_id       uuid references public.areas(id) on delete set null,
  title         text not null,
  waiting_on    text,                 -- من/جهة الانتظار
  kind          text default 'person',-- person | email | company | university | meeting | deadline
  requested_at  date default current_date,
  due_date      date,
  status        text default 'waiting',-- waiting | received | overdue
  notes         text,
  created_at    timestamptz default now()
);

-- ============================================================================
-- 7) NOTES — ملاحظات وأفكار
-- ============================================================================
create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  area_id     uuid references public.areas(id) on delete set null,
  title       text,
  body        text,
  category    text,
  is_idea     boolean default false,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- مشغّلات updated_at
-- ---------------------------------------------------------------------------
drop trigger if exists trg_projects_updated on public.projects;
create trigger trg_projects_updated before update on public.projects
  for each row execute function public.set_updated_at();

drop trigger if exists trg_meetings_updated on public.meetings;
create trigger trg_meetings_updated before update on public.meetings
  for each row execute function public.set_updated_at();

drop trigger if exists trg_tasks_updated on public.tasks;
create trigger trg_tasks_updated before update on public.tasks
  for each row execute function public.set_updated_at();

drop trigger if exists trg_notes_updated on public.notes;
create trigger trg_notes_updated before update on public.notes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- فهارس للأداء
-- ---------------------------------------------------------------------------
create index if not exists idx_tasks_user      on public.tasks(user_id);
create index if not exists idx_tasks_due        on public.tasks(due_date);
create index if not exists idx_tasks_status     on public.tasks(status);
create index if not exists idx_projects_user    on public.projects(user_id);
create index if not exists idx_meetings_user    on public.meetings(user_id);
create index if not exists idx_meetings_date     on public.meetings(meeting_date);
create index if not exists idx_waiting_user     on public.waiting_for(user_id);
create index if not exists idx_notes_user       on public.notes(user_id);
create index if not exists idx_decisions_user   on public.decisions(user_id);

-- ============================================================================
-- ROW LEVEL SECURITY — كل مستخدم يرى بياناته فقط
-- ============================================================================
alter table public.areas       enable row level security;
alter table public.projects    enable row level security;
alter table public.meetings    enable row level security;
alter table public.tasks       enable row level security;
alter table public.decisions   enable row level security;
alter table public.waiting_for enable row level security;
alter table public.notes       enable row level security;

-- سياسة موحّدة لكل جدول: المالك فقط يقرأ/يكتب/يعدّل/يحذف
do $$
declare t text;
begin
  foreach t in array array['areas','projects','meetings','tasks','decisions','waiting_for','notes']
  loop
    execute format('drop policy if exists "own_select" on public.%I;', t);
    execute format('drop policy if exists "own_insert" on public.%I;', t);
    execute format('drop policy if exists "own_update" on public.%I;', t);
    execute format('drop policy if exists "own_delete" on public.%I;', t);

    execute format('create policy "own_select" on public.%I for select using (auth.uid() = user_id);', t);
    execute format('create policy "own_insert" on public.%I for insert with check (auth.uid() = user_id);', t);
    execute format('create policy "own_update" on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);', t);
    execute format('create policy "own_delete" on public.%I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;

-- ============================================================================
-- تفعيل Realtime (اختياري — لمزامنة لحظية بين الأجهزة)
-- ============================================================================
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;
alter publication supabase_realtime add table public.tasks, public.projects, public.meetings, public.waiting_for, public.notes, public.decisions, public.areas;

-- ============================================================================
-- تم. النظام جاهز. المجالات الافتراضية يتم إنشاؤها تلقائياً من التطبيق عند أول دخول.
-- ============================================================================
