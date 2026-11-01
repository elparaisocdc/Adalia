-- ============================================================
--  ADALIA · Esquema de Supabase
--  Pegá TODO este archivo en Supabase > SQL Editor > New query y tocá "Run".
--  Se puede ejecutar más de una vez sin romper nada.
-- ============================================================

-- 1) Configuración del sitio (una sola fila con todo el contenido editable)
create table if not exists public.site_config (
  id          int primary key default 1 check (id = 1),
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users(id) on delete set null
);

-- 2) Lista de administradores
create table if not exists public.admins (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);

alter table public.site_config enable row level security;
alter table public.admins      enable row level security;

-- 3) ¿El usuario actual es administrador?
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- 4) Permisos y reglas de acceso (RLS)
grant select on public.site_config to anon, authenticated;
grant update on public.site_config to authenticated;
grant select on public.admins to authenticated;

drop policy if exists "config: lectura publica" on public.site_config;
create policy "config: lectura publica" on public.site_config
  for select to anon, authenticated using (true);

drop policy if exists "config: solo admins editan" on public.site_config;
create policy "config: solo admins editan" on public.site_config
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins: ver el propio registro" on public.admins;
create policy "admins: ver el propio registro" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- 5) Fecha y autor de cada cambio
create or replace function public.touch_site_config()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;
drop trigger if exists site_config_touch on public.site_config;
create trigger site_config_touch before update on public.site_config
  for each row execute function public.touch_site_config();

-- 6) Tiempo real: los visitantes ven el cambio de modo al instante
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'site_config'
  ) then
    alter publication supabase_realtime add table public.site_config;
  end if;
end $$;

-- 7) Almacenamiento de fotos (bucket público "adalia", máx. 5 MB por archivo)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('adalia', 'adalia', true, 5242880, array['image/webp','image/jpeg','image/png'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/webp','image/jpeg','image/png'];

drop policy if exists "adalia: admins suben fotos" on storage.objects;
create policy "adalia: admins suben fotos" on storage.objects
  for insert to authenticated with check (bucket_id = 'adalia' and public.is_admin());

drop policy if exists "adalia: admins editan fotos" on storage.objects;
create policy "adalia: admins editan fotos" on storage.objects
  for update to authenticated using (bucket_id = 'adalia' and public.is_admin());

drop policy if exists "adalia: admins borran fotos" on storage.objects;
create policy "adalia: admins borran fotos" on storage.objects
  for delete to authenticated using (bucket_id = 'adalia' and public.is_admin());

-- 8) Contenido inicial (solo se inserta si la tabla está vacía)
insert into public.site_config (id, data) values (1, $adalia${"v":2,"mode":"live","soon":{"title":"Algo está germinando","text":"Estamos preparando un jardín nuevo de agendas, cuadernos y regalos de papel. Muy pronto vas a poder recorrerlo.","launch":"2026-12-01T10:00","countdown":true},"maint":{"title":"Estamos regando el jardín","text":"Hacemos unos ajustes para que todo florezca mejor. Volvé en un ratito: lo vas a encontrar más lindo.","back":"Volvemos en unas horas"},"announce":{"on":true,"text":"Agendas 2027 ya disponibles · Consultas y pedidos por WhatsApp"},"contact":{"whatsapp":"5493510000000","instagram":"adalia.regalos","email":"contacto@tu-dominio.com","location":"Córdoba, Argentina","pending":["whatsapp","instagram","email"]},"catalog":{"title":"Catálogo","year":"2027","intro":"Cada pieza de este catálogo nació pensando en alguien: en sus mañanas, en sus metas y en las cosas lindas que quiere recordar. Elegí tranquila, pasá las hojas y escribinos cuando algo te guiñe el ojo.","thanks":"Gracias por ser parte de este sueño"},"products":[{"id":"agenda-2027","name":"Agenda 2027","col":"agendas","price":"$25.000","desc":"14 meses de organización con vistas mensuales y semanales, habit tracker, mood tracker, journaling y control de gastos.","long":"Esta agenda incluye 14 meses de organización, comenzando desde noviembre y diciembre del año anterior, con vistas semanales y mensuales detalladas. Para potenciar tu crecimiento personal, cuenta con un espacio para revisar tus logros previos, definir tus objetivos anuales, hacer seguimiento de hábitos (habit tracker) y registrar tus emociones (mood tracker). Además, cada mes te regala microdosis de inspiración: lecturas, preguntas de autoconocimiento, ejercicios de journaling, frases motivadoras semanales y herramientas de organización financiera. Se completa con hojas de notas punteadas, un espacio de gratitud y listas de prioridades.","badge":"Nuevo","photos":[],"mock":"agenda","tint":"rosa","visible":true},{"id":"organizador-diario","name":"Organizador diario","col":"organizadores","price":"$16.600","desc":"Para ordenar el día sin perder la calma: prioridades, pendientes y un lugar para lo que te hizo bien.","long":"","badge":"","photos":[],"mock":"agenda","tint":"salvia","visible":true},{"id":"cuaderno-a5-dura","name":"Cuaderno A5 tapa dura","col":"cuadernos","price":"$10.750","desc":"Formato A5 de tapa dura, firme para escribir donde sea y lindo para dejar a la vista.","long":"","badge":"","photos":[],"mock":"cuaderno","tint":"beige","visible":true},{"id":"cuaderno-a5-blanda","name":"Cuaderno A5 tapa blanda","col":"cuadernos","price":"$6.000","desc":"Liviano y flexible, para la cartera, la mochila o la mesa de luz.","long":"","badge":"","photos":[],"mock":"cuaderno","tint":"rosa","visible":true},{"id":"cuaderno-a4-dura","name":"Cuaderno universitario A4 tapa dura","col":"cuadernos","price":"$16.000","desc":"Tamaño A4 para estudiar, planificar proyectos y tomar apuntes con espacio de sobra.","long":"","badge":"","photos":[],"mock":"cuaderno","tint":"salvia","visible":true},{"id":"cuaderno-a4-blanda","name":"Cuaderno universitario A4 tapa blanda","col":"cuadernos","price":"$10.750","desc":"La versión liviana del A4, ideal para la cursada de todos los días.","long":"","badge":"","photos":[],"mock":"cuaderno","tint":"beige","visible":false},{"id":"planner","name":"Planner semanal y diario","col":"organizadores","price":"desde $2.800","desc":"Hojas para planificar la semana o el día y pegar en la heladera, el escritorio o tu agenda.","long":"","badge":"","photos":[],"mock":"taco","tint":"beige","visible":true},{"id":"taco-notas","name":"Taco de notas","col":"notas","price":"$5.380","desc":"Para las listas, los recordatorios y las ideas que aparecen de golpe.","long":"","badge":"","photos":[],"mock":"taco","tint":"rosa","visible":true},{"id":"marcadores","name":"Marcadores de página","col":"notas","price":"$1.500","desc":"Para no perder la página donde quedó la mejor frase.","long":"","badge":"","photos":[],"mock":"marcadores","tint":"beige","visible":true},{"id":"kit-cajas","name":"Kit cajas","col":"kits","price":"$19.500","desc":"Cajas listas para regalar, con etiqueta y sticker de la casa.","long":"","badge":"Para regalar","photos":[],"mock":"caja","tint":"rosa","visible":true}]}$adalia$::jsonb)
on conflict (id) do nothing;

-- ============================================================
--  9) DAR PERMISO DE ADMINISTRACIÓN
--  Primero creá el usuario en Supabase > Authentication > Users > Add user
--  (email + contraseña, marcá "Auto Confirm User"). Después ejecutá esta línea
--  cambiando el email:
--
--  insert into public.admins (user_id)
--  select id from auth.users where email = 'tu-email@ejemplo.com'
--  on conflict do nothing;
-- ============================================================
