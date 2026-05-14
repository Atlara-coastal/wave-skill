# WAVE — Next.js E-Commerce Skill

A Claude Code skill built from real production experience building [Atlara](https://atlara.store) — a Colombian fashion brand. Every pattern, error, and fix is documented from a live project.

## What's inside

- **Next.js 15+ patterns** — async params, force-dynamic, tsconfig paths
- **PostgreSQL via pg** — connection pool, type gotchas, migration without local DB
- **Vercel Blob** — image upload with drag-drop and URL fallback
- **Wompi payments** — SHA256 integrity, webhook verification (Colombia)
- **GSAP cinematic hero** — SSR-safe dynamic import, ScrollTrigger, cleanup
- **Collections system** — many-to-many schema, slug generation
- **Admin panel** — localStorage auth, CRUD form pattern
- **Mobile navbar** — dynamic background based on route + menu state
- **Error reference** — 16+ real bugs with root causes and exact fixes

---

## Installation

### Option 1 — Claude Code plugin install (recommended)

```bash
claude plugin install https://github.com/AtlaraStore/wave-skill
```

### Option 2 — Manual (Windows PowerShell)

```powershell
.\install.ps1
```

### Option 3 — Manual (Mac/Linux bash)

```bash
chmod +x install.sh && ./install.sh
```

### Option 4 — Copy manually

Copy the `skills/` folder into your Claude Code plugins directory:

- **Windows:** `%USERPROFILE%\.claude\plugins\wave-skill\`
- **Mac/Linux:** `~/.claude/plugins/wave-skill/`

---

## Usage

Once installed, WAVE activates automatically when you work on:
- Any Next.js e-commerce project
- Atlara-style fashion stores
- Projects using Wompi, Vercel Blob, or GSAP with App Router

Claude will reference WAVE patterns and check the error catalog before suggesting fixes.

---

## Updating

When a new error or pattern is found, update the skill:

```bash
# Pull latest
git pull

# Or add a new error manually to:
# skills/wave/references/errors.md
# Following the ERR-XXX format
```

---

## Structure

```
wave-skill/
├── .claude-plugin/
│   └── plugin.json          — plugin metadata
├── skills/
│   └── wave/
│       ├── SKILL.md         — main patterns and architecture guide
│       └── references/
│           └── errors.md    — complete error catalog
├── install.ps1              — Windows installer
├── install.sh               — Mac/Linux installer
└── README.md
```

---

## Built by

[Atlara](https://atlara.store) — info@atlara.store
