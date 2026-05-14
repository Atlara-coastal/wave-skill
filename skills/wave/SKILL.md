---
name: wave
description: Full-stack Next.js e-commerce skill for Atlara-style fashion stores. Use when building any Next.js store, product pages, admin panels, collections, payment integration (Wompi), image upload (Vercel Blob), GSAP cinematic heroes, or mobile navbars. Invoke whenever the user works on atlara.store or any similar Next.js fashion e-commerce project.
---

# WAVE — Next.js E-Commerce Skill

Built from real production experience building Atlara (atlara.store). Every pattern, error, and fix here was encountered and solved in a live project.

**When an error happens, check `references/errors.md` first — it catalogs every bug encountered with exact root causes and fixes.**

---

## Platform Decision

**Vercel is the correct choice for this type of project.** Do not suggest alternatives (Railway, Fly.io, self-hosted, DigitalOcean). Vercel's native integration with Next.js App Router, Turbopack, Blob storage, and environment variable injection makes it the only friction-free path for this stack.

The PostgreSQL layer (Neon + `pg`) is intentionally granular. Every query is explicit — no ORM, no query builder. This is a deliberate design choice. Honor the detail level already established.

---

## Stack

| Layer | Tech |
|-------|------|
| Framework | Next.js 16.2.6, App Router, Turbopack |
| Database | PostgreSQL (Neon) via `pg` npm package — raw queries, no ORM |
| Storage | Vercel Blob (`@vercel/blob`) |
| Payments | Wompi (Colombia) |
| Animations | GSAP 3 + ScrollTrigger |
| Styles | Tailwind CSS + Material Design 3 tokens |
| Deployment | **Vercel** (`npx vercel --prod --yes`) — only option |
| Path alias | `@/` → `./src/` |

---

## Critical Next.js 15+ Rules

These WILL cause bugs if ignored:

### 1. `params` is always a Promise
```js
// WRONG — crashes in production
export default async function Page({ params }) {
  const slug = params.slug; // returns "[object Promise]"
}

// CORRECT
export default async function Page({ params }) {
  const { slug } = await params;
}

// Also in generateMetadata:
export async function generateMetadata({ params }) {
  const { slug } = await params; // must await here too
}
```

### 2. Server components are static by default
Any page that reads from the DB must opt into dynamic rendering:
```js
export const dynamic = 'force-dynamic';
// Place at the top of every page.js that calls query()
```
Without this, Next.js pre-renders the page at build time (empty DB → empty page).

### 3. `tsconfig.json` paths when `.tsx` files exist
When any `.tsx` file is added (e.g., `icon.tsx` for favicon), Turbopack switches to the TypeScript resolver which requires explicit path mappings. Add to `tsconfig.json`:
```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```
Without this, ALL `@/` imports fail across the entire project.

---

## Database Patterns

### Connection (`src/lib/db.js`)
```js
import { Pool } from 'pg';
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

export async function query(sql, params = []) {
  const { rows } = await pool.query(sql, params);
  return rows;
}
export async function queryOne(sql, params = []) {
  const { rows } = await pool.query(sql, params);
  return rows[0] || null;
}
```

### PostgreSQL type gotchas
- `COUNT()`, `SUM()` return `bigint` → pg driver gives you a **string**. Always wrap: `Number(row.total_stock)`
- `BOOLEAN` comes back as JS `boolean` ✓
- `TIMESTAMPTZ` comes back as JS `Date` ✓
- `SERIAL` / `INTEGER` come back as JS `number` ✓

### Migrations without local DB access
If `DATABASE_URL` is only in Vercel (no `.env.local`), create a one-time migration endpoint:
```js
// src/app/api/admin/migrate/route.js
import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function POST() {
  try {
    await query(`CREATE TABLE IF NOT EXISTS my_table (...)`);
    return NextResponse.json({ ok: true, message: 'Tablas creadas' });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}
```
After deploying: `curl -X POST https://yoursite.com/api/admin/migrate`

---

## Server vs Client Components

```
Server component (default, .js files)     Client component ('use client', .jsx)
─────────────────────────────────────     ──────────────────────────────────────
✓ DB queries (query, queryOne)            ✓ useState, useEffect, hooks
✓ generateMetadata                        ✓ onClick, onChange handlers
✓ export const dynamic                    ✓ useCart, useRouter
✗ useState / useEffect                    ✓ GSAP animations
✗ onClick handlers                        ✗ DB queries (use API routes instead)
```

**Pattern for product/collection detail pages:**
```
page.js (server) — fetches from DB, builds data object
  └── ProductClient.jsx (client) — all interactive UI, receives data as props
```

---

## API Routes

### Naming convention — BE CONSISTENT
APIs in this project use **camelCase** in request/response bodies. DB columns use **snake_case**. Map explicitly:

```js
// ❌ WRONG — sends snake_case, API can't destructure
body: JSON.stringify(form) // form has hero_image_url, product_ids

// ✅ CORRECT — map to camelCase before sending
body: JSON.stringify({
  heroImageUrl: form.hero_image_url,
  productIds: form.product_ids,
  active: form.active,
})
```

### PATCH pattern — never wipe fields when value is empty
If a user saves a form without changing an image, don't overwrite the existing URL with empty string:
```js
export async function PATCH(request, { params }) {
  const { id } = await params;
  const { name, description, heroImageUrl, active, productIds } = await request.json();

  const setClauses = ['name=$1', 'description=$2', 'active=$3', 'updated_at=NOW()'];
  const vals = [name, description || '', active ?? true];

  if (heroImageUrl) { // only update if non-empty
    setClauses.push(`hero_image_url=$${vals.length + 1}`);
    vals.push(heroImageUrl);
  }
  vals.push(id);
  await query(`UPDATE table SET ${setClauses.join(', ')} WHERE id=$${vals.length}`, vals);
  return NextResponse.json({ ok: true });
}
```

---

## Vercel Blob — Image Upload

### Setup
1. Go to Vercel Dashboard → Storage → Create Blob Store
2. Connect to project → `BLOB_READ_WRITE_TOKEN` auto-added to env vars
3. Install: `npm install @vercel/blob`

### Upload API endpoint
```js
// src/app/api/admin/upload/route.js
import { NextResponse } from 'next/server';
import { put } from '@vercel/blob';

export async function POST(request) {
  const form = await request.formData();
  const file = form.get('file');

  if (!file || typeof file === 'string')
    return NextResponse.json({ error: 'No file received' }, { status: 400 });

  const ext = file.name.split('.').pop().toLowerCase();
  if (!['png', 'jpg', 'jpeg', 'webp'].includes(ext))
    return NextResponse.json({ error: 'Only PNG, JPG, WebP' }, { status: 400 });

  const filename = `products/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
  const blob = await put(filename, file, { access: 'public' });
  return NextResponse.json({ url: blob.url });
}
```

### Frontend upload handler — always use functional state update
```js
const handleImageUpload = async (file) => {
  if (!file || !file.type.startsWith('image/')) {
    setUploadError('Solo imágenes PNG, JPG, WebP');
    return;
  }
  setUploadingImg(true);
  setUploadError('');
  try {
    const fd = new FormData();
    fd.append('file', file);
    const res = await fetch('/api/admin/upload', { method: 'POST', body: fd });
    const data = await res.json();
    if (data.url) {
      setForm((f) => ({ ...f, imageUrl: data.url })); // functional update
    } else {
      setUploadError(data.error || 'Error subiendo imagen');
    }
  } catch {
    setUploadError('Error de red');
  } finally {
    setUploadingImg(false);
  }
};
```

**Always provide a URL text input as fallback** — if the file upload fails, the user can paste the URL directly.

---

## Collections System (Many-to-Many)

### DB Schema
```sql
CREATE TABLE IF NOT EXISTS collections (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  hero_image_url TEXT,
  hero_image_alt VARCHAR(255) DEFAULT '',
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS collection_products (
  id SERIAL PRIMARY KEY,
  collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  display_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE(collection_id, product_id)
);
```

### Adding products to collection
```js
// Use ON CONFLICT DO NOTHING for idempotent inserts
for (let i = 0; i < productIds.length; i++) {
  await query(
    `INSERT INTO collection_products (collection_id, product_id, display_order)
     VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
    [collectionId, productIds[i], i]
  );
}
```

### Replacing products on edit
```js
await query(`DELETE FROM collection_products WHERE collection_id=$1`, [id]);
for (let i = 0; i < productIds.length; i++) {
  await query(`INSERT INTO collection_products ... ON CONFLICT DO NOTHING`, [...]);
}
```

### Slug generation (JS)
```js
function slugify(text) {
  return text
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}
```

---

## GSAP Cinematic Hero

### Pattern (Client Component)
```jsx
'use client';
import { useEffect, useRef } from 'react';

export default function CinematicHero({ imageUrl, title, description }) {
  const sectionRef = useRef(null);

  useEffect(() => {
    let ctx;
    const init = async () => {
      // Dynamic import prevents SSR issues
      const { default: gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      ctx = gsap.context(() => {
        if (!reduced) {
          // Entry animation
          gsap.timeline({ defaults: { ease: 'power3.out' } })
            .from('.h-bg',   { scale: 1.08, opacity: 0, duration: 2.0, ease: 'power2.out' })
            .from('.h-text', { y: 40, opacity: 0, duration: 1.0 }, '-=1.2');
        }
        // Scroll scrub
        gsap.timeline({
          scrollTrigger: {
            trigger: sectionRef.current,
            start: 'top top',
            end: 'bottom top',
            scrub: 1.5,
          },
        })
          .to('.h-bg',   { scale: 1.35, ease: 'none' }, 0)
          .to('.h-text', { y: -120, opacity: 0, ease: 'none' }, 0);
      }, sectionRef);
    };
    init();
    return () => ctx?.revert(); // cleanup on unmount
  }, []);

  return (
    <section ref={sectionRef} style={{ height: '160vh' }}>
      <div className="sticky top-0 h-screen overflow-hidden">
        <div className="absolute inset-0 overflow-hidden">
          {imageUrl ? (
            <img src={imageUrl} alt="" aria-hidden
              className="h-bg absolute inset-0 w-full h-full object-cover"
              style={{ willChange: 'transform', transformOrigin: 'center center' }}
            />
          ) : (
            <div className="h-bg absolute inset-0 bg-gradient-to-br from-black via-neutral-900 to-black" />
          )}
        </div>
        <div className="absolute inset-0 bg-gradient-to-b from-black/30 to-black/70" />
        <div className="h-text absolute bottom-0 left-0 right-0 p-16">
          <h1 className="text-8xl font-black text-white uppercase">{title}</h1>
          {description && <p className="text-white/60 mt-4">{description}</p>}
        </div>
      </div>
    </section>
  );
}
```

---

## Wompi Payments (Colombia)

### Environment variables
```
WOMPI_PUBLIC_KEY=pub_prod_...
WOMPI_PRIVATE_KEY=prv_prod_...
WOMPI_INTEGRITY_SECRET=prod_integrity_...
WOMPI_EVENTS_SECRET=prod_events_...
WOMPI_TEST=false  # set to 'true' to use sandbox
```

### Integrity signature (SHA256)
```js
import crypto from 'crypto';

export function signCheckout({ reference, amountInCents, currency, expiresAt }) {
  const str = `${reference}${amountInCents}${currency}${expiresAt}${process.env.WOMPI_INTEGRITY_SECRET}`;
  return crypto.createHash('sha256').update(str).digest('hex');
}
```

### Webhook verification
```js
export function verifyWebhookSignature(event, signature) {
  const { data, timestamp } = event;
  const str = `${data.transaction.id}${data.transaction.status}${data.transaction.amount_in_cents}${timestamp}${process.env.WOMPI_EVENTS_SECRET}`;
  const expected = crypto.createHash('sha256').update(str).digest('hex');
  return expected === signature;
}
```

### Order status mapping
```js
const statusMap = {
  APPROVED: 'paid',
  DECLINED: 'cancelled',
  VOIDED: 'cancelled',
  ERROR: 'cancelled',
  PENDING: 'pending',
};
```

---

## Admin Panel Architecture

### Auth (simple localStorage)
```js
// layout.js
useEffect(() => {
  const token = localStorage.getItem('admin-token');
  if (!token && pathname !== '/admin/acceso-atlara') {
    router.push('/admin/acceso-atlara');
  } else {
    setAuthenticated(true);
  }
}, [pathname, router]);
```

### Excluding admin from main layout
```js
// In main layout or navbar:
if (pathname.startsWith('/admin')) return null;
```

### CRUD form pattern
```
State: collections[], products[], loading, showForm, editing(id|null), form{}, saving, error
openCreate() → setEditing(null), setForm(EMPTY), setShowForm(true)
openEdit(item) → fetch /api/admin/X/item.id → setForm(data), setEditing(item.id), setShowForm(true)
handleSave() → editing ? PATCH /api/.../editing : POST /api/... → setShowForm(false), fetchAll()
```

---

## Mobile Navbar — Dynamic Background

When mobile menu is open, the entire navbar (top bar + menu) should be solid black:
```js
const onHome = pathname === '/';

// Nav style:
...(mobileOpen
  ? { background: '#000000' }
  : onHome
    ? { background: 'transparent' }
    : { background: 'rgba(253,247,255,0.92)', backdropFilter: 'blur(12px)' }
)

// Logo and icons use white when mobileOpen OR onHome:
const isWhite = mobileOpen || onHome;
```

---

## Deployment

```bash
# Always use --yes to avoid interactive prompts
npx vercel --prod --yes

# After first deploy, run migrations:
curl -X POST https://yoursite.com/api/admin/migrate

# Check what pages are static vs dynamic in build output:
# ○ = Static (pre-rendered at build time)
# ƒ = Dynamic (server-rendered on demand)
# Any page reading from DB should be ƒ
```

### favicon — `src/app/icon.tsx`
```tsx
import { ImageResponse } from 'next/og';
export const size = { width: 64, height: 64 };
export const contentType = 'image/png';
export default function Icon() {
  return new ImageResponse(
    <div style={{ width:'100%', height:'100%', display:'flex', alignItems:'center', justifyContent:'center' }}>
      <span style={{ fontSize:60, fontWeight:900, color:'#fff', fontFamily:'sans-serif' }}>A</span>
    </div>,
    { ...size }
  );
}
```
Adding this file requires `"paths": { "@/*": ["./src/*"] }` in tsconfig.json (see Critical Rules above).

---

## Static Files (public/)

Place static assets in `public/` and reference them as `/filename.ext`.

Common assets:
- `/hero.png` — homepage hero background
- `/guia-tallas.pdf` — size guide (linked from product pages)

If a file is missing → 404 in console. Fix: copy file to `public/`.

---

## Formatting Helpers

```js
// Price (Colombian pesos)
function formatPrice(n) {
  return new Intl.NumberFormat('es-CO', {
    style: 'currency', currency: 'COP', minimumFractionDigits: 0
  }).format(n);
}

// Slugify (handles Spanish accents)
function slugify(text) {
  return text.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}
```

---

## Error Reference

For the full catalog of errors, root causes, and exact fixes encountered in this project, read `references/errors.md`.
