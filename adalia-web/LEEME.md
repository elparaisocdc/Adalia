# Adalia: sitio web listo para Cloudflare Pages + Supabase

## Qué hay en esta carpeta

| Carpeta / archivo | Para qué sirve |
|---|---|
| `public/` | El sitio (lo que se publica). `index.html` tiene toda la página, el catálogo y el panel. |
| `public/assets/` | Recortes de la marca en WebP. |
| `public/js/supabase.js` | Librería oficial supabase-js 2.45.4 (licencia MIT), incluida para no depender de otro servidor. |
| `public/_headers` | Encabezados de seguridad y caché para Cloudflare. |
| `functions/_middleware.js` | Inyecta la configuración y el contenido actual de Supabase en cada visita (sin parpadeos al estar en "Próximamente" o "Mantenimiento"). |
| `supabase/schema.sql` | Tablas, permisos, almacenamiento de fotos y contenido inicial. |
| `wrangler.toml` | Configuración de Cloudflare Pages: acá van tu URL y tu clave pública de Supabase. |

---

## Paso 1 · Supabase (10 minutos)

1. Entrá a https://supabase.com y creá un proyecto nuevo (región: São Paulo es la más cercana).
2. Andá a **SQL Editor → New query**, pegá todo `supabase/schema.sql` y tocá **Run**.
3. Andá a **Authentication → Users → Add user → Create new user**. Poné tu email y una contraseña y marcá **Auto Confirm User**.
4. Volvé a **SQL Editor**, pegá esto (con tu email) y tocá **Run**:
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'tu-email@ejemplo.com'
   on conflict do nothing;
   ```
5. Andá a **Authentication → URL Configuration** y en **Site URL** poné la dirección final de tu sitio (por ejemplo `https://adalia.pages.dev` o tu dominio). Se usa para el enlace de "Olvidé mi contraseña".
6. Andá a **Project Settings → API** y copiá:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **anon public key**

## Paso 2 · Conectar las claves

Abrí `wrangler.toml` con el Bloc de notas y reemplazá:

```toml
SUPABASE_URL = "https://TU-PROYECTO.supabase.co"
SUPABASE_ANON_KEY = "PEGA-ACA-TU-ANON-KEY"
```

La clave **anon** es pública por diseño: lo que protege los datos son las reglas del `schema.sql`. **Nunca** pegues la clave `service_role`.

## Paso 3 · Cloudflare Pages

> Importante: la subida "arrastrar y soltar" del panel de Cloudflare **no** ejecuta la carpeta `functions/`. Usá una de estas dos opciones.

**Opción A: con GitHub (recomendada, sin consola)**
1. Creá un repositorio en GitHub y subí esta carpeta completa (con GitHub Desktop es arrastrar y "Commit + Push").
2. En Cloudflare: **Workers & Pages → Create → Pages → Connect to Git**, elegí el repositorio.
3. Build command: *(vacío)* · Build output directory: `public`. Tocá **Save and Deploy**.
4. Cada vez que subas un cambio a GitHub, Cloudflare publica solo.

**Opción B: desde la computadora (requiere Node.js)**
```bash
npx wrangler login
npx wrangler pages deploy
```
(ejecutado dentro de esta carpeta).

**Dominio propio:** en el proyecto de Pages → **Custom domains → Set up a domain**.

---

## Cómo se administra

- Entrá al sitio y tocá la **llave** (arriba a la derecha) o **Acceso del equipo** (pie de página).
- Ingresá con el email y la contraseña del Paso 1.3.
- Pestañas del panel:
  - **Estado del sitio:** Disponible / Próximamente / Mantenimiento, con vista previa. El cambio llega al instante a quien tenga la página abierta.
  - **Productos:** nombre, precio, textos, visibilidad, orden y **fotos** (subís desde la computadora; se achican solas a 1600 px en WebP).
  - **Catálogo:** título, año, texto del índice y frase de cierre. Las páginas se arman solas a partir de los productos visibles.
  - **Contacto** y **Aviso** superior.
- Si alguien inicia sesión con una cuenta que no está en `admins`, el panel no se abre y Supabase rechaza cualquier cambio.

## Sin Supabase configurado

Si `wrangler.toml` conserva los valores de ejemplo, el sitio funciona igual pero el panel pasa a **modo local**: PIN `adalia2026` y cambios guardados solo en ese navegador. Sirve para probar, no para producción.

## Pendiente de reemplazar

- WhatsApp (`5493510000000`), email (`contacto@tu-dominio.com`) e Instagram (`@adalia.regalos`, tomado de un mockup; confirmá si es `adalia.desing`).
- Fotos de producto: se cargan desde el panel. Mientras tanto se ven ilustraciones provisorias marcadas como "Foto pendiente".
- Precios: tomados del catálogo; verificá qué precio corresponde a cada variante (A5, A4 y planner).
- Tipografía manuscrita: Great Vibes como sustituto de "Amoresa Aged".
