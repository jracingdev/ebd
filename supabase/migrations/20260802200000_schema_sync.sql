-- Schema sync: campos do app local + overrides + turmas custom + engagement mínimo.
-- Aplicar após 20260727000000_init_ebd.sql (Dashboard SQL Editor ou supabase db push).

-- Presença: "Trouxe Bíblia"
alter table public.attendance_people
  add column if not exists trouxe_biblia boolean not null default false;

-- Perfis: overrides granulares (mesmo formato do Hive)
alter table public.profiles
  add column if not exists permission_overrides jsonb;

-- Turmas extras (além das classes padrão do app)
create table if not exists public.custom_groups (
  nome text primary key,
  criado_em timestamptz not null default now()
);

alter table public.custom_groups enable row level security;

drop policy if exists custom_groups_select on public.custom_groups;
create policy custom_groups_select on public.custom_groups
  for select to authenticated using (true);

drop policy if exists custom_groups_write on public.custom_groups;
create policy custom_groups_write on public.custom_groups
  for all using (public.is_staff());

-- Aluno pode atualizar só a própria linha de presença (self check-in)
drop policy if exists attendance_people_self_update on public.attendance_people;
create policy attendance_people_self_update on public.attendance_people
  for update to authenticated
  using (
    public.is_staff()
    or exists (
      select 1 from public.students s
      join public.profiles p on p.id = auth.uid()
      where s.id = coalesce(attendance_people.aluno_id, attendance_people.id)
        and (
          (s.matricula is not null and lower(s.matricula) = lower(p.matricula))
          or s.profile_id = p.id
        )
    )
  )
  with check (
    public.is_staff()
    or exists (
      select 1 from public.students s
      join public.profiles p on p.id = auth.uid()
      where s.id = coalesce(attendance_people.aluno_id, attendance_people.id)
        and (
          (s.matricula is not null and lower(s.matricula) = lower(p.matricula))
          or s.profile_id = p.id
        )
    )
  );

-- Engagement mínimo (pontos / badges) para sync futuro
create table if not exists public.engagement_scores (
  student_id text primary key,
  points int not null default 0,
  badges jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.engagement_scores enable row level security;

drop policy if exists engagement_select on public.engagement_scores;
create policy engagement_select on public.engagement_scores
  for select to authenticated using (true);

drop policy if exists engagement_write on public.engagement_scores;
create policy engagement_write on public.engagement_scores
  for all using (public.is_staff() or public.current_role() = 'admin');

-- updated_at helper em profiles (já existe coluna)
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
