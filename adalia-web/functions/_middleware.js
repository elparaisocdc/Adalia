/**
 * Adalia · Cloudflare Pages middleware
 * Inyecta en el HTML la configuración pública de Supabase y el estado actual del sitio
 * (modo, productos, textos) antes de enviarlo al navegador. Así el visitante ve
 * directamente "Próximamente" o "Mantenimiento" sin parpadeos, y los buscadores
 * leen el contenido actualizado.
 *
 * Variables (wrangler.toml [vars] o Settings > Variables en Cloudflare):
 *   SUPABASE_URL       https://xxxx.supabase.co
 *   SUPABASE_ANON_KEY  clave "anon public" del proyecto (es pública por diseño)
 */
export async function onRequest(context) {
  const response = await context.next();
  const type = response.headers.get('content-type') || '';
  if (!type.includes('text/html') || response.status !== 200) return response;

  const { SUPABASE_URL, SUPABASE_ANON_KEY } = context.env;
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || SUPABASE_URL.includes('TU-PROYECTO')) return response;

  const safe = (obj) => JSON.stringify(obj).replace(/</g, '\\u003c');
  let state = null;
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/site_config?id=eq.1&select=data`, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
      cf: { cacheTtl: 10, cacheEverything: true },
    });
    if (r.ok) {
      const rows = await r.json();
      if (rows && rows[0] && rows[0].data) state = rows[0].data;
    }
  } catch (e) {
    // si Supabase no responde, se sirve el estado por defecto embebido en el HTML
  }

  const origin = new URL(context.request.url).origin;
  let rewriter = new HTMLRewriter()
    .on('script#adalia-config', {
      element(el) {
        el.setInnerContent(`window.ADALIA_CONFIG = ${safe({ supabaseUrl: SUPABASE_URL, supabaseAnonKey: SUPABASE_ANON_KEY })};`, { html: true });
      },
    })
    .on('meta[property="og:image"]', {
      element(el) {
        const c = el.getAttribute('content') || '';
        if (c && !/^https?:/i.test(c)) el.setAttribute('content', `${origin}/${c.replace(/^\//, '')}`);
      },
    });
  if (state) {
    rewriter = rewriter.on('script#adalia-state', {
      element(el) { el.setInnerContent(safe(state), { html: true }); },
    });
  }

  const out = rewriter.transform(response);
  const headers = new Headers(out.headers);
  headers.set('Cache-Control', 'no-cache');
  headers.delete('ETag');
  return new Response(out.body, { status: out.status, statusText: out.statusText, headers });
}
