-- SUPRADS PORTAL · configuración inicial
-- Pegar completo en Supabase → SQL Editor → New query → Run

-- 1) Tabla de perfiles de clientes (1 fila por usuario)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  company text,
  message text default 'Acá vas a encontrar los materiales de tu cuenta.',
  photo_path text,          -- ruta dentro del bucket, ej: <id-del-usuario>/foto.jpg
  photo_title text,
  photo_date date default current_date,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
grant select on public.profiles to authenticated;

-- cada cliente puede leer SOLO su propio perfil
drop policy if exists "cliente lee su perfil" on public.profiles;
create policy "cliente lee su perfil" on public.profiles
  for select to authenticated
  using (auth.uid() = id);

-- 2) Al crear un usuario en Authentication, se crea su perfil automáticamente
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, split_part(new.email, '@', 1))
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3) Bucket PRIVADO para las fotos
insert into storage.buckets (id, name, public)
values ('client-photos', 'client-photos', false)
on conflict (id) do nothing;

-- cada cliente puede ver SOLO los archivos de su carpeta (carpeta = su id)
drop policy if exists "cliente lee su carpeta" on storage.objects;
create policy "cliente lee su carpeta" on storage.objects
  for select to authenticated
  using (bucket_id = 'client-photos' and (storage.foldername(name))[1] = auth.uid()::text);
