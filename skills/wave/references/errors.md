# Error Reference — WAVE Skill

Every bug encountered building Atlara (atlara.store), with root cause and exact fix. Check here first before debugging.

---

## ERR-001 — `params.slug` returns `"[object Promise]"` in production

**Symptom:** Product or collection page shows `[object Promise]` instead of the slug. Works fine in dev, breaks after deploy.

**Root cause:** Next.js 15+ made `params` an async Promise. Accessing it synchronously reads the Promise object, not the value.

**Fix:**
```js
// WRONG
export default async function Page({ params }) {
  const slug = params.slug; // "[object Promise]"
}

// CORRECT
export default async function Page({ params }) {
  const { slug } = await params;
}

// Also in generateMetadata:
export async function generateMetadata({ params }) {
  const { slug } = await params;
}
```

---

## ERR-002 — Pages show empty content after deploy (DB data missing)

**Symptom:** Pages work locally but are blank after deploying to Vercel. The DB has data.

**Root cause:** Next.js pre-renders server components at build time by default. If the DB has no data at build time (Vercel sandbox environment), the page is frozen as empty HTML.

**Fix:** Add `export const dynamic = 'force-dynamic'` at the top of every `page.js` that queries the DB:
```js
export const dynamic = 'force-dynamic';

export default async function Page() {
  const items = await query('SELECT * FROM products');
  // ...
}
```

**Applies to:** Every page that calls `query()` or `queryOne()` — products, collections, shop, admin pages.

---

## ERR-003 — ALL `@/` imports fail after adding any `.tsx` file

**Symptom:** After adding `icon.tsx` (favicon) or any TypeScript file, the entire app breaks with `Cannot find module '@/components/...'` for every single import.

**Root cause:** When a `.tsx` file exists, Turbopack switches to the TypeScript resolver, which requires explicit path mappings in `tsconfig.json`. Without them, `@/` is not recognized.

**Fix:** Add `paths` to `tsconfig.json`:
```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

**Note:** This breaks EVERYTHING simultaneously when triggered. If you see mass import failures after a seemingly unrelated change, this is the cause.

---

## ERR-004 — `COUNT()` and `SUM()` return strings instead of numbers

**Symptom:** Displaying product count shows `"0"` not `0`. Comparisons like `count > 0` fail silently (string vs number).

**Root cause:** PostgreSQL `bigint` (returned by `COUNT`, `SUM`) is mapped by the `pg` driver as a JavaScript string to avoid precision loss.

**Fix:** Always wrap with `Number()`:
```js
const count = Number(row.total_stock); // not row.total_stock directly
const total = Number(row.order_total);
```

**Gotcha:** This only affects `COUNT` and `SUM`. `INTEGER`, `SERIAL`, `BOOLEAN`, and `TIMESTAMPTZ` map correctly.

---

## ERR-005 — Collection image and products not saving (silent failure)

**Symptom:** Admin form appears to save successfully (no error shown), but the collection still has no image and 0 products. Re-editing shows the fields are empty.

**Root cause:** The form state used `snake_case` field names (`hero_image_url`, `product_ids`), but the API route destructured `camelCase` names (`heroImageUrl`, `productIds`). The API received `undefined` for both fields and saved empty values.

**Fix:** Explicitly map field names before sending:
```js
const handleSave = async () => {
  const payload = {
    name: form.name,
    slug: form.slug,
    description: form.description,
    heroImageUrl: form.hero_image_url,   // explicit camelCase mapping
    productIds: form.product_ids,         // explicit camelCase mapping
    active: form.active,
  };
  const res = await fetch(url, { method, body: JSON.stringify(payload) });
};
```

**Rule:** API request/response bodies always use **camelCase**. DB columns use **snake_case**. Map explicitly at the boundary.

---

## ERR-006 — Saving collection wipes the hero image (image disappears)

**Symptom:** Editing a collection that already has an image — clicking Save replaces the image with nothing, even if you didn't change the image field.

**Root cause:** The PATCH endpoint unconditionally included `hero_image_url` in the SQL UPDATE. If the user opened the edit form and the image upload UI showed empty (cleared for a new upload that never happened), `heroImageUrl` was `''` and the existing URL was overwritten with empty string.

**Fix:** Only add `hero_image_url` to the UPDATE if the incoming value is non-empty:
```js
const setClauses = ['name=$1', 'description=$2', 'active=$3', 'updated_at=NOW()'];
const vals = [name, description || '', active ?? true];

if (heroImageUrl) {                             // only update if non-empty
  setClauses.push(`hero_image_url=$${vals.length + 1}`);
  vals.push(heroImageUrl);
}
vals.push(id);
await query(
  `UPDATE collections SET ${setClauses.join(', ')} WHERE id=$${vals.length}`,
  vals
);
```

**Pattern:** Apply to every optional file/URL field in any PATCH endpoint.

---

## ERR-007 — Image upload fails silently (no feedback to user)

**Symptom:** User drags an image onto the upload zone. Nothing happens. No error, no spinner, no URL appears. The form saves with no image.

**Root cause:** Multiple possible causes: file type not in allowed list, Vercel Blob token missing, fetch to `/api/admin/upload` returning non-200 without visible error.

**Fix (layered):**
1. Add a separate `uploadError` state and display it prominently in red.
2. Add `uploadingImg` state and show a spinner/progress indicator.
3. Add a URL text input as a permanent fallback — user can paste any image URL directly.
4. Add `console.log('[debug] uploading', file.name, file.type)` to trace the issue.

```jsx
{uploadError && (
  <p className="text-red-500 text-sm font-semibold mt-2">{uploadError}</p>
)}

{/* Always show URL fallback */}
<input
  type="url"
  placeholder="O pega una URL de imagen..."
  value={form.hero_image_url}
  onChange={e => setForm(f => ({ ...f, hero_image_url: e.target.value }))}
/>
```

**Rule:** Every image upload UI must have a URL text input as fallback.

---

## ERR-008 — `/hero.png` 404 — hero section shows broken image

**Symptom:** HeroSection references `/hero.png` but the browser console shows `GET /hero.png 404`.

**Root cause:** The image file was never placed in `public/`. The `public/` directory is the only folder Next.js serves as static files at the root URL.

**Fix:** Copy the image file to `public/hero.png`. In this project, the correct file was `C:\Users\Alejo\Desktop\ATLARA\modelos\ChatGPT Image 10 may 2026, 23_41_57.png` (black t-shirt with ocean waves on the back).

**Pattern:** Any static asset referenced as `/filename.ext` must physically exist in `public/filename.ext`.

---

## ERR-009 — Footer links cause 404 (`/envios`, `/privacidad`, `/terminos`)

**Symptom:** Clicking footer links shows Next.js 404 page. Console shows no pre-fetch errors but navigation fails.

**Root cause:** `Footer.jsx` had `<Link href="/envios">`, `<Link href="/privacidad">`, `<Link href="/terminos">` pointing to pages that had never been created.

**Fix:** Create the missing page files:
- `src/app/envios/page.js`
- `src/app/privacidad/page.js`
- `src/app/terminos/page.js`

Each needs at minimum a default export returning JSX. For a Colombian e-commerce store, include relevant legal text (Ley 1581 de 2012 for privacy, standard return policy).

---

## ERR-010 — Mobile menu has semi-transparent/blurred background instead of solid black

**Symptom:** Mobile navigation menu opens with a gray/translucent background with a blur effect. The top navbar bar remains a different color from the menu body.

**Root cause:** Menu div had `background: 'rgba(0,0,0,0.75)'` with `backdropFilter: 'blur(12px)'`. The top bar and menu body were styled independently, creating a mismatch.

**Fix:** Use the `mobileOpen` state to control the ENTIRE navbar's background as one unit:
```js
const onHome = pathname === '/';

// Entire nav:
style={{
  ...(mobileOpen
    ? { background: '#000000' }                          // solid black, whole nav
    : onHome
      ? { background: 'transparent', backdropFilter: 'none' }
      : { background: 'rgba(253,247,255,0.92)', backdropFilter: 'blur(12px)', borderBottom: '1px solid rgba(0,0,0,0.06)' }
  )
}}

// Mobile menu div (same color, seamless continuation):
<div style={{ background: '#000000' }}>
```

This makes the navbar and menu look like one solid black panel when open. No blur, no transparency.

---

## ERR-011 — GSAP animations cause SSR errors (module not found / window is not defined)

**Symptom:** Build fails or hydration error with "window is not defined" or GSAP import errors.

**Root cause:** GSAP uses browser APIs (`window`, `document`) that don't exist during server-side rendering.

**Fix:** Always use dynamic import inside `useEffect`:
```js
useEffect(() => {
  const init = async () => {
    const { default: gsap } = await import('gsap');
    const { ScrollTrigger } = await import('gsap/ScrollTrigger');
    gsap.registerPlugin(ScrollTrigger);
    // ... animation code
  };
  init();
}, []);
```

Never `import gsap from 'gsap'` at the top of a file that could be server-rendered.

---

## ERR-012 — GSAP memory leak / animations running after component unmounts

**Symptom:** Console errors about animations targeting removed DOM nodes. Animations from previous page affect new page.

**Root cause:** GSAP contexts and ScrollTriggers are not cleaned up when the React component unmounts.

**Fix:** Use `gsap.context()` and return a cleanup function:
```js
useEffect(() => {
  let ctx;
  const init = async () => {
    const { default: gsap } = await import('gsap');
    ctx = gsap.context(() => {
      // all animations here
    }, sectionRef);
  };
  init();
  return () => ctx?.revert(); // cleanup on unmount
}, []);
```

---

## ERR-013 — `interactive prompts` blocking Vercel deploy

**Symptom:** Running `npx vercel --prod` hangs waiting for input (project name, link existing, etc.).

**Root cause:** First-time deploy prompts for configuration interactively.

**Fix:** Always use `--yes` flag:
```bash
npx vercel --prod --yes
```

---

## ERR-014 — DB migration not running (tables don't exist in production)

**Symptom:** After deploying, API routes return 500 errors with "relation does not exist" because there's no `DATABASE_URL` locally to run migrations.

**Root cause:** `DATABASE_URL` is only in Vercel environment variables, not in `.env.local`. Can't run migration scripts locally.

**Fix:** Create a one-time migration API endpoint, deploy it, then call it via curl:
```js
// src/app/api/admin/migrate/route.js
export async function POST() {
  try {
    await query(`CREATE TABLE IF NOT EXISTS collections (...)`);
    return NextResponse.json({ ok: true });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}
```

After deploy:
```bash
curl -X POST https://yoursite.com/api/admin/migrate
```

Delete or protect the endpoint after running.

---

## ERR-015 — Admin panel accessible without auth (no redirect)

**Symptom:** Navigating directly to `/admin` shows the panel without logging in.

**Root cause:** Auth check in `layout.js` uses `useEffect` which runs client-side, so on first render the panel briefly appears before redirect.

**Fix:** The `useEffect` approach is intentional for a simple localStorage-based auth. It checks on mount:
```js
useEffect(() => {
  const token = localStorage.getItem('admin-token');
  if (!token && pathname !== '/admin/acceso-atlara') {
    router.push('/admin/acceso-atlara');
  } else {
    setAuthenticated(true);
  }
}, [pathname, router]);

// Render nothing until auth check completes:
if (!authenticated) return null;
```

The brief flash before redirect is acceptable for an internal admin panel. For public-facing auth, use Next.js middleware instead.

---

## ERR-016 — Collection products showing wrong count or joining incorrectly

**Symptom:** Collection card shows incorrect product count. Some products appear in wrong collections.

**Root cause:** Query joining `collections` with `collection_products` without proper GROUP BY causes duplicated rows.

**Fix:** Use COUNT with GROUP BY, or use a subquery:
```sql
SELECT c.*,
  COUNT(cp.product_id) AS product_count
FROM collections c
LEFT JOIN collection_products cp ON cp.collection_id = c.id
GROUP BY c.id
ORDER BY c.created_at DESC
```

The `LEFT JOIN` ensures collections with 0 products still appear.

---

## Update Log

| Date | Error | Description |
|------|-------|-------------|
| 2026-05-10 | ERR-001 | params Promise issue in Next.js 15+ |
| 2026-05-10 | ERR-002 | Static rendering wiping DB data |
| 2026-05-10 | ERR-003 | tsconfig paths after tsx file added |
| 2026-05-10 | ERR-004 | COUNT returns string not number |
| 2026-05-10 | ERR-005 | snake_case/camelCase mismatch in API |
| 2026-05-10 | ERR-006 | PATCH wiping hero image |
| 2026-05-10 | ERR-007 | Silent upload failure |
| 2026-05-10 | ERR-008 | /hero.png 404 |
| 2026-05-10 | ERR-009 | Footer links 404 |
| 2026-05-10 | ERR-010 | Mobile menu color mismatch |
| 2026-05-10 | ERR-011 | GSAP SSR errors |
| 2026-05-10 | ERR-012 | GSAP memory leak on unmount |
| 2026-05-10 | ERR-013 | Vercel deploy interactive prompt |
| 2026-05-10 | ERR-014 | DB migration without local DB |
| 2026-05-10 | ERR-015 | Admin auth flash |
| 2026-05-10 | ERR-016 | Collection product count wrong |
