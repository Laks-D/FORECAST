-- Immediate-write Supabase schema for the Flutter app.
--
-- The app uses Firebase Auth for identity, so client-side Supabase requests
-- are made with the anonymous key. These tables are intentionally writable
-- from the client so the existing Flutter service can persist data right away.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id text primary key,
  email text,
  display_name text,
  photo_url text,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

alter table public.profiles disable row level security;

grant select, insert, update, delete on public.profiles to anon, authenticated;

create table if not exists public.organizations (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  owner_id text not null,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

drop trigger if exists organizations_set_updated_at on public.organizations;
create trigger organizations_set_updated_at
before update on public.organizations
for each row
execute function public.set_updated_at();

create index if not exists organizations_owner_id_idx on public.organizations(owner_id);

grant select, insert, update, delete on public.organizations to anon, authenticated;

create table if not exists public.students (
  id text primary key default gen_random_uuid()::text,
  org_id text not null references public.organizations(id) on delete cascade,
  full_name text not null,
  phone text,
  profession text,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

drop trigger if exists students_set_updated_at on public.students;
create trigger students_set_updated_at
before update on public.students
for each row
execute function public.set_updated_at();

create index if not exists students_org_id_idx on public.students(org_id);

grant select, insert, update, delete on public.students to anon, authenticated;

create table if not exists public.activities (
  id text primary key default gen_random_uuid()::text,
  org_id text not null references public.organizations(id) on delete cascade,
  student_id text not null references public.students(id) on delete cascade,
  activity_type text not null,
  amount_due numeric,
  event_date timestamptz,
  status text,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

drop trigger if exists activities_set_updated_at on public.activities;
create trigger activities_set_updated_at
before update on public.activities
for each row
execute function public.set_updated_at();

create index if not exists activities_org_id_idx on public.activities(org_id);
create index if not exists activities_student_id_idx on public.activities(student_id);
create index if not exists activities_event_date_idx on public.activities(event_date desc);

grant select, insert, update, delete on public.activities to anon, authenticated;