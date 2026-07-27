-- EBD schema: profiles, roles, catalog, lessons, FCM tokens
-- Apply via: supabase db push / SQL editor

create extension if not exists "pgcrypto";

create type public.user_role as enum (
  'aluno',
  'professor',
  'superintendente',
  'pastor',
  'admin'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  matricula text not null unique,
  nome text not null,
  role public.user_role not null default 'aluno',
  grupo text,
  telefone text,
  email text,
  aniversario date,
  foto_url text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_matricula_idx on public.profiles (matricula);
create index profiles_role_idx on public.profiles (role);
create index profiles_aniversario_idx on public.profiles (aniversario);

create table public.students (
  id text primary key,
  nome text not null,
  grupo text not null,
  matricula text unique,
  telefone text,
  aniversario date,
  foto_url text,
  profile_id uuid references public.profiles (id) on delete set null,
  criado_em timestamptz not null default now()
);

create table public.editions (
  id text primary key,
  grupo text not null,
  trimestre text not null,
  capa text,
  tema text,
  sku text,
  serie text,
  criado_em timestamptz not null default now()
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  edition_id text not null references public.editions (id) on delete cascade,
  numero int not null check (numero between 1 and 13),
  titulo text not null,
  data_domingo date not null,
  unique (edition_id, numero)
);

create table public.betel_catalog (
  id uuid primary key default gen_random_uuid(),
  grupo text not null,
  trimestre text not null,
  serie text not null,
  tema text,
  sku text,
  capa_url text,
  produto_url text,
  preco numeric,
  synced_at timestamptz not null default now(),
  unique (grupo, trimestre)
);

create table public.delivery_records (
  id text primary key,
  nome text not null,
  grupo text not null,
  edicao_id text not null references public.editions (id) on delete cascade,
  valor numeric not null,
  status text not null check (status in ('pago', 'pendente')),
  data timestamptz not null default now()
);

create table public.finances (
  id text primary key,
  grupo text not null,
  data date not null,
  tipo text not null check (tipo in ('oferta', 'doacao')),
  valor numeric not null,
  descricao text default '',
  criado_em timestamptz not null default now()
);

create table public.attendance_sessions (
  id text primary key,
  grupo text not null,
  data date not null,
  criado_em timestamptz not null default now(),
  unique (grupo, data)
);

create table public.attendance_people (
  id text primary key,
  session_id text not null references public.attendance_sessions (id) on delete cascade,
  aluno_id text,
  nome text not null,
  presente boolean not null default false
);

create table public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  unique (profile_id, token)
);

-- Helper: current user's role
create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('professor', 'superintendente', 'pastor', 'admin')
  );
$$;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.editions enable row level security;
alter table public.lessons enable row level security;
alter table public.betel_catalog enable row level security;
alter table public.delivery_records enable row level security;
alter table public.finances enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_people enable row level security;
alter table public.fcm_tokens enable row level security;

-- Profiles: self read; staff read all; admin write
create policy profiles_select_self on public.profiles
  for select using (id = auth.uid() or public.is_staff());

create policy profiles_update_self on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin');

create policy profiles_insert_admin on public.profiles
  for insert with check (public.current_role() in ('admin', 'pastor', 'superintendente'));

-- Authenticated read for catalog/lessons/editions
create policy betel_select on public.betel_catalog for select to authenticated using (true);
create policy lessons_select on public.lessons for select to authenticated using (true);
create policy editions_select on public.editions for select to authenticated using (true);

create policy betel_write_admin on public.betel_catalog
  for all using (public.current_role() in ('admin', 'superintendente'));
create policy lessons_write_admin on public.lessons
  for all using (public.current_role() in ('admin', 'superintendente', 'pastor'));
create policy editions_write_staff on public.editions
  for all using (public.is_staff());

create policy students_select on public.students for select to authenticated using (true);
create policy students_write on public.students
  for all using (public.is_staff());

create policy finances_select on public.finances for select to authenticated using (true);
create policy finances_write on public.finances for all using (public.is_staff());

create policy delivery_select on public.delivery_records for select to authenticated using (true);
create policy delivery_write on public.delivery_records for all using (public.is_staff());

create policy attendance_sessions_select on public.attendance_sessions for select to authenticated using (true);
create policy attendance_sessions_write on public.attendance_sessions for all using (public.is_staff());
create policy attendance_people_select on public.attendance_people for select to authenticated using (true);
create policy attendance_people_write on public.attendance_people for all using (public.is_staff());

create policy fcm_own on public.fcm_tokens
  for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Storage bucket for photos (run in dashboard or via API)
-- insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, matricula, nome, role, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'matricula', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'nome', 'Usuário'),
    coalesce((new.raw_user_meta_data->>'role')::public.user_role, 'aluno'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
