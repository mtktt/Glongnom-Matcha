# Glongnom POS — Session Update Log
**Session Date:** 2026-05-28 / 2026-05-29
**Phase Completed:** Phase 1A — Core POS Loop + Post-launch Improvements

---

## Phase 1A Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Project folder structure | `js/`, `css/`, `admin/`, `kitchen/`, `supabase/migrations/`, `netlify/functions/` |
| 2 | Database schema + RLS + Realtime | `supabase/migrations/001_initial_schema.sql` |
| 3 | Database reset script | `supabase/migrations/000_reset.sql` |
| 4 | Menu seed data (22 items, 6 option groups) | `supabase/migrations/002_seed_menu.sql` |
| 5 | Supabase client config | `js/config.js` |
| 6 | Auth system — login, session, role guard | `login.html`, `js/auth.js` |
| 7 | Password set/reset page | `reset-password.html` |
| 8 | Admin panel — menu CRUD, shop toggle, close message | `admin/index.html` |
| 9 | Order queue — live Supabase Realtime | `admin/orders.html` |
| 10 | Customer ordering app — ported GAS → Supabase | `index.html` |
| 11 | PromptPay QR (built, disabled by flag) | `js/promptpay.js` |
| 12 | LINE notification — Netlify Function + Supabase Webhook | `netlify/functions/line-notify.js` |
| 13 | Netlify deployment config | `netlify.toml` |
| 14 | Roadmap updated — tech stack, Phase 1A/1B split | `roadmap.md` |

**Live URL:** https://glongnom-pos.netlify.app

---

## Post-launch Features Added (Same Session)

| # | Feature | Files Changed |
|---|---|---|
| 15 | Drag & drop menu sorting (global sort_order) | `admin/index.html` |
| 16 | Permanent delete with confirmation modal | `admin/index.html` |
| 17 | Disable/Enable button color (yellow/green) | `admin/index.html` |
| 18 | Edit close message when closing shop | `admin/index.html`, SQL alter shops |
| 19 | Self-service Forgot Password on login page | `login.html` |
| 20 | User Management page — invite, change role, deactivate | `admin/users.html` |
| 21 | Netlify Function — invite staff via Supabase Admin API | `netlify/functions/invite-user.js` |
| 22 | Option Template System — reusable global option groups | `supabase/migrations/003_option_templates.sql` |
| 23 | Option Groups admin page — CRUD templates + choices | `admin/options.html` |
| 24 | Assign Options modal per menu item | `admin/index.html` |
| 25 | Customer ordering app updated to use template query | `index.html` |

---

## Tech Stack (Locked)

| Layer | Tool |
|---|---|
| Database + Auth + Realtime | Supabase (PostgreSQL) |
| Frontend | Vanilla JS |
| Hosting | Netlify |
| Serverless Functions | Netlify Functions (Node 18) |
| Notifications | LINE Messaging API via Netlify Function |

---

## Bugs & Fixes

| # | Bug | Cause | Solution |
|---|---|---|---|
| 1 | `relation "shops" already exists` | Schema run twice — first run failed mid-way, left partial tables | Created `000_reset.sql` to drop all tables cleanly before re-running schema |
| 2 | `relation "drink" does not exist` | Unicode `×` chars in SQL comments confused Supabase's RLS advisor — clicking "Enable RLS" tried to run `ALTER TABLE drink` | Removed all `×` chars from SQL comments, always click "Run anyway" on RLS warning |
| 3 | `Identifier 'supabase' has already been declared` | Supabase CDN sets `window.supabase` as namespace; `config.js` tried to re-declare `const supabase` in same global scope | Changed `const supabase =` → `window.supabase =` in `config.js` |
| 4 | `new row violates row-level security policy for table "orders"` | INSERT + `.select()` chained requires both INSERT and SELECT policy — anon had no SELECT policy | Added SELECT policies for orders, order_items, order_item_options with `using (true)` |
| 5 | Invite email link pointed to `localhost` | Supabase Site URL not configured — defaults to localhost | Set Site URL to Netlify URL, created `reset-password.html`, re-sent invite |
| 6 | `Database error saving new user` on invite | `handle_new_user` trigger couldn't find `user_profiles` without explicit search_path | Added `set search_path = public` to trigger function |
| 7 | Menu not loading on Netlify | Netlify Functions defaulted to Node 16 — no built-in `fetch` | Added `NODE_VERSION = "18"` to `netlify.toml` |
| 8 | Drag & drop sort not persisting on ordering page | sort_order saved per-category causing global overlaps (Matcha 1-13, Drinks 1-7) | Fixed `onDrop` to always reassign sort_order across ALL items globally |
| 9 | SUPABASE_URL secret env var broke redeploy | Netlify "secret" vars behave differently during build phase | Changed to plain env var — only `LINE_CHANNEL_TOKEN` and `WEBHOOK_SECRET` need to be secret |
| 10 | `invite-user.js` deploy error — could not resolve `@supabase/supabase-js` | No `package.json` in project — esbuild can't bundle npm package | Rewrote function using native `fetch` only, no npm dependencies |

---

## Feature Requests & Implementation

| # | Request | Solution |
|---|---|---|
| 1 | Drag & drop menu sorting | HTML5 drag events → save global sort_order to Supabase on drop |
| 2 | Permanent delete with confirmation | Delete button → confirm modal with item name → `supabase.delete()` with FK error handled |
| 3 | Disable/Enable button color differentiation | Disable = yellow, Enable = green, Delete = red |
| 4 | Edit close message when closing shop | `close_message` column on shops + Close Shop modal with editable textarea |
| 5 | LINE message format match original GAS | Rewrote `line-notify.js` to match `code_new.gs` format exactly |
| 6 | Self-service forgot password for staff | `supabase.auth.resetPasswordForEmail()` with `redirectTo: reset-password.html` |
| 7 | Add new users without Supabase dashboard | `admin/users.html` + `invite-user.js` Netlify Function using Supabase Admin API |
| 8 | Option group management (Lineman/Wongnai style) | New Option Template System: global reusable groups + assign to menus |

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `000_reset.sql` | Drop all tables (use when re-running schema) |
| `001_initial_schema.sql` | All core tables, RLS, Realtime, seed shop + categories |
| `002_seed_menu.sql` | 22 menu items + 6 option groups seeded |
| `003_option_templates.sql` | Option Template System tables + migrate old data |

---

## Manual SQL Applied (Not in Migration Files)

```sql
-- Fix handle_new_user trigger
create or replace function handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.user_profiles (id, name) values (new.id, new.email);
  return new;
end; $$;

-- RLS fix for guest order submission
create policy "orders_insert"             on orders             for insert with check (true);
create policy "orders_read_own"           on orders             for select using (true);
create policy "order_items_insert"        on order_items        for insert with check (true);
create policy "order_items_read"          on order_items        for select using (true);
create policy "order_item_options_insert" on order_item_options for insert with check (true);
create policy "order_item_options_read"   on order_item_options for select using (true);
create policy "customers_insert"          on customers          for insert with check (true);

-- Close message column
alter table shops add column if not exists close_message text
  default 'ขณะนี้ร้านปิดรับออร์เดอร์ค่ะ ^^';
```

---

## Supabase Configuration (Reference)

| Setting | Value |
|---|---|
| Project URL | `https://ykxzmakquyjpsgdaalba.supabase.co` |
| Site URL | `https://glongnom-pos.netlify.app` |
| Redirect URLs | `https://glongnom-pos.netlify.app/reset-password.html` |
| Database Webhook | INSERT on `orders` → `/.netlify/functions/line-notify` with `x-webhook-secret` header |

---

## Netlify Environment Variables

| Variable | Type | Purpose |
|---|---|---|
| `LINE_CHANNEL_TOKEN` | Secret | LINE Messaging API push |
| `WEBHOOK_SECRET` | Secret | Verify Supabase webhook requests |
| `SUPABASE_URL` | Plain | Supabase project URL |
| `SUPABASE_ANON_KEY` | Plain | Supabase anon key |
| `SUPABASE_SERVICE_KEY` | Secret | Admin API for user invitations |
| `LINE_USER_ID` | Plain | Owner's LINE user ID |
| `SITE_URL` | Plain | `https://glongnom-pos.netlify.app` |

---

## Admin Panel Pages

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort | admin, manager |
| `/admin/orders.html` | Live order queue | admin, manager, cashier |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/login.html` | Staff login + forgot password | — |
| `/reset-password.html` | Set/reset password from email link | — |

---

## Next Phase

**Phase 1B — Kitchen & Hardware Layer**
- Kitchen Display System (KDS) using Supabase Realtime → `kitchen/index.html`
- Browser PDF receipt for customer and kitchen
- ESC/POS thermal printer (stretch goal)

**Phase 2 — Inventory & Costing**
- BOM/recipe engine (auto-deduct ingredients per order)
- Supplier + purchase order management
- Low-stock alerts

---

---

# Design System Alignment & UI/UX Overhaul
**Session Date:** 2026-05-29
**Scope:** All 6 admin/auth pages + global design system infrastructure

---

## Task 1 — Design System Alignment

Applied the design system established in `index.html` to all 6 previously unstyled files.

| Task | Files Affected |
|---|---|
| Created CSS variable `:root` block | All 6 files |
| Added Sarabun (Google Fonts) | All 6 files |
| Replaced green scheme (`#4a7c59`) with brown/pink brand palette | `login.html`, `reset-password.html`, all 4 admin pages |
| Fixed button styles — pill radius, `var(--brown-dark)`/`var(--brown-mid)` | All 6 files |
| Fixed input focus styles — `var(--pink-deep)` + pink glow | All 6 files |
| Fixed card/surface styles — `var(--surface-warm)`, brown shadows, `var(--radius-lg)` | All 6 files |

---

## Task 2 — Login & Reset Password

| # | Improvement | Files |
|---|---|---|
| 1 | Pink brand divider added below `<h1>` | `login.html`, `reset-password.html` |
| 2 | Body repositioned to golden-third vertical placement (`clamp(64px, 12vh, 140px)` top padding) | `login.html`, `reset-password.html` |
| 3 | Animated Login ↔ Forgot Password panel switch — opacity + translateY fade, removed `display:none` jump | `login.html` |
| 4 | Password show/hide toggle (`👁`) added to all password fields | `login.html`, `reset-password.html` |
| 5 | "← Back to login" link added | `reset-password.html` |
| 6 | Disappearing placeholder replaced with persistent "Minimum 6 characters" hint text | `reset-password.html` |

---

## Task 3 — Admin Menu Management

| # | Improvement | Files |
|---|---|---|
| 1 | Shop Open/Close toggle separated from Sign Out with visual border; `●`/`○` prefix + tooltip | `admin/index.html` |
| 2 | Mobile hamburger nav — collapses to `☰` below 640px (later superseded by sidebar in Phase 7) | `admin/index.html` |
| 3 | 4-button action column replaced with Edit + `•••` overflow dropdown (Options / Disable / Delete) | `admin/index.html` |
| 4 | Active / Inactive / Total count summary bar above table, live-updating | `admin/index.html` |
| 5 | Live image URL preview (64×64px) in Add/Edit modal — auto-hides on broken URL | `admin/index.html` |
| 6 | Drag handle upgraded from Braille `⠿` to 6-dot grip SVG + first-use dismissable banner | `admin/index.html` |

---

## Task 4 — Orders Page

| # | Improvement | Files |
|---|---|---|
| 1 | Color-coded column headers — amber left border (New), pink (Preparing), green (Ready) | `admin/orders.html` |
| 2 | "New" badge turns amber/urgent when count > 0 | `admin/orders.html` |
| 3 | Age badges on New orders: green <5 min, amber 5–10 min, red >10 min; auto-refreshes every 60 s | `admin/orders.html` |
| 4 | Order item rows split into bold name + muted options on separate lines with left border grouping | `admin/orders.html` |
| 5 | "Mark Paid" demoted to ghost-style button | `admin/orders.html` |
| 6 | Empty "New" column shows "✓ All quiet / No new orders" placeholder | `admin/orders.html` |
| 7 | Past order search bar — queries by order number or customer name, shows styled result cards | `admin/orders.html` |

---

## Task 5 — Options Page

| # | Improvement | Files |
|---|---|---|
| 1 | Add-choice row inputs have persistent `NAME EN`, `NAME TH`, `PRICE +฿` labels | `admin/options.html` |
| 2 | Choice rows are drag-to-reorder with 6-dot grip SVG; updates `sort_order` in Supabase on drop | `admin/options.html` |
| 3 | Template card headers have `tabindex="0"`, `role="button"`, keyboard support (Enter/Space), `aria-expanded` | `admin/options.html` |
| 4 | Delete confirmation modal shows which menus will be unassigned | `admin/options.html` |
| 5 | "Assigned to menus" section moved from bottom to top of choices panel | `admin/options.html` |

---

## Task 6 — Users Page

| # | Improvement | Files |
|---|---|---|
| 1 | Deactivate/Activate buttons use `.btn-deactivate`/`.btn-activate` CSS classes — removed inline styles | `admin/users.html` |
| 2 | Email column added to the users table | `admin/users.html` |
| 3 | Confirmation dialog before deactivating a user ("They will lose access immediately.") | `admin/users.html` |
| 4 | Admin badge changed to solid dark purple (`#7c3aed`, white text) to signal higher privilege | `admin/users.html` |
| 5 | Current user's row highlighted in `var(--pink-soft)`; inline "(You)" marker in pink; tooltip on disabled button | `admin/users.html` |

---

## Task 7 — Left Sidebar Navigation

Replaced the top `<nav>` bar on all 4 admin pages with a left slide-over sidebar pattern.

| Element | Detail |
|---|---|
| Trigger bar | Fixed 52px bar — hamburger + brand name + current page label + shop toggle (menu page only) |
| Sidebar drawer | 260px, slides in from left with backdrop overlay |
| Nav links | 4 links with emoji prefixes: 📋 Menu, 🧾 Orders, ⚙️ Options, 👥 Users |
| Active state | Pink left border + soft pink background, detected via `window.location.pathname` |
| Footer | User info + Sign Out button |
| Body offset | `padding-top: 52px` applied to all 4 pages to clear fixed topbar |

Files affected: `admin/index.html`, `admin/orders.html`, `admin/options.html`, `admin/users.html`

---

## Task 8 — Global Cross-Cutting

| # | Improvement | Files |
|---|---|---|
| 1 | **Shared CSS file** — `/css/design-system.css` created; `:root` block defined once; all 7 files link to it | `/css/design-system.css`, all 7 HTML files |
| 2 | **Typography tokens** — `--text-xs` through `--text-3xl` added to design system; applied across all `<style>` blocks | `/css/design-system.css` |
| 3 | **Shimmer skeleton loading** — `@keyframes shimmer` + `.skeleton-*` classes added globally; all 4 admin pages show animated placeholders instead of "Loading…" text | `/css/design-system.css`, all 4 admin pages |
| 4 | **iOS safe area fix** — all 7 files updated with `viewport-fit=cover`; toast `bottom` uses `calc(Xpx + env(safe-area-inset-bottom, 0px))` | All 7 HTML files |
| 5 | **Error banners** — dismissable red error banner with Retry button on all 4 admin pages, wired to Supabase error catch blocks | All 4 admin pages |
| 6 | **Animated modals** — `opacity + visibility + pointer-events` pattern replaces `display:none/flex`; modal box gets scale + translateY animation | `admin/index.html`, `admin/options.html`, `admin/users.html` |
| 7 | **Spacing tokens** — `--space-1` through `--space-10` added to design system, applied to layout-level containers | `/css/design-system.css` |
| 8 | **Dynamic order queue tab title** — browser tab shows `(3) Order Queue` when new orders are pending | `admin/orders.html` |

---

## Task 9 — Bug Fixes

| # | Bug | Cause | Fix |
|---|---|---|---|
| 1 | Action dropdown clipping (`admin/index.html`) | `.action-dropdown` used `position: absolute`, clipped by parent overflow contexts | Changed to `position: fixed`; `toggleActionMenu()` now uses `getBoundingClientRect()` for viewport-relative positioning; opens upward when near bottom of page; scroll/resize listeners close any open dropdown |
| 2 | Users page load error (`admin/users.html`) | `email` column included in Supabase `.select()` string, but `user_profiles` has no email column — auth emails live in Supabase's internal `auth.users` | Removed `email` from `.select()`; email cell correctly shows `—` as fallback |

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `login.html` | Brand alignment, animated panel switch, show/hide toggle, divider, layout |
| `reset-password.html` | Brand alignment, hint text, back link, show/hide toggle, divider, layout |
| `admin/index.html` | Full UI overhaul — action dropdown, summary bar, image preview, drag handle, sidebar, bug fix |
| `admin/orders.html` | Full UI overhaul — color headers, age badges, item row split, search bar, sidebar, tab title |
| `admin/options.html` | Full UI overhaul — input labels, drag reorder, keyboard accessibility, delete modal, sidebar |
| `admin/users.html` | Full UI overhaul — CSS classes, email column, confirmation dialog, badge, current user row, sidebar, bug fix |
| `css/design-system.css` | New file — shared `:root` variables, typography tokens, spacing tokens, shimmer skeleton |

---

---

# Phase 1B — KDS Integration, Bug Fixes & Printer Foundation
**Session Date:** 2026-05-30
**Scope:** Order queue KDS merge, Realtime race condition fix, FK constraint fix, receipt engine, printer management page

---

## Phase 1B Deliverables (Completed)

| # | Deliverable | Files |
|---|---|---|
| 1 | KDS merged into Order Queue — 3-section card, all roles, live timer, audio ping | `admin/orders.html` |
| 2 | Realtime race condition fix — debounced reload + `order_item_options` subscription | `admin/orders.html` |
| 3 | FK constraint fixed — `choice_id` now references `option_template_choices` | Supabase SQL (manual) |
| 4 | Receipt engine — 58mm thermal format, shared across all pages | `js/receipt.js` |
| 5 | Printer management page — add/edit/delete/status/test print | `admin/printer.html` |
| 6 | Printer nav link added to all admin sidebars | All 4 admin pages |

---

## Task 1 — KDS + Order Queue Merge (`admin/orders.html`)

Integrated KDS functionality directly into the existing order queue page instead of creating a separate `kitchen/index.html`. All roles (`admin`, `manager`, `cashier`, `kitchen`, `staff`) are now authorized.

### Card Redesign — 3 Sections

| Section | Content |
|---|---|
| **TOP** | Order #, order type badge (with table no), age badge (green/amber/red), customer name + phone, delivery address |
| **MIDDLE** | Pink-soft background. Items with qty + name + options (colored left border per column status). Per-item notes italic. Order-level note in amber block. |
| **BOTTOM** | Surface-warm background. Total price, payment toggle (Unpaid → Paid), kitchen status button (▶ Prepare / ✓ Ready / Served), cancel ✕, live ⏱ timer |

### KDS Features Added

| Feature | Implementation |
|---|---|
| Live timer | `data-timer-start` on each card span; `setInterval` every 1s updates text only — no DOM rebuild |
| Timer colors | Green < 5 min, amber 5–10 min, red > 10 min |
| Audio ping | Web Audio API two-note tone on `orders` INSERT Realtime event; AudioContext primed on first user click |
| Column item borders | CSS `[data-status]` attribute — amber (New), pink (Preparing), green (Ready) |
| All roles authorized | `Auth.require(['admin','manager','cashier','kitchen','staff'])` |

---

## Task 2 — Realtime Race Condition Fix (`admin/orders.html`)

### Problem
When a customer submitted an order, the order card appeared with no items or options. Refresh fixed it.

### Root Cause
`index.html` inserts in 3 sequential steps: `orders` → `order_items` → `order_item_options`. The Realtime INSERT on `orders` triggered `loadOrders()` immediately — before `order_items` and `order_item_options` existed in the database.

### Fix

```js
// Debounced reload — fires once after all inserts settle
let reloadTimer = null;
function scheduleReload(ms = 0) {
  clearTimeout(reloadTimer);
  reloadTimer = setTimeout(loadOrders, ms);
}
```

| Event | Behaviour |
|---|---|
| `orders` INSERT | Play ping + schedule reload in **3000ms** (fallback) |
| `order_item_options` INSERT | Reset timer to **500ms** — fires after last option lands |
| `orders` UPDATE | Reload **immediately** |

**SQL required (Supabase SQL Editor):**
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE order_item_options;
```

---

## Task 3 — FK Constraint Fix (Supabase SQL)

### Problem
Submitting an order threw: `insert or update on table "order_item_options" violates foreign key constraint "order_item_options_choice_id_fkey"`

### Root Cause
Migration 003 moved option choices from `option_choices` to `option_template_choices`. The FK constraint on `order_item_options.choice_id` still pointed to the old `option_choices` table.

### Fix (run in Supabase SQL Editor)

```sql
-- Drop FK (regardless of current state)
ALTER TABLE order_item_options
  DROP CONSTRAINT IF EXISTS order_item_options_choice_id_fkey;

-- Nullify stale choice_ids from old test orders
UPDATE order_item_options
SET choice_id = NULL
WHERE choice_id IS NOT NULL
  AND choice_id NOT IN (SELECT id FROM option_template_choices);

-- Add correct FK
ALTER TABLE order_item_options
  ADD CONSTRAINT order_item_options_choice_id_fkey
  FOREIGN KEY (choice_id)
  REFERENCES option_template_choices(id)
  ON DELETE SET NULL;
```

`ON DELETE SET NULL` preserves order history when a template choice is later deleted — `choice_name` and `additional_price` snapshots keep display data intact.

---

## Task 4 — Receipt Engine (`js/receipt.js`)

Shared receipt builder for 58mm thermal paper (XPrinter XP-58IIL and compatible).

### Functions

| Function | Description |
|---|---|
| `buildReceiptHTML(order, shopConfig)` | Returns full receipt HTML string — 58mm `@page`, Courier New, monospace table layout |
| `printOrderReceipt(order, shopConfig)` | Opens popup window and triggers `window.print()` |
| `testPrintReceipt(shopConfig)` | Prints a pre-built dummy order for format testing |
| `RECEIPT_TEST_ORDER` | Exported test data constant |

### Receipt Format (58mm)

```
🍵 GLONGNOM MATCHA 🍵
มัทฉะคราฟท์สดใหม่
Tel: 0XX-XXX-XXXX
════════════════════════
30/05/2569  14:30
Order #G-0042 | Delivery
────────────────────────
ชื่อ: Somchai Rakdee
โทร: 089-123-4567
ส่งที่: U Baan อาคาร A
📝 หมายเหตุออเดอร์
────────────────────────
2x Matcha Latte   150.00
  • น้ำตาลน้อย, ไม่มีน้ำแข็ง
1x Green Tea       60.00
  • น้ำตาลปกติ
  📝 Extra hot please
────────────────────────
════════════════════════
รวมทั้งหมด        210.00 ฿
════════════════════════
ขอบคุณที่อุดหนุนนะคะ ♡
กลับมาอีกนะคะ 🌿
@glongnom_matcha
```

---

## Task 5 — Printer Management Page (`admin/printer.html`)

| Feature | Detail |
|---|---|
| **Add printer** | Name, model, connection type (Browser / Network), IP, port, notes, set as default |
| **Edit printer** | Pre-filled modal |
| **Delete printer** | Confirmation modal |
| **Status check** | `fetch(http://ip/, {mode:'no-cors'})` with 3s timeout — detects online/offline without agent |
| **Receipt preview** | In-page preview panel showing sample receipt in Courier New |
| **Test print** | Calls `testPrintReceipt()` from `receipt.js` — opens 58mm popup |
| **Set default** | Marks one printer as default, clears others |
| **Auth** | admin + manager only |

### Supabase Table Required

```sql
CREATE TABLE IF NOT EXISTS public.printers (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name            text NOT NULL,
  model           text DEFAULT 'XPrinter XP-58IIL',
  connection_type text DEFAULT 'browser' CHECK (connection_type IN ('browser','network')),
  ip_address      text,
  port            integer DEFAULT 9100,
  is_default      boolean DEFAULT false,
  notes           text,
  last_status     text DEFAULT 'unknown',
  last_checked_at timestamptz,
  created_at      timestamptz DEFAULT now()
);
ALTER TABLE public.printers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "printers_read"  ON public.printers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "printers_write" ON public.printers FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
);
```

---

## Remaining Printer Tasks (Future)

- Add **Print Receipt** button to each order card in `admin/orders.html`
- Connect shop config (name, phone) live from Supabase `shops` table into receipt
- **ESC/POS local print agent** — Node.js bridge from browser → TCP 9100 → printer (when needed)
- Multi-station routing — kitchen slip vs cashier receipt

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `admin/orders.html` | Full KDS integration — 3-section card, timer, audio ping, debounced Realtime, all roles |
| `admin/printer.html` | New file — printer management page |
| `js/receipt.js` | New file — shared 58mm receipt engine |
| `admin/index.html` | Sidebar: added Printers link |
| `admin/options.html` | Sidebar: added Printers link |
| `admin/users.html` | Sidebar: added Printers link |

---

## Admin Panel Pages (Updated)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort | admin, manager |
| `/admin/orders.html` | Live order queue + KDS | all roles |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/admin/printer.html` | Printer config + test print | admin, manager |
| `/login.html` | Staff login + forgot password | — |
| `/reset-password.html` | Set/reset password from email link | — |

---

---

# Phase 2 — Inventory & Costing System
**Session Date:** 2026-05-30
**Scope:** Full Phase 2 build — BOM engine, inventory management, cost tracking, supplier + PO management, auto-print receipt, bug fixes

---

## Phase 2 Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Database schema — 7 new tables, indexes, RLS, stored functions | `supabase/migrations/004_phase2_inventory.sql` |
| 2 | Migration amendments — `partial` status + `receive_po_items` function | `supabase/migrations/005_phase2_amendments.sql` |
| 3 | Inventory management page — ingredients CRUD, stock adjust, wastage log | `admin/inventory.html` |
| 4 | BOM builder — assign ingredients + quantities per menu item | `admin/inventory.html` (Tab 2) |
| 5 | BOM deduction engine — auto-deduct stock on order `served` | `admin/orders.html`, Supabase RPC `deduct_bom_for_order` |
| 6 | Food cost columns on menu page — Cost ฿ + FC% with color coding | `admin/index.html` |
| 7 | Supplier management page — CRUD, active/inactive | `admin/suppliers.html` |
| 8 | Purchase order management page — create, submit, receive, cancel | `admin/purchase-orders.html` |
| 9 | Auto-print receipt on new order — OFF by default, toggle in topbar | `admin/orders.html`, `js/receipt.js` |
| 10 | Sidebar nav updated across all admin pages — Inventory, Suppliers, Purchases links | All 8 admin pages |

---

## Schema Design (Holmes Review — 2026-05-30)

### New Tables

| Table | Purpose |
|---|---|
| `ingredients` | Ingredient catalog with stock, reorder level, cost per unit |
| `recipe_bom` | Bill of Materials — ingredient quantities per menu item |
| `inventory_adjustments` | Audit log for all manual stock changes and wastage |
| `inventory_deductions` | Idempotency log for BOM deduction engine |
| `suppliers` | Supplier profiles |
| `purchase_orders` | PO headers (draft → submitted → partial → received → cancelled) |
| `purchase_order_items` | PO line items with quantity ordered/received and unit cost |

### Stored Functions

| Function | Purpose |
|---|---|
| `deduct_bom_for_order(order_id)` | Atomic BOM deduction on order served — single transaction, idempotent |
| `adjust_ingredient_stock(id, delta)` | Safe stock adjustment (floors at 0) |
| `receive_po_items(po_id, receipts)` | Atomic goods receipt — updates stock, weighted average cost, audit log, PO status |

### Key Design Decisions

| Decision | Choice |
|---|---|
| Unit handling | Single canonical unit per ingredient — CHECK constraint enforced |
| Deduction trigger | `status = 'served'` |
| Soft delete | `is_active = false` on ingredients — no hard deletes |
| Atomicity | Postgres stored functions via `supabase.rpc()` |
| Cost update on receipt | Weighted average cost |
| PO partial deliveries | PO stays open, receives in batches, auto-transitions to `partial` / `received` |

---

## Food Cost Formulas (Finn Validation — 2026-05-30)

| Formula | Definition |
|---|---|
| Recipe Cost | Σ (quantity_used × cost_per_unit) across all BOM entries |
| Food Cost % | Recipe Cost / base_price × 100 |
| Gross Margin % | (base_price − Recipe Cost) / base_price × 100 |
| Suggested Price | ROUND_UP_TO_5(Recipe Cost / 0.30) |

- **Target food cost %: 30%** (Thai beverage cafe benchmark)
- FC% color coding: green ≤ 30%, amber 31–35%, red > 35%
- Tooltip: "Ingredient cost only. Does not include labor or overhead."

---

## Auto-Print Receipt

- Triggers automatically on Supabase Realtime `orders` INSERT event
- Calls `printOrderReceipt(order, shopConfig)` from `js/receipt.js`
- Only fires for new orders (INSERT), not status updates
- **Default: OFF** — toggle in topbar: `🖨 Auto-print: OFF/ON`
- State persisted in `localStorage` key `glongnom_autoprint`
- Shop config loaded once on init from `shops` table

---

## Bugs Fixed This Session

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | Add ingredient shows success but never appears in table | Two `async function saveIngredient` in same script — second override caused infinite self-recursion; Supabase insert never ran | Renamed internal writer to `_writeIngredient(data)` |
| 2 | Purchase orders page shows "Failed to load" on every open | `submitted_at` column doesn't exist in `purchase_orders` table — all SELECT/INSERT/UPDATE referencing it caused Supabase to error | Removed all 4 `submitted_at` references from the page |

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `000_reset.sql` | Drop all tables |
| `001_initial_schema.sql` | Core tables, RLS, Realtime |
| `002_seed_menu.sql` | 22 menu items + option groups |
| `003_option_templates.sql` | Option Template System |
| `004_phase2_inventory.sql` | Phase 2 — all 7 inventory tables + functions |
| `005_phase2_amendments.sql` | Add `partial` status + `receive_po_items` function |

---

## Admin Panel Pages (Updated)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort + FC% columns | admin, manager |
| `/admin/orders.html` | Live order queue + KDS + auto-print toggle | all roles |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/admin/printer.html` | Printer config + test print | admin, manager |
| `/admin/inventory.html` | Ingredient CRUD + BOM builder | admin, manager |
| `/admin/suppliers.html` | Supplier management | admin, manager |
| `/admin/purchase-orders.html` | Purchase order lifecycle | admin, manager |

---

## Local Development

Run locally with no Netlify deploy needed:

```bash
npx serve .
# Opens at http://localhost:3000
# Clean URLs — use /admin/inventory not /admin/inventory.html
```

Netlify Functions (LINE notify, invite-user) require `netlify dev` instead.

---

## Next Phase

**Phase 3 — Operations & Business Intelligence** ✅ Complete (see below)

---

---

# Phase 3 — Operations & Business Intelligence
**Session Date:** 2026-05-31
**Scope:** Dashboard migration (Google Sheets → Supabase), CRM + Loyalty System, Interactive Reports page, Bug fixes

---

## Phase 3 Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Dashboard migrated — Google Apps Script removed, all data from Supabase | `admin/dashboard.html` |
| 2 | CRM schema — loyalty_points, tier, birthday on customers + loyalty_ledger table | `supabase/migrations/006_phase3_crm.sql` |
| 3 | CRM page — customer list, order history, loyalty points, tier progression | `admin/customers.html` |
| 4 | Loyalty accrual hook — auto-accrues points on order served | `admin/orders.html` |
| 5 | Reports page — 3-tab interactive tables (Sales, Menu & Options, Inventory) | `admin/reports.html` |
| 6 | RLS fix — customers table SELECT policy for authenticated users | `supabase/migrations/007_rls_fixes.sql` |
| 7 | Sidebar nav updated across all admin pages — Dashboard, Reports, Customers links | All admin pages |

---

## Task 1 — Dashboard (`admin/dashboard.html`)

Migrated from Google Apps Script to Supabase. React UI kept intact — only the data layer replaced.

| Card | Supabase Source |
|---|---|
| Revenue / Orders / Avg Basket / Customers KPIs | `orders` table, aggregated in JS |
| Revenue chart (hourly/daily) | `orders` grouped by hour or date |
| Top sellers | `order_items` JOIN `menus` JOIN `categories` |
| Options analysis | `order_item_options` via `order_items` for current period orders |
| Heatmap (day × hour) | `orders` grouped by DOW × hour |
| Top customers | `customer_name` from orders (direct column, works for all historical data) |
| Live feed | Latest 10 `orders` with Realtime subscription |
| Today hourly | `orders` for today, bucketed into 13 hourly slots (08:00–20:00) |

**Auth guard added:** admin + manager only. Sidebar added matching all other admin pages.

---

## Task 2 — CRM System (`admin/customers.html`)

### New Schema (migration `006_phase3_crm.sql`)

| Table / Column | Purpose |
|---|---|
| `customers.loyalty_points` | Running point total (integer, default 0) |
| `customers.tier` | bronze / silver / gold (auto-updated by RPC) |
| `customers.birthday` | date (optional) |
| `customers.notes` | freetext notes |
| `loyalty_ledger` | Full transaction history — delta, reason, order_id, created_at |

### Stored Functions

| Function | Purpose |
|---|---|
| `accrue_loyalty_for_order(p_order_id)` | Idempotent — floor(total/10) pts earned, updates tier |
| `adjust_loyalty_points(p_customer_id, p_delta, p_reason, p_note)` | Manual adjustment, floors at 0, updates tier |

### Tier Thresholds (Finn-validated)

| Tier | Points | Visits to reach (฿100 avg, 2×/week) |
|---|---|---|
| Bronze | 0 – 299 pts | Immediate |
| Silver | 300 – 999 pts | ~30 visits / 3.5 months |
| Gold | 1,000+ pts | ~100 visits / 12 months |

### Page Features
- Left panel: customer list sorted by points (desc), real-time name/phone search
- Right panel: editable profile, 4-stat bar, tier + progress bar, manual point adjustment (admin/manager only), order history timeline, loyalty ledger table
- Deep-link: `/admin/customers.html?id=UUID` auto-opens customer detail
- Orders page: "View →" link on each order card routes to customer detail

---

## Task 3 — Reports Page (`admin/reports.html`)

Three fully interactive tabs — all data from Supabase.

### Tab 1 — Sales
- Filters: period, order type, payment status, order # search
- 10-column sortable table with paginated results (50 rows/page)
- Summary: total orders + total revenue (incl. delivery) + cancelled count
- CSV export fetches all matching rows (not just current page), UTF-8 BOM for Excel

### Tab 2 — Menu & Options
- Filters: period, category dropdown, menu name search
- Columns: Rank, Menu, Category, Qty Sold, Revenue, Avg Price, Recipe Cost, FC%, Top Choice
- FC% color: green ≤30%, amber 31–35%, red >35%, dash if no BOM
- BOM cost + top option fetched in parallel via `Promise.all()`

### Tab 3 — Inventory
- Filters: period (affects deducted/restocked/wastage totals), status filter (All/Low/Critical), name search
- Columns: Ingredient, Unit, Current Stock, Reorder Level, Status, Deducted, Restocked, Wastage, Cost/Unit, Stock Value
- Summary: total stock value + deducted + wastage + alert counts

**Default period:** Week (changed from Today — avoids empty table on first load)

---

## Bugs Fixed This Session

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | `customer_id: null` on every order | `index.html` hardcoded `customer_id: null` — upserted customer but never retrieved the UUID | Chained `.select('id').single()` on upsert; passes `customerId` to order insert |
| 2 | Top customers empty on dashboard | All orders had `customer_id = null` (Bug 1) | Dashboard now reads `customer_name` directly from orders — works for all historical data |
| 3 | Customers page shows 0 orders | `orders()` nested select had no FK hint — Supabase couldn't traverse reverse relation | Changed to `orders!customer_id(...)` |
| 4 | Inventory tab error loading | `inventory_deductions` uses `deducted_at` not `created_at`; `inventory_adjustments` type column is `adjustment_type` not `reason` | Corrected both column names in query and reduce logic |
| 5 | Menu tab revenue mismatch vs Sales | `orders!order_id` (LEFT JOIN) meant cancelled-order filter applied only to embedded object, leaking cancelled items into Menu revenue | Restored `orders!inner` — inner join correctly filters outer rows |
| 6 | Search by order # broken | `.or()` with `customers.name.ilike` on foreign table not supported by Supabase PostgREST | Replaced with direct `.ilike('order_no', ...)` on main table |
| 7 | Options analysis empty on dashboard | `order_item_options` has no `created_at` column — date filter errored silently | Rewired to filter via `currOrderIds → order_items → order_item_options` |
| 8 | Category mix all same color on dashboard | `CAT_COLORS` mapped hardcoded English keys; real DB category names don't match | Replaced with `CAT_PALETTE` — 8-color array assigned by sorted index |
| 9 | Today's orders not showing | Menu tab `orders!order_id` (LEFT JOIN) not enforcing status filter on outer rows | Restored `orders!inner`; revenue now matches between tabs |

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `006_phase3_crm.sql` | CRM tables — loyalty_points, tier, birthday, loyalty_ledger + 2 stored functions |
| `007_rls_fixes.sql` | customers table SELECT policy for authenticated users |

---

## Admin Panel Pages (Updated)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/dashboard.html` | Live sales dashboard — KPIs, charts, heatmap, top sellers | admin, manager |
| `/admin/customers.html` | CRM — customer list, order history, loyalty points, tier | admin, manager, cashier |
| `/admin/reports.html` | Interactive reports — Sales, Menu & Options, Inventory tabs | admin, manager |

---

---

# Phase 4 — Accounting & Finance
**Session Date:** 2026-05-31
**Scope:** Accounting journal page, Finance P&L page (contribution format), auto-recording hooks, fixed costs management

---

## Phase 4 Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Database schema — accounting_entries, fixed_costs tables + 2 stored functions | `supabase/migrations/008_phase4_accounting.sql` |
| 2 | Accounting page — journal entries, auto + manual, balance summary | `admin/accounting.html` |
| 3 | Finance page — P&L contribution format + fixed costs manager | `admin/finance.html` |
| 4 | Auto-record income hook — fires on order marked Paid | `admin/orders.html` |
| 5 | Auto-record expense hook — fires on PO received | `admin/purchase-orders.html` |
| 6 | Sidebar nav updated — Accounting + Finance links | All 11 admin pages |

---

## Schema Design (migration `008_phase4_accounting.sql`)

### New Tables

| Table | Purpose |
|---|---|
| `accounting_entries` | Journal entry log — income and expense records with auto/manual flag |
| `fixed_costs` | Fixed cost definitions — rent, salary, utilities, etc. with period type and effective dates |

### `accounting_entries` Key Columns

| Column | Notes |
|---|---|
| `entry_type` | `income` or `expense` |
| `category` | `sales`, `purchase`, `labor`, `rent`, `utilities`, `other` |
| `reference_type` | `order`, `purchase_order`, `manual` |
| `is_auto` | `true` = system-generated, cannot be deleted by user |

### `fixed_costs` Key Columns

| Column | Notes |
|---|---|
| `period_type` | `monthly`, `weekly`, `yearly` — used for P&L proration |
| `effective_from` / `effective_to` | Date range when cost is active; `effective_to = NULL` means ongoing |

### Stored Functions

| Function | Purpose |
|---|---|
| `record_order_income(p_order_id)` | Idempotent — records income entry when order is paid |
| `record_purchase_expense(p_po_id)` | Idempotent — sums `quantity_ordered × unit_cost` from PO items, records expense |

---

## Task 1 — Accounting Page (`admin/accounting.html`)

- Period picker (default: Month)
- **Summary bar:** Total Income (green) | Total Expense (red) | Net Balance (green if +, red if −)
- Transaction table: Date, Description (🔒 if auto), Type badge, Category badge, +/− Amount, Actions
- Auto-generated entries (orders paid, POs received) are read-only — delete blocked with toast
- Add/Edit modal for manual entries: date, description, type, category, amount
- Client-side filters: type dropdown, category dropdown, text search
- CSV export respects current filters and sort

---

## Task 2 — Finance Page (`admin/finance.html`)

- Period picker (default: Month; minimum 7 days enforced)
- Two-panel layout: P&L Statement (left, 60%) | Fixed Costs Manager (right, 40%)

### P&L Statement — Contribution Format

```
REVENUE
  Sales Revenue              ฿ X,XXX.XX    (accounting_entries income/sales in period)

VARIABLE COSTS (COGS)
  Cost of Goods Sold         ฿ X,XXX.XX    (inventory_deductions × ingredients.cost_per_unit)

CONTRIBUTION MARGIN          ฿ X,XXX.XX    (Revenue − COGS)
  Contribution Margin %      XX.X%

FIXED COSTS
  [each fixed cost name]     ฿ X,XXX.XX    (prorated for selected period)
  Total Fixed Costs          ฿ X,XXX.XX

NET INCOME                   ฿ X,XXX.XX    (green = profit, red = loss)
  Net Margin %               XX.X%
```

**COGS calculation:**
1. Fetch served orders in period
2. Fetch `inventory_deductions` for those orders joined with `ingredients(cost_per_unit)`
3. COGS = Σ (quantity_deducted × cost_per_unit)

**Fixed cost proration:**
- Monthly cost prorated as: `amount × (period_days / 30)`
- Weekly: `amount × (period_days / 7)`
- Yearly: `amount × (period_days / 365)`

### Fixed Costs Manager (right panel)

- List all active fixed costs with Edit/Delete buttons
- Add Fixed Cost modal: name, amount, period type, effective from/to, active toggle
- Any change auto-refreshes the P&L statement

---

## Auto-Recording Hooks

| Trigger | Function Called | Location |
|---|---|---|
| Order marked **Paid** | `record_order_income(orderId)` | `admin/orders.html` → `markPaid()` |
| PO marked **Received** | `record_purchase_expense(poId)` | `admin/purchase-orders.html` → `confirmReceive()` |

Both hooks are fire-and-forget (`.catch(console.warn)`) — a recording failure never blocks the main operation.

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `008_phase4_accounting.sql` | accounting_entries + fixed_costs tables + 2 stored functions |

---

## Admin Panel Pages (Final State)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort + FC% columns | admin, manager |
| `/admin/orders.html` | Live order queue + KDS + auto-print + shop toggle | all roles |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/admin/printer.html` | Printer config + test print | admin, manager |
| `/admin/inventory.html` | Ingredient CRUD + BOM builder + compound ingredients | admin, manager |
| `/admin/suppliers.html` | Supplier management | admin, manager |
| `/admin/purchase-orders.html` | Purchase order lifecycle + big-unit input | admin, manager |
| `/admin/dashboard.html` | Live sales dashboard | admin, manager |
| `/admin/customers.html` | CRM — loyalty, order history | admin, manager, cashier |
| `/admin/reports.html` | Interactive reports — 3 tabs | admin, manager |
| `/admin/accounting.html` | Journal entries + PO# search | admin, manager |
| `/admin/finance.html` | P&L statement (white) + fixed costs | admin, manager |

---

---

# Bug Fixes & Feature Improvements — Session 5
**Session Date:** 2026-06-01
**Scope:** Bug fixes across all admin pages, inventory big-unit system, compound ingredients, purchase order unit alignment, accounting grants & backfill, period picker standardisation, sidebar navigation restructure

---

## Task 1 — Dashboard Improvements (`admin/dashboard.html`)

| # | Change | Detail |
|---|---|---|
| 1 | Removed Options Analysis card | Decluttered dashboard — moved to Reports page |
| 2 | Top Customers — added Total Spent column | Sorted by total spending (more meaningful than order count) |
| 3 | Layout re-balanced | Top Sellers `col-7` + Category Mix `col-5` (was `col-5` + `col-4` + `col-3`) |

---

## Task 2 — Menu Management Bug Fix (`admin/index.html`)

| # | Bug | Fix |
|---|---|---|
| 1 | `•••` button wrapping to new row | Changed `.actions` from `flex-wrap: wrap` → `flex-wrap: nowrap; white-space: nowrap` |

---

## Task 3 — Loyalty Points Fix (`admin/customers.html`, `admin/orders.html`)

**Root cause chain:**
1. No `UPDATE` RLS policy on `customers` table → upsert's `ON CONFLICT phone DO UPDATE` was blocked for returning customers → `customer_id = null` on orders
2. `accrue_loyalty_for_order` early-returns when `customer_id IS NULL` → no points
3. Fire-and-forget `.catch()` in `orders.html` swallowed Supabase errors silently

| # | Fix | File |
|---|---|---|
| 1 | Migration 009 — `customers_update` RLS policy, `recalculate_loyalty_for_customer` RPC | `009_crm_rls_fix.sql` |
| 2 | "↺ Recalculate from Orders" button — backfills points for existing customers | `admin/customers.html` |
| 3 | Loyalty accrual changed from fire-and-forget to `await` | `admin/orders.html` |

---

## Task 4 — Inventory Big-Unit / Small-Unit System (`admin/inventory.html`)

Complete redesign of ingredient input to separate purchase units (big) from usage units (small).

### New 8-Step Ingredient Form

| Step | Field | Logic |
|---|---|---|
| 1 | Name | Text input |
| 2 | Type | วัตถุดิบ / บรรจุภัณฑ์ |
| 3 | Big unit | kg / L / ขวด / กล่อง / กระปุก / ถุง / แพค / แกลลอน |
| 4 | ราคา / big unit (฿) | User input |
| 5 | Conversion | 1 big unit = N small units (g / ml / pcs) |
| 6 | ฿ / small unit | Auto-calculated = field 4 ÷ field 5 |
| 7 | Current stock (big units) | Input → auto-converts to small units for storage |
| 8 | Reorder level (big units) | Input → auto-converts to small units for storage |

### Storage Strategy
- `unit` = small unit (g/ml/pcs) — canonical DB storage and BOM usage unit
- `big_unit` = purchase unit label
- `units_per_big` = conversion ratio
- `cost_per_big` = purchase price stored directly (avoids reverse-calculation precision loss)
- `cost_per_unit` = `cost_per_big / units_per_big` — derived, stored with full numeric precision

### Table Display
- Primary: big-unit stock + big-unit cost (what the owner thinks in)
- Secondary muted: small-unit stock + small-unit cost (what BOM uses)
- Adjust stock / Wastage modals: input in big units, convert internally

### Migrations

| File | Purpose |
|---|---|
| `010_ingredient_units.sql` | `ingredient_type`, `big_unit`, `units_per_big`, `cost_per_big` columns |
| `011_compound_ingredients.sql` | `is_compound`, `batch_yield`, `compound_ingredient_parts` table; updated `deduct_bom_for_order` |

### Cost Display Fix
- `cost_per_unit numeric(10,2)` was the root cause of "0.0000 THB/ml" bug — `0.075` stored as `0.08`
- Migration 011 runs `ALTER COLUMN cost_per_unit TYPE numeric` (removes scale constraint)
- `fmtCost4()` — adaptive decimal formatter: shows enough dp to represent the actual value (e.g. `฿0.000150` not `฿0.0000`)

---

## Task 5 — Compound Ingredients (`admin/inventory.html`)

New concept: ingredients made from other ingredients (e.g. น้ำเชื่อม, น้ำปรุง).

| Feature | Detail |
|---|---|
| Modal toggle | "วัตถุดิบผสม" checkbox; hides cost field, shows recipe builder |
| Batch yield | How much compound ingredient the recipe produces (in big units) |
| Parts builder | Select raw ingredient + qty (in small units); live cost per line |
| Auto-cost calc | Total cost / batch → ฿/big unit → ฿/small unit |
| Table badge | Amber "ผสม" badge on compound ingredient rows |
| Chain deduction | `deduct_bom_for_order` resolves compound BOM entries → deducts raw parts, not the compound; `ON CONFLICT DO UPDATE` aggregates when same raw ingredient appears in multiple compound BOMs |

---

## Task 6 — BOM Seed (`supabase/migrations/012_bom_seed_common.sql`)

Added 8 common base ingredients + BOM entries for all 19 active Matcha & Drinks menus.

| Ingredient | Unit | Type |
|---|---|---|
| น้ำเชื่อมมิตรผล | ml | ingredient |
| น้ำแข็ง | g | ingredient |
| แก้ว PET 14oz + ฝายกดื่มปาก 98 | pcs | packaging |
| กระดาษปิดกันน้ำ | pcs | packaging |
| ถ้วยพลาสติก 3 oz | pcs | packaging |
| ถุงซิปน้ำแข็ง 12*17 | pcs | packaging |
| ถุงหิ้วเดี่ยวไฮโซ | pcs | packaging |
| หลอดไม่งอ 6 มิล | pcs | packaging |

---

## Task 7 — Purchase Orders Big-Unit Alignment (`admin/purchase-orders.html`)

**Root cause:** `receive_po_items` adds `qty_received` directly to `current_stock` (small units) and uses `unit_cost` as cost per small unit. The old UI stored big-unit values, causing a unit mismatch.

| Change | Detail |
|---|---|
| `loadIngredients` | Now fetches `big_unit`, `units_per_big`, `cost_per_big`, `cost_per_unit` |
| PO builder | Dropdown stores big-unit metadata; unit cost auto-fills from `cost_per_big`; all inputs in big units |
| Save logic | Converts big → small before inserting (`qty × upb`, `cost / upb`) |
| Detail view | Converts small → big for display |
| Receive modal | Input in big units; converts before RPC; `data-upb` on each row |
| `confirmReceive` | Proper try-catch, close modal + toast immediately on success (not after `loadPOs`), removed flawed JS over-receipt guard (DB handles it) |
| Migration 013 | `unit_cost TYPE numeric` (was `numeric(10,2)`); `receive_po_items` ROUND `2` → `6` dp |
| PO# search | Search box in list view; searches by PO#, supplier name, status |

---

## Task 8 — Accounting & Finance Bug Fixes

### Root Cause: Missing GRANT EXECUTE (Migration 014)

`record_order_income` and `record_purchase_expense` were created in migration 008 **without** `GRANT EXECUTE TO authenticated`. Every call from the frontend returned "permission denied" — silently swallowed by `.catch()`.

| Migration | Fix |
|---|---|
| `014_accounting_grants.sql` | `GRANT EXECUTE` for both functions; `SET search_path = public`; `record_purchase_expense` now uses `quantity_received × unit_cost` (not `quantity_ordered`) |
| `015_accounting_backfill.sql` | Backfills all historical paid orders and received POs; uses Bangkok timezone for `entry_date` |
| `016_accounting_timezone.sql` | Replaces `CURRENT_DATE` with `(NOW() AT TIME ZONE 'Asia/Bangkok')::date` in both functions; uppercases PO# in descriptions |

### Hooks Fixed
| File | Change |
|---|---|
| `admin/orders.html` — `markPaid()` | Changed from fire-and-forget `.catch()` → `await` with error logging |
| `admin/purchase-orders.html` — `confirmReceive()` | Same fire-and-forget → `await` fix |

---

## Task 9 — Period Picker Standardisation (All Pages)

Replaced inconsistent period labels (Today/Week/Month) with rolling-window labels across all 4 data pages.

| Page | Old | New |
|---|---|---|
| `dashboard.html` | Today / Week / Month / Custom | Today / Last 7d / Last 30d / Custom |
| `reports.html` (all 3 tabs) | Today / Week / Month / Custom | Today / Last 7d / Last 30d / Custom |
| `accounting.html` | Today / Week / Month / Custom | Today / Last 7d / Last 30d / Custom |
| `finance.html` | Week / Month / Custom | Today / Last 7d / Last 30d / Custom |

Additional:
- Removed 7-day minimum for finance custom range (Today is now valid)
- Default period changed from `month` → `30d` on accounting and finance

### Accounting PO# Search
- Search bar added to accounting.html — searches `description` AND `reference_id` (hyphens stripped for flexible UUID matching)

---

## Task 10 — Finance P&L White Background (`admin/finance.html`)

Added `style="background:#ffffff;"` inline on the P&L Statement card only. Fixed Costs Manager card keeps the warm cream background.

---

## Task 11 — Sidebar Navigation Restructure (All 13 Admin Pages)

Replaced flat 13-link list with 4 labelled groups.

| Group | Pages |
|---|---|
| **Management** | Order Queue, Menu Management, Options, Customers |
| **Inventory** | Inventory, Suppliers, Purchases |
| **Analysis** | Dashboard, Reports, Accounting, Finance |
| **Setting** | Staff, Printers |

**CSS added to `design-system.css`:**
- `.sidebar-group-label` — section header style (10px, uppercase, muted)
- `.sidebar-nav { flex: 1; overflow-y: auto; min-height: 0; }` — scroll fix for long nav lists

---

## Task 12 — Shop Open/Close Toggle Moved (`admin/index.html` → `admin/orders.html`)

Toggle relocated from Menu Management topbar to Order Queue topbar — more logical since staff opens the order queue first every shift.

| Change | Detail |
|---|---|
| `admin/index.html` | Removed CSS, button HTML, Close Shop modal, toggle JS functions; `loadShop()` kept (still needs `shopId` for menu item creation) |
| `admin/orders.html` | Added CSS, button between spacer and auto-print toggle, Close Shop modal HTML, full JS (state vars, `loadShop`, `updateShopToggleBtn`, click handler, `closeCloseShopModal`, `confirmCloseShop`); `init()` now calls `await loadShop()` |
| Bug fix | Added `.modal-overlay` + `.modal-overlay.show` CSS to orders.html (page had no modals before) |
| Bug fix | Removed orphaned `}` `});` brackets left in index.html that caused JS syntax error |
| Button labels | Thai: ยกเลิก / 🔒 ปิดร้าน |

---

## Database Migrations (This Session)

| File | Purpose |
|---|---|
| `009_crm_rls_fix.sql` | customers UPDATE policy + recalculate_loyalty_for_customer RPC |
| `010_ingredient_units.sql` | big_unit, units_per_big, cost_per_big, ingredient_type columns |
| `011_compound_ingredients.sql` | is_compound, batch_yield, compound_ingredient_parts; updated deduct_bom_for_order |
| `012_bom_seed_common.sql` | 8 base ingredients + BOM for all Matcha & Drinks menus |
| `013_po_unit_cost_precision.sql` | unit_cost → numeric; receive_po_items ROUND 2→6dp |
| `014_accounting_grants.sql` | GRANT EXECUTE for accounting functions + search_path fix |
| `015_accounting_backfill.sql` | Backfill historical accounting entries with Bangkok timezone dates |
| `016_accounting_timezone.sql` | CURRENT_DATE → Bangkok timezone in both accounting functions |
| `017_bom_option_overrides.sql` | bom_option_overrides table + `_do_ingredient_deduction` helper + updated `deduct_bom_for_order` with option override logic |

---

---

# Option-Based BOM Override System
**Session Date:** 2026-06-02
**Scope:** Allow inventory deduction to be customized per option choice selected by customer

---

## Problem

Base BOM deduction was menu-level only — it ignored which options the customer selected. For example:
- Customer selects **Matcha Grade: High** → system still deducted the default matcha (medium)
- Customer selects **แยกน้ำแข็ง** → system did not deduct the separate ice bag packaging

---

## Solution: `bom_option_overrides` Table + 3 Rule Types

| Action | Description | Example |
|---|---|---|
| `replace` | Swap a default ingredient with another | matcha medium → matcha high |
| `add` | Inject extra ingredients not in base BOM | เลือกแยกน้ำแข็ง → add ถุงซิปน้ำแข็ง |
| `remove` | Skip a default BOM ingredient | เลือกไม่ใส่น้ำแข็ง → skip น้ำแข็ง |

---

## Database Changes

### New Table: `bom_option_overrides`

| Column | Purpose |
|---|---|
| `choice_id` | FK to `option_template_choices` — which option choice triggers this rule |
| `action` | `replace` / `add` / `remove` |
| `target_ingredient_id` | Ingredient to be replaced or removed (required for `replace` / `remove`) |
| `ingredient_id` | Ingredient to use instead or to add (required for `replace` / `add`) |
| `quantity_used` | Qty for `add`; null on `replace` = inherit qty from BOM |

### New Helper Function: `_do_ingredient_deduction(order_id, ingredient_id, total, is_compound, batch_yield)`
Extracted the compound/normal deduction block from `deduct_bom_for_order` into a reusable helper to avoid code duplication.

### Updated: `deduct_bom_for_order`

Per order_item, now runs 3 phases:
1. **Base BOM** — deduct default ingredients, skipping those overridden by chosen options
2. **Replace overrides** — deduct the substitute ingredient (qty from BOM if `quantity_used` is null)
3. **Add overrides** — deduct extra ingredients injected by chosen options

---

## Admin UI Changes (`admin/inventory.html`)

- **BOM Tab** — "⚙ Option Overrides" button appears after selecting a menu
- Clicking opens a modal organized by **Option Group → Choice**
- Each choice shows its current rules (badge + description + delete ✕)
- "+ Rule" button per choice → inline form appears below:
  - Action selector (replace / add / remove)
  - Conditional fields per action type
  - Save / Cancel
- Rules update in-place without full modal reload

---

## Files Changed

| File | Change |
|---|---|
| `supabase/migrations/017_bom_option_overrides.sql` | New migration |
| `admin/inventory.html` | Added ⚙ button, overrides modal, CSS, JS |

---

---

# Promotion Management System
**Session Date:** 2026-06-02
**Scope:** Promotion management in admin/index.html + customer-facing promo logic in index.html

---

## Deliverables

| # | Deliverable | Files |
|---|---|---|
| 1 | Database schema — promotions + promotion_items tables, discount_amount on orders | `supabase/migrations/018_promotions.sql` |
| 2 | Admin promotion management — section tab, promo cards, add/edit/toggle/delete | `admin/index.html` |
| 3 | Customer promo logic — promo loading, effective price, ribbon badges, bundle cart | `index.html` |

---

## Promo Types

| Type | Behavior | Customer View |
|---|---|---|
| `item_discount` | Single/multi menu, % or ฿ off | Red ribbon badge on card, strikethrough original price |
| `bundle` | Set of 2+ menus → fixed bundle_price | Purple "🎁 เซต" tag on all bundled cards, discount line in cart |

---

## Admin UI (`admin/index.html`)

- New page-level tab row: "📋 เมนู" / "🏷 โปรโมชัน"
- On Promotions tab: promo card grid + "+ เพิ่มโปรโมชัน" button
- Each card shows: type badge, discount value, menu list, dates, active status, Edit/Toggle/Delete
- Add/Edit modal: name, type, menus multi-select, discount type+value or bundle price, date range, active toggle
- Menu table rows show small promo badge next to item name when a promo is active

---

## Customer Logic (`index.html`)

- Active promotions loaded after menu renders (non-blocking)
- `getEffectivePrice(item)` — calculates discounted price from `PROMO_MAP`
- `calcBundleDiscount()` — checks if all bundle menu_ids in cart, returns discount amount
- Menu cards: red ribbon ("-20%" / "-฿10") or purple "🎁 เซต" badge depending on type
- Discounted items: strikethrough original price + red promo price
- Cart / drawer summary: "🎁 BundleName … -XX ฿" discount line when bundle active
- Order insert: `discount_amount`, `promotion_id`, `subtotal` (before discount), `total_price` (after discount)

---

## Database Changes

| Table/Column | Change |
|---|---|
| `promotions` | New table |
| `promotion_items` | New table (links promotions to menus) |
| `orders.discount_amount` | New column `numeric(10,2) DEFAULT 0` |
| `orders.promotion_id` | New column FK → promotions |

---

## Files Changed

| File | Change |
|---|---|
| `supabase/migrations/018_promotions.sql` | New migration |
| `admin/index.html` | Page tabs, promo section, promo modal, promo JS |
| `index.html` | Promo state, loadPromotions, getEffectivePrice, calcBundleDiscount, card decoration, cart discount |

---

---

# Session 6 — BOM Option Overrides, Promotion System, Bug Fixes
**Session Date:** 2026-06-02
**Scope:** Option-based ingredient deduction, promotion management, price display fixes, reports/accounting data freshness fixes

---

## Feature 1 — BOM Option Override System

### Problem
The BOM deduction (`deduct_bom_for_order`) was menu-level only. When a customer selected options like Matcha Grade "High" or "แยกน้ำแข็ง", the system still deducted default ingredients instead of adjusting for the selected options.

### Solution

**New table: `bom_option_overrides`** — maps option choices to ingredient deduction rules with 3 action types:

| Action | Description | Example |
|---|---|---|
| `replace` | Swap a default ingredient with another | Matcha Grade High → deduct matcha high instead of medium |
| `add` | Inject extra ingredients not in base BOM | แยกน้ำแข็ง → also deduct ถุงซิปน้ำแข็ง |
| `remove` | Skip a default BOM ingredient | ไม่ใส่น้ำแข็ง → skip น้ำแข็ง deduction |

**New helper function: `_do_ingredient_deduction`** — extracted compound/normal deduction logic from `deduct_bom_for_order` to a reusable helper.

**Updated `deduct_bom_for_order`** — now runs 3 phases per order_item:
1. Base BOM, skipping ingredients overridden by chosen options
2. Replace overrides — deduct substitute ingredient (inherits BOM qty if `quantity_used` is null)
3. Add overrides — inject extra ingredients

**Admin UI** (`admin/inventory.html`):
- "⚙ Option Overrides" button appears in BOM tab when a menu is selected
- Modal organized by Option Group → Choice → rules list
- Inline "+Rule" form per choice with conditional fields per action type

### Files
| File | Change |
|---|---|
| `supabase/migrations/017_bom_option_overrides.sql` | New table + helper function + updated `deduct_bom_for_order` |
| `admin/inventory.html` | ⚙ button, overrides modal, CSS, JS |

---

## Feature 2 — Promotion Management System

### Promotion Types

| Type | Behavior |
|---|---|
| `item_discount` | Single/multi menu, % or ฿ off. Effective price applied per item in cart. |
| `bundle` | All menus in set must be in cart → discount applied at order level. |

### Admin UI (`admin/index.html`)
- New page-level tab row: "📋 เมนู" / "🏷 โปรโมชัน"
- Promotions section: card grid showing type badge, discount value, menus, dates, status
- Add/Edit modal: name, type, multi-select menus, discount params, date range, active toggle
- Menu table rows show small promo badge (SALE / 🎁 เซต) next to item name when active

### Customer UI (`index.html`)
- `loadPromotions()` loads active promos non-blocking after menu renders
- `PROMO_MAP` (menuId → promo) and `BUNDLE_PROMOS` array built for O(1) lookup
- `getEffectivePrice(item)` applies discount for card display, modal price, and cart storage
- Red ribbon badge ("-20%" / "-฿10") on discounted card images
- Purple "🎁 เซต" tag on bundle-involved cards
- Cart / checkout drawer shows bundle discount as a separate line

### Order Submission
- `subtotal` = pre-discount total (original prices × qty)
- `discount_amount` = item discounts + bundle discounts
- `total_price` = subtotal − discount_amount (final charged amount)
- `promotion_id` = FK to applied bundle promo (if any)

### Bug: `openAddPromoModal` did nothing
`openPromoModal` called `escHtml()` which was defined in `index.html` but never defined in `admin/index.html`. JS threw `ReferenceError` before reaching `classList.add('show')`. Fixed by adding `escHtml()` to admin/index.html.

### Files
| File | Change |
|---|---|
| `supabase/migrations/018_promotions.sql` | `promotions`, `promotion_items` tables; `orders.discount_amount`, `orders.promotion_id` columns |
| `admin/index.html` | Page tabs, promo card grid, promo modal, `escHtml`, promo JS |
| `index.html` | Promo state globals, `loadPromotions`, `getEffectivePrice`, `calcBundleDiscount`, card decoration, cart discount line, corrected order insert |

---

## Bug Fix — Promotion Price Not Reflected in Cart / Backend

### Root Causes

| # | Bug | Fix |
|---|---|---|
| 1 | `modalBasePrice` in the order modal always showed original price — customer saw ฿100 when discount should show ฿80 | Updated `openModal` to render strikethrough original + red discounted price when promo active |
| 2 | Cart items had no indicator the discount was applied — user couldn't tell if price was original or discounted | Added `original_price` field to cart items; cart row shows ~~100~~ 80 ฿ for discounted items |
| 3 | `orders.subtotal` stored the post-discount total; `discount_amount` was always 0 for item discounts — no visible discount in the DB record | Recalculated: `subtotal` = pre-discount total, `discount_amount` = item discounts + bundle discounts, `total_price` = final |

---

## Bug Fix — Reports / Accounting / Finance Showing Stale Data

### Root Causes

| # | Bug | Affected Pages | Fix |
|---|---|---|---|
| 1 | No Realtime subscription or visibility refresh — pages only loaded data once on init | reports, accounting, finance | Added `postgres_changes` Realtime channel + `visibilitychange` listener to all three pages |
| 2 | Datetime strings `T00:00:00` / `T23:59:59` had no timezone suffix — Supabase treated them as UTC, missing Bangkok orders placed before 7 AM | reports, finance | Added `toUtcISO(dateStr, endOfDay)` helper using `new Date(y, m-1, d, ...).toISOString()` — correctly converts Bangkok local midnight to UTC |
| 3 | `order_items` has no `created_at` column — Menu & Options tab filter silently returned nothing | reports | Fixed: two-step query — fetch order IDs via `orders.created_at`, then filter `order_items` by `order_id IN (...)` |

---

## Bug Fix — Accounting Auto-Record Not Working

### Root Causes

| # | Bug | Fix |
|---|---|---|
| 1 | `accounting_entries` was never added to the `supabase_realtime` publication — Realtime channel subscribed but received zero events | Migration 019: `ALTER PUBLICATION supabase_realtime ADD TABLE accounting_entries` |
| 2 | `markPaid` in `orders.html` used `console.warn` for RPC errors — user had no visibility when `record_order_income` failed | Changed to `showToast(..., true)` so failures appear as visible red toast |
| 3 | No fallback refresh for accounting.html if Realtime unavailable | Added `setInterval(loadEntries, 30000)` — 30-second polling safety net |

---

## Database Migrations (This Session)

| File | Purpose |
|---|---|
| `017_bom_option_overrides.sql` | `bom_option_overrides` table + `_do_ingredient_deduction` helper + updated `deduct_bom_for_order` |
| `018_promotions.sql` | `promotions` + `promotion_items` tables; `orders.discount_amount` + `orders.promotion_id` columns |
| `019_accounting_realtime.sql` | Add `accounting_entries` to Realtime publication; re-grant function execute permissions |

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/017_bom_option_overrides.sql` | New — BOM option overrides schema + updated deduction function |
| `supabase/migrations/018_promotions.sql` | New — Promotions schema |
| `supabase/migrations/019_accounting_realtime.sql` | New — Realtime publication + function grants |
| `admin/inventory.html` | ⚙ Option Overrides button + modal + CSS + JS |
| `admin/index.html` | Section tabs, promo card grid, promo modal, escHtml, promo JS |
| `admin/orders.html` | `markPaid` error visibility: console.warn → showToast |
| `admin/reports.html` | `toUtcISO` helper, timezone fix on all 4 queries, `order_items` query fix, Realtime + visibilitychange |
| `admin/accounting.html` | Realtime channel, visibilitychange, 30s polling interval |
| `admin/finance.html` | `cogsFrom/To` timezone fix, Realtime channel, visibilitychange |
| `index.html` | Full promotion system: promo globals, loadPromotions, getEffectivePrice, card decoration, modal price, cart strikethrough, order discount recording |

---

---

# Session 7 — Delivery Fee + Menu Status Toggle
**Session Date:** 2026-06-07
**Scope:** Delivery cost system (DB + frontend + admin config), menu status toggle switch in place of ••• dropdown

---

## Feature 1 — Delivery Cost System

### Problem
Every order was flat no-cost. No delivery fee was recorded in the DB, displayed to the customer, or configurable by the admin.

### Solution

**Migration `020_delivery_fee.sql`:**
- `shops.delivery_fee numeric(10,2) DEFAULT 10` — admin-configurable live setting
- `orders.delivery_fee numeric(10,2) DEFAULT 0` — snapshot at order time so historical records stay accurate

**Customer ordering page (`index.html`):**

| Change | Detail |
|---|---|
| Global `DELIVERY_FEE = 10` | Loaded from `shops.delivery_fee` on page init |
| Cart panel + cart sheet | New `.cart-delivery-line` row (brown, dashed border top) after discount line; `finalTotal += DELIVERY_FEE` |
| Cart FAB | Total in floating button now includes delivery fee |
| Checkout drawer | Delivery fee row in order summary (`renderDrawerSummary`); `finalTotal += DELIVERY_FEE` |
| Order submit | `delivery_fee: DELIVERY_FEE` added to `orders` insert; `total_price = subtotal − discount + DELIVERY_FEE` |
| Translations | `deliveryFee: 'ค่าจัดส่ง'` (TH) / `'Delivery'` (EN) |

**Admin panel (`admin/index.html`):**

| Change | Detail |
|---|---|
| New page tab | "⚙️ ตั้งค่าร้าน" alongside เมนู / โปรโมชัน |
| Settings section | Card with delivery fee number input + "บันทึก" button |
| `saveDeliveryFee()` | Validates input, updates `shops.delivery_fee` via Supabase, shows toast |
| `loadShop()` | Now also loads `delivery_fee` into `currentDeliveryFee` |
| `switchSection('settings')` | Hides page action button; auto-populates input with current value |

**Accounting:** No change needed — `record_order_income` already uses `total_price` which now includes the delivery fee.

---

## Feature 2 — Menu Status Toggle Switch

### Problem
Enabling/disabling a menu item required: clicking `•••` → clicking Disable/Enable in dropdown — 2 clicks and not immediately obvious.

### Solution
Replaced the static Active/Inactive badge in the Status column with a clickable iOS-style toggle switch. Single click flips state immediately.

| Change | Detail |
|---|---|
| CSS `.status-toggle` | 40×22px pill — gray (`#d1d5db`) when off, green (`#22c55e`) when on |
| CSS `.status-toggle-knob` | White circle, 0.18s sliding animation via `left` transition |
| Status column HTML | `<button class="status-toggle [on]">` replaces `<span class="badge">` |
| `•••` dropdown | Disable/Enable item removed — now only Options + Delete remain |
| `toggleActive()` | Reused as-is — no backend change |

---

## Database Migrations (This Session)

| File | Purpose |
|---|---|
| `020_delivery_fee.sql` | `shops.delivery_fee` (configurable default) + `orders.delivery_fee` (order snapshot) |

**Run this migration in Supabase SQL Editor before deploying.**

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/020_delivery_fee.sql` | New — delivery fee columns |
| `index.html` | Delivery fee: global var, cart line, drawer line, FAB total, submit insert, translations |
| `admin/index.html` | Delivery fee: Settings tab + card + save function; status column: toggle switch, ••• dropdown trimmed |

---

# Session 8 — Admin System Mobile Responsiveness Pass
**Session Date:** 2026-06-08 / 2026-06-09
**Scope:** Full systematic mobile audit + patch across all 13 admin pages, targeting phone widths (~375–430px)

---

## Approach

The admin system was originally designed desktop-first. Staff increasingly check orders/inventory/reports from personal phones at the counter, so every admin page got a phone-width pass.

**Decisions made:**
- **CSS-only, page-level changes** — added `@media` blocks inside each page's existing `<style>` block rather than centralizing into `css/design-system.css`. Reason: design-system.css loads *before* each page's own styles, so same-specificity overrides would lose to source order; pages also redefine shared classes (`.modal`, `.table-wrap`, `.sidebar`) with page-specific values, making one shared block fragile.
- **Column-hiding via `nth-child` over card-conversion** — wide tables get 2–4 less-critical columns hidden at ≤640px (e.g. Email/Phone/Contact, Unit/Reorder/Cost) rather than restructuring rows into cards in JS. Keeps every change additive CSS with zero risk to row-rendering logic.
- **Standard breakpoints**: `@media (max-width: 640px)` as the primary phone breakpoint (a few pages already used 700px/720px/768px conventions from earlier sessions — left those in place and layered phone-specific rules on top), with supplementary `400px`/`480px`/`360px` blocks for extra-narrow refinements.

## Pages Patched

| Page | Key changes |
|---|---|
| `admin/index.html` (Menu Mgmt) | Hid drag-handle/Category/Cost/FC% columns on the 9-col menu table (also Photo at 400px); responsive promo-grid, settings-card, page-tabs-row |
| `admin/options.html` | Card-based layout already; compacted `.template-header`, `.choice-row` (drag-handle/name/TH/price/edit/delete), `.add-choice-row` |
| `admin/users.html` | Hid Email column on the 5-col staff table; switched `.table-wrap` to `overflow-x: auto` |
| `admin/printer.html` | Forced `.printer-grid` to single column; modal padding + `.ip-port-row` tweaks |
| `admin/suppliers.html` | Hid Contact/Phone/Email columns on the 6-col supplier table, kept Name/Status/Actions |
| `admin/orders.html` (Order Queue + KDS) | Reduced topbar gap/padding, hid `.topbar-page-label` and `#lastUpdate`, shrank shop-toggle/autoprint controls; added `360px` refinement |
| `admin/dashboard.html` (Sales Dashboard) | Added `hdr-controls` className to the period-picker/live-indicator/clock row so it wraps on narrow screens; shrank seg buttons, live indicator, clock, range-picker popover, KPI values, hours-grid (4→2 cols), category mix (stacked), heatmap grid/labels, customer table |
| `admin/inventory.html` | Hid Unit/Reorder Point/Cost-per-Unit on the ingredients table (kept Name/Stock/Status/Actions); stacked form rows, wrapped BOM/override rows, compacted compound-parts table, full-width overrides modal |
| `admin/reports.html` | Compacted tab bar, constrained date-popover width; hid columns per tab — Sales keeps Date/Order#/Customer/Total/Status, Menu keeps Item/Qty/Revenue/FC%, Inventory keeps Ingredient/Stock/Status/Stock Value |
| `admin/finance.html` | Reduced card padding and P&L value column widths/fonts, constrained date popover, wrapped fixed-cost rows, stacked modal form rows |
| `admin/accounting.html` | Hid Type/Category columns on the journal entries table, constrained date popover, stacked form rows |
| `admin/customers.html` | Already had solid two-panel mobile handling (collapsing CRM layout, mobile-back-button, 2-col stats-bar); added `480px` refinement — stacked form rows, smaller loyalty-points display/profile name, compacted ledger table |
| `admin/purchase-orders.html` | **Fixed an existing mobile bug**: the prior `@media(max-width:640px)` rule hid columns 3+ of the line-item builder, silently removing the price input, notes field, and remove button — making it impossible to set a price or delete a row from a phone. Replaced with a proper stacked-card layout using CSS grid-areas that keeps every field accessible. Also hid Items/Created on the PO list table and Unit/Remaining/Notes on the line-items detail table |

## Notable Find — Purchase Orders Line-Item Bug

`admin/purchase-orders.html` already had a `@media (max-width: 640px)` rule from an earlier session that collapsed `.po-line-row` to a 2-column grid and hid every child past the 2nd (`*:nth-child(n+3) { display: none }`). Since each row is `<select> <input qty> <span unit> <input price> <input note> <button remove>`, this silently hid the **price input, notes field, and remove button** — staff on phones could add ingredients and quantities to a PO but could not set a price or remove a row. Replaced it with a single-column "card" layout per line item using `grid-template-areas`, mapped via `:nth-of-type` on the `<select>`/`<input>`/`<span>`/`<button>` children — every control is now reachable on a phone screen.

## Files Changed This Session

| File | Type of Change |
|---|---|
| `admin/index.html` | Phone media queries — column hiding, grids, tabs |
| `admin/options.html` | Phone media queries — template/choice cards |
| `admin/users.html` | Phone media queries — column hiding, table scroll |
| `admin/printer.html` | Phone media queries — single-column printer grid |
| `admin/suppliers.html` | Phone media queries — column hiding |
| `admin/orders.html` | Phone media queries — topbar compaction |
| `admin/dashboard.html` | Added `hdr-controls` className (JSX) + phone media queries — header controls, KPIs, charts, heatmap, tables |
| `admin/inventory.html` | Phone media queries — column hiding, BOM/override/compound layouts |
| `admin/reports.html` | Phone media queries — column hiding across 3 tabs, popover sizing |
| `admin/finance.html` | Phone media queries — P&L card, fixed-cost rows, popover sizing |
| `admin/accounting.html` | Phone media queries — column hiding, popover sizing |
| `admin/customers.html` | Phone media queries — form rows, loyalty display, ledger table |
| `admin/purchase-orders.html` | **Bug fix** — rebuilt broken mobile line-item layout; phone media queries — column hiding on PO list & line-items tables |

---

---

# Security Review & Hardening — Order Pricing, RLS, PII
**Session Date:** 2026-06-12 / 2026-06-13
**Scope:** Full code review of `index.html` + 13 `admin/` pages (with Alex code-reviewer), then a two-phase security fix: server-side order pricing authority, RLS lockdown, LINE-notify repair, repo sync, and Phase-2 hardening.

---

## Headline Problem — Client-Authoritative Pricing

The customer app computed `subtotal`, `discount_amount`, `unit_price`, and `total_price` **in the browser** and inserted them directly into `orders` / `order_items` / `order_item_options` using the public anon key. Because the RLS insert policies were `with check (true)`, anyone could submit an order at any price (e.g. ฿0). Those client-set totals fed straight into:
- `record_order_income` → the accounting ledger (revenue)
- `accrue_loyalty_for_order` → `FLOOR(total_price/10)` loyalty points

**Proven exploitable** by a live anon-key test (see Live Pentest below).

---

## Live Pentest (authorized, against production)

| Test | Method | Result | Meaning |
|---|---|---|---|
| Forge ฿0 order | `POST /rest/v1/orders` with anon key, `total_price:0` | `201 Created` (ORD-1027) | **A1 confirmed** — price tampering works |
| Delete that order | `DELETE` with anon key | `200`, 0 rows | Delete correctly blocked (good) |
| Read all orders | `GET /rest/v1/orders` with anon key | `200`, real customer name/phone/address | **A7 found** — PII leak (anyone can read every order) |

A7 traced to the manual `orders_read_own using(true)` SELECT policy added during the Phase 1A Bug #4 fix.

---

## Phase 1 Fix — Server-Side Pricing Authority

| # | Deliverable | File |
|---|---|---|
| 1 | `create_order(p_payload jsonb)` RPC — recomputes ALL prices server-side from `menus` / `option_template_choices` / `promotions` / `shops`, writes orders+items+options in ONE transaction, returns authoritative total | `supabase/migrations/021_create_order_rpc.sql` |
| 2 | RLS lockdown — drop the permissive `*_insert with check(true)` **and** the public `*_read using(true)` policies on orders/order_items/order_item_options/customers | `supabase/migrations/022_lockdown_order_rls.sql` |
| 3 | `submitOrder()` rewired — sends only menu_ids/choice_ids/qty/notes/customer (NO prices), calls `supabase.rpc('create_order', …)`, shows server-returned total; added `friendlyOrderError()` | `index.html` |

**Design principle:** the browser sends *what* the customer wants, never *how much* it costs. A tampered client has no price field to lie about.

**Key properties of `create_order()`:**
- `SECURITY DEFINER` → bypasses RLS to do the validated atomic write; the RPC becomes the only way to create an order.
- Validates each option choice actually belongs to its menu (via `menu_option_templates`) — rejects hand-crafted payloads.
- Replicates the client promo math exactly (item_discount %/fixed on base price; bundle = max(0, Σ first-occurrence unit prices − bundle_price)).
- `GRANT EXECUTE … TO anon, authenticated`.

**Side benefit:** the atomic write also eliminates the order-items Realtime race patched with a debounce in Phase 1B (items now always exist when the order row becomes visible).

**Two-step rollout** (deliberate): run 021 (additive, safe) and verify ordering works, *then* run 022 (the lockdown). Never lock down before the RPC is proven, so there's always a working fallback.

---

## LINE Notification Repair

After 021 went live, the LINE message showed correct item details but **฿0 total** — and 022 would have made it worse. Two bugs:

| Bug | Cause | Fix |
|---|---|---|
| ฿0 total | Webhook `payload.record` is the row **as first inserted**; `create_order()` inserts the order with `total_price=0` then UPDATEs the real total later in the same transaction → snapshot is stale | Re-fetch the committed order fresh from the DB |
| Empty item list (after 022) | Function read `order_items` with the **anon key**; 022 removes anon read access | Switch reads to `SUPABASE_SERVICE_KEY` (service role bypasses RLS) |

Both fixed in `netlify/functions/line-notify.js` — now one query fetches order + items + options with the service key, with a fallback to the webhook snapshot.

---

## Deploy & Repo Discovery

While trying to deploy the LINE fix, found the git repo was **badly out of sync**: it tracked only `index.html` + `assets/` + a few stale files. The entire real app (`netlify/`, `admin/`, `css/`, `js/`, `supabase/`, `login.html`, etc.) was **untracked, never committed**.

- **Deploy method confirmed:** manual **drag-and-drop** to Netlify (not git auto-deploy). Pushing to GitHub does NOT update the live site.
- **Action:** committed the full project (53 files) to `github.com/mtktt/Glongnom-Matcha.git`, added a `.gitignore`. Repo now reflects reality and serves as real backup.

---

## Phase 2 — Security Hardening

| # | Finding | Fix | File |
|---|---|---|---|
| A3 | Search text injected raw into PostgREST `.or()` filter (a `,` or `()` breaks the query / leaks parse errors) | Wrap each ilike pattern in double quotes + escape `\` `"` so reserved chars are literal | `admin/orders.html` |
| A4 | Managers could open User Mgmt and *appear* to change roles, but RLS silently no-op'd → UI falsely showed "Role updated" | Gate Change Role / Deactivate to admins only; add `.select()` so a blocked write reports "permission denied" not false success | `admin/users.html` |
| A5 | `customers_update` was `using(true)` — anyone with the anon key could overwrite any customer's name/address/notes | Replace with `customers_staff_update` (admin/manager/cashier); RPC + loyalty fns bypass RLS so ordering is unaffected | `supabase/migrations/023_phase2_security_hardening.sql` |
| D2 | `receive_po_items` / `record_purchase_expense` callable by any authenticated role | Add `current_user_role() IN ('admin','manager')` guards (bodies reproduced verbatim from 013/016) | `023_phase2_security_hardening.sql` |

**D2 deliberate exception:** `record_order_income` is left UNguarded — `markPaid()` runs on the all-roles orders page, and the function is idempotent over the order's own (now server-authoritative) total.

---

## Verifications (live, against production)

| Check | Result |
|---|---|
| A3 quoted `.or()` syntax valid + comma treated as literal | ✅ old unquoted comma → HTTP 400 parse error; new quoted → HTTP 200 literal |
| A1 insert hole closed (after 022) | ✅ (lockdown applied; direct anon insert now RLS-denied) |
| A5 anon can't tamper customers (after 023) | ✅ anon PATCH → HTTP 200, 0 rows changed |
| A5 didn't break returning-customer ordering | ✅ RPC order for existing phone → ORD-1031, ฿74, upsert UPDATE path works |

---

## Database Migrations (Run Order)

| File | Purpose | Status |
|---|---|---|
| `021_create_order_rpc.sql` | Server-side `create_order()` pricing RPC | Applied |
| `022_lockdown_order_rls.sql` | Drop permissive insert + public-read policies (close A1 + A7) | Applied |
| `023_phase2_security_hardening.sql` | A5 customer-update lockdown + D2 PO RPC role guards | Applied |

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/021_create_order_rpc.sql` | New — server-side order pricing RPC |
| `supabase/migrations/022_lockdown_order_rls.sql` | New — RLS lockdown (insert + read) |
| `supabase/migrations/023_phase2_security_hardening.sql` | New — A5 + D2 hardening |
| `index.html` | `submitOrder()` rewired to RPC; `friendlyOrderError()` |
| `netlify/functions/line-notify.js` | Re-fetch committed order with service-role key (฿0 total + post-022 read fix) |
| `admin/orders.html` | A3 — escape search input for `.or()` filter |
| `admin/users.html` | A4 — admin-only write gating + `.select()` false-success backstop |
| `.gitignore` | New — node_modules / .env / .netlify |
| *(repo sync)* | Committed full project (53 files) to GitHub for the first time |

---

## Remaining Review Backlog (not yet done)

- **Audit all `using(true)` policies** — found the orders PII leak by accident; sweep `inventory`, `suppliers`, `promotions`, etc.
- **Phase 3 polish:** B2 dynamic category tabs (vs hardcoded), B4 image `onerror` fallback, B6 search debounce, D3 surface silent BOM/loyalty failures.
- **Phase 4 maintainability:** C3 de-duplicate sidebar/auth boilerplate across 13 files, C4 extract shared unit-conversion helpers.

---

---

# Order Notifications — LINE → Telegram Migration
**Session Date:** 2026-06-13
**Scope:** Add a Telegram notification channel to replace LINE for new-order alerts, to escape the LINE free-tier push-message cap.

---

## Why

LINE Messaging API free tier ≈ **500 push messages/month** (~16 orders/day, halved when notifying multiple recipients) — the first bottleneck as order volume grows. **Telegram Bot API is free with no monthly message cap** (rate limit only ~30 msg/sec), so it removes that ceiling entirely. Same webhook flow, only the destination changes.

```
Supabase Webhook (INSERT orders) → Netlify Function → Telegram Bot API (group chat)
```

## What was built

| # | Item | Detail |
|---|---|---|
| 1 | `netlify/functions/telegram-notify.js` | New function mirroring `line-notify.js`: verifies `x-webhook-secret`, re-fetches the committed order + items with the **service-role key** (handles the create_order ฿0-snapshot + post-022 RLS lockdown), sends to Telegram |
| 2 | `netlify.toml` | Registered `[functions."telegram-notify"]` (esbuild bundler) |

**Design choices:**
- **Plain text** message (no `parse_mode`) — arbitrary customer names/notes never need Telegram Markdown/HTML escaping.
- **Group chat** target — all staff see one feed; `TELEGRAM_CHAT_ID` supports comma-separated ids (e.g. group + owner DM).
- `line-notify.js` **kept intact as a backup** — rollback is just repointing the Supabase webhook.

## New Environment Variables (Netlify)

| Variable | Value |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Group chat id (negative number, e.g. `-100...`); comma-separated for multiple |

(`SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `WEBHOOK_SECRET` are reused.)

## Activation Steps (manual, owner-side)

1. @BotFather → `/newbot` → get token
2. Create group, add bot, get chat id (e.g. via @getidsbot, then remove it)
3. Set the two env vars in Netlify
4. **Deploy** (drag-and-drop) so the function exists, *then* repoint the Supabase `orders` webhook URL from `/line-notify` → `/telegram-notify` (keep the `x-webhook-secret` header)

## Files Changed This Session

| File | Type of Change |
|---|---|
| `netlify/functions/telegram-notify.js` | New — Telegram order-notification function |
| `netlify.toml` | Registered telegram-notify function |

---

---

# Rider Delivery System — Pricing Model, Registry & Self-Accept Dispatch
**Session Date:** 2026-07-13
**Scope:** Stand up an in-house delivery operation to cut dependence on LINE MAN — a model for what to pay riders, a rider registry + job-history admin page (Phase 1), and a public "tap-to-accept" dispatch flow driven from the order queue (Phase 2).

---

## Why

LINE MAN / Grab take ~30% GP per order and own the customer relationship. Glongnom sits opposite Thammasat Rangsit (Dcondo Dome) with ~60% of orders within 0–3 km and ~40% within 3–5 km — a tight, campus-dense radius where an in-house rider running clustered short trips earns a good ฿/hr while costing the shop far less than platform GP. This session built both the pricing rationale and the operational tooling.

```
Order queue → [🛵 Rider] → OPEN rider_job + link /r.html?job=<token>
   → paste in LINE group → registered rider taps รับงาน (first wins, atomic)
   → picked_up → delivered  (each auto-stamped)
```

## Part 0 — Delivery pricing model (planning tool)

Benchmarked real LINE MAN rider pay (green zone = Pathum Thani/Rangsit ≈ 37฿ base 2566, cut to ~28฿ Apr 2025; +~7฿/km beyond 2 km; batch add-on ~15–17฿; rates falling for years). Derived an **all-win** pricing identity:

> `price = 2·(food cost) + 2·(rider_fee − customer_fee) / (cups per order)`

Decisive lever = **basket size**; single-cup delivery is the margin killer. A 2-cup / ฿120 minimum + free delivery ≥ ฿250 closes the math so shop (50% contribution margin), customer (≤15฿ delivery), and rider (~app rate) all win.

- Recommended rider pay: **base 25฿ (incl. first 3 km) + 6฿/km beyond 3 km + time/weather bonus**.
- Customer fee tiers: **0–1 km = 10฿ · 1–3 km = 15฿ · 3 km+ = 20฿**.
- `rider-pay-calculator.html` (repo root) — standalone interactive calculator; per-dorm pay/fee table (11 real TU-Rangsit dorms, editable, auto-distance via Haversine, localStorage + CSV import/export) + a Margin & Basket tab. **Planning tool only — not wired to the app DB.**

## Part 1 — Rider registry + job history (admin · migration 024)

| # | Item | Detail |
|---|---|---|
| 1 | `riders` table | name, phone, line_id, vehicle, is_active, note |
| 2 | `rider_jobs` table | rider_id, order_id + order snapshot (order_no, customer, address, dropoff_label, distance_km), `rider_fee`, status, assigned/accepted/delivered timestamps, `accept_token` |
| 3 | `admin/rider.html` | 2 tabs — **ไรเดอร์** (CRUD cards) + **ประวัติการรับงาน** (job log w/ filters, summary incl. total rider fees). Job modal "ดึงจากเลขออเดอร์" prefills from `orders`. Per-job: mark accepted / delivered, copy dispatch text, delete |
| 4 | Sidebar nav | Added `🛵 Riders` link to all 13 other admin pages |

RLS mirrors migration 006: read = any authenticated user; write = staff (admin/manager/cashier).

## Part 2 — Public self-accept dispatch (migration 025)

| # | Item | Detail |
|---|---|---|
| 1 | `riders.claim_token` | Secret per-rider identity (128-bit). Device remembers it via a one-time personal link `/r.html?setup=<claim_token>` |
| 2 | `rider_jobs` — `open` status + `picked_up_at` | New broadcast status for unclaimed dispatches |
| 3 | 4 SECURITY DEFINER RPCs (granted to `anon`) | `get_rider_identity`, `get_rider_job` (need-to-know info incl. menu items + assigned_at, **no pricing/payment**), `claim_rider_job` (atomic first-come via `UPDATE … WHERE status='open'`), `update_rider_job_status` (owner-only) |
| 4 | `r.html` (repo root, public, no login) | Rider job page. Emphasises **order no / route (รับ→ส่ง) / ค่ารอบ**, plus menu+qty, customer, status, and a live count-up **timer** from `assigned_at` until accepted. Handles `?setup=` and `?job=` |
| 5 | `admin/orders.html` | **🛵 Rider** button on each delivery order card → creates/reuses an OPEN job and auto-copies the LINE-ready link |
| 6 | `admin/rider.html` | Per-rider **🔗 ลิงก์** copies the personal setup link; dispatch text now includes the accept link; `open` status label/badge/filter |

## Identity & security design

- **No rider login.** Each rider's device stores their secret `claim_token` (localStorage) after opening their personal setup link once. Every accept/status call carries that token → the server always knows *which registered rider* acted, and rejects any token that isn't a registered active rider.
- **All public writes go through SECURITY DEFINER RPCs** (like `create_order` in 021) — the anon key never touches these tables directly; every RPC is gated on knowing a 128-bit token.
- **Atomic claim:** `UPDATE rider_jobs SET … WHERE accept_token=? AND status='open'` — concurrent second claim serialises on the row, sees status ≠ open, returns `already_taken`. First rider wins.
- `get_rider_job` exposes only delivery-relevant fields to token holders (customer name/phone/address + menu) — deliberately no totals/payment/margins.

## Activation Steps (manual, owner-side)

1. **Run migrations in order** in Supabase SQL Editor: `024_riders.sql`, then `025_rider_accept.sql` (safe to re-run — 025 is idempotent and DROP/recreates `get_rider_job`).
2. **Deploy** (drag-and-drop) — see Files Changed below.
3. **Test flow:** add a rider → **🔗 ลิงก์** → open on rider phone (setup, device remembers) → order queue **🛵 Rider** on a delivery order → open the job link on that phone → **รับงาน** → รับของ → ส่งสำเร็จ.

## Not yet done (Phase 3 ideas)

- Auto-compute `rider_fee` from distance at dispatch (currently defaults to the order's customer `delivery_fee`).
- Auto-notify the rider LINE group when a new job is dispatched (reuse the `telegram-notify.js` webhook pattern).
- Pull the pickup label from the `shops` table instead of the hardcoded `PICKUP` const in `r.html`.
- Phase 2 identity hardening if needed (LINE Login/LIFF) — deferred; device-claim chosen for zero external setup.

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/024_riders.sql` | New — riders + rider_jobs tables, RLS |
| `supabase/migrations/025_rider_accept.sql` | New — claim_token, `open` status, 4 self-accept RPCs |
| `r.html` | New — public rider tap-to-accept page (root) |
| `admin/rider.html` | New — rider registry + job-history admin page |
| `admin/orders.html` | Added 🛵 Rider dispatch button + `copyToRider`/`copyText` |
| `admin/*.html` (13 pages) | Added `🛵 Riders` sidebar nav link |
| `rider-pay-calculator.html` | New (root) — standalone delivery pricing calculator (planning tool) |

---

# Session Update — 2026-07-15
**Focus:** Address-based delivery pricing · per-dorm rider wages · rider payout tracking · orders workflow tweaks · free-delivery promo

Six connected pieces of work this session. **Migrations must be run in order: 026 → 027 → 028 → 029 → 030.** Then redeploy the changed files (manual drag-and-drop to Netlify — the git repo is not the deploy source).

## Part 1 — Per-dorm delivery fee (migrations 026, 027)

Replaced the single flat delivery fee (`shops.delivery_fee`) with **per-dorm rates** sourced from `glongnom-dorms.csv`. Because pricing is server-authoritative (`create_order` RPC), the rate card lives in the DB so the browser and the RPC read the same numbers.

| # | Item | Detail |
|---|---|---|
| 1 | `026_delivery_zones.sql` | New `delivery_zones(name, customer_pay, is_active, sort_order)` table — anon read / admin+manager write. Seeded from the CSV (45 dorms, tiers 10/15/20฿). Re-runnable via `ON CONFLICT`. |
| 2 | `027_create_order_dorm_fee.sql` | `create_order` now reads `customer.dorm` from the payload, looks up the fee in `delivery_zones`, and **rejects** any dorm not in the table (`INVALID_DELIVERY_ZONE`) — same defense-in-depth as menu/option validation. |
| 3 | `index.html` checkout | The single address box became **two fields**: a required `<select>` dorm dropdown (locked to the CSV list) + a free-text box for building/floor/room. Fee recomputes live on dorm change; payload sends `dorm` separately; combined `"Dorm — detail"` stored as `customer_address`. |

## Part 2 — Admin delivery-rate manager (Settings tab)

Deleted the flat delivery-fee setting; replaced with a **per-dorm manager** in `admin/index.html` → ตั้งค่าร้าน:
- Table of dorms with inline **fee auto-save** on change, **show/hide** checkbox (`is_active`), and **delete**.
- **"+ เพิ่มหอใหม่"** row to add a dorm (name + fee); blocks blanks/dupes.
- Reads/writes `delivery_zones` directly (admin/manager RLS). `shops.delivery_fee` is now unused (column left in place, harmless).

## Part 3 — Per-dorm rider wage `rider_gain` (migration 028)

Decoupled the rider's wage from the customer's delivery fee. **Previously** `admin/orders.html` set `rider_fee = order.delivery_fee` (rider paid = customer fee). **Now** each dorm has its own wage.

| # | Item | Detail |
|---|---|---|
| 1 | `028_rider_gain.sql` | Adds `rider_gain` to `delivery_zones` and a **snapshot** `rider_gain` to `orders`. `create_order` records the dorm's wage on each order at order time (rider_gain is a **shop cost — NOT added to the customer total**). Seeded real wages from `glongnom-dorms.csv` (`rider_gain` column, tiers 20/25/30/40/45฿) via a re-runnable name-matched UPDATE. |
| 2 | `admin/rider.html` | New **"💰 ค่าจ้างไรเดอร์"** tab — per-dorm rider wage editor (auto-save), customer fee shown for reference. |
| 3 | `admin/orders.html` | Dispatch now sets `rider_fee = order.rider_gain \|\| order.delivery_fee \|\| 0` (fallback covers orders placed before 028). Also fills `dropoff_label` with the dorm name. |

Note: rider wage is **not** a straight function of the customer fee — e.g. Golf view / Keystone charge the customer 15฿ but pay the rider 30฿. Decoupling was necessary.

## Part 4 — Rider payout tracking + job-history filters (migration 029)

`admin/rider.html` → **ประวัติการรับงาน** tab enhanced:

| # | Item | Detail |
|---|---|---|
| 1 | `029_rider_job_payout.sql` | Adds `rider_jobs.rider_paid` (bool) + `rider_paid_at`. Internal bookkeeping — deliberately **not** exposed via the public rider RPCs. |
| 2 | Date filter | ตั้งแต่/ถึง date pickers (on `assigned_at`, local-date compare) + paid/unpaid filter + "ล้างตัวกรอง". |
| 3 | Wage subtotal | Summary chips show **ค่าจ้างรวม** + **ค้างจ่ายไรเดอร์** (outstanding); a `<tfoot>` totals the wage column for the current filter. |
| 4 | Paid/unpaid column | New **"จ่ายค่าจ้าง"** column with a one-click toggle (ค้างจ่าย ⇄ ✓ จ่ายแล้ว), stamps `rider_paid_at`. Table is now 10 columns. |

This "shop pays rider" flag is separate from the customer-payment toggle in Part 5 — independent on purpose.

## Part 5 — `admin/orders.html` workflow tweaks

| # | Change | Detail |
|---|---|---|
| 1 | Rider button turns green after copy | After copying the dispatch link, the 🛵 Rider button flips to green **"✓ ส่งไรเดอร์แล้ว"** (resets on next data reload) so staff see which orders were dispatched. |
| 2 | Double-confirm cancel | The ✕ cancel button now calls `cancelOrder()` → **two** confirm prompts (both show the order no) before cancelling. |
| 3 | Payment temporarily disabled | New flag `const AUTO_MARK_PAID = true;` — every unpaid order that loads is auto-marked paid + income recorded (guarded against double-firing). **Flip to `false` to restore manual Unpaid→Paid.** Client-side (runs while the orders page is open). |

## Part 6 — Free-delivery promotion (migration 030)

New third promo type. When active and the order has ≥ `min_qty` cups, the **customer's delivery fee → 0**. **`rider_gain` is untouched — the shop absorbs the delivery cost** (rider still paid in full).

| # | Item | Detail |
|---|---|---|
| 1 | `030_free_delivery_promo.sql` | Adds `free_delivery` promo type + `promotions.min_qty` (default threshold 2). `create_order` counts total cups and zeroes `v_delivery_fee` only when an active free-delivery promo's threshold is met. |
| 2 | Admin `index.html` promo tab | New **"🚛 ส่งฟรี"** type with a "ส่งฟรีเมื่อซื้อครบ N แก้ว" field; menu picker hidden (order-wide). Green promo badge. |
| 3 | Customer `index.html` | `FREE_DELIVERY`/`totalCupCount()`/`freeDeliveryActive()`; cart, drawer, and floating total show the delivery fee struck-through → **"ฟรี / FREE"**. Browser preview mirrors the server rule exactly. |

Cup count = total item qty (any menu counts, incl. rice bowls).

## Activation Steps (manual, owner-side)

1. **Run migrations in Supabase SQL Editor, in order:** `026_delivery_zones.sql` → `027_create_order_dorm_fee.sql` → `028_rider_gain.sql` → `029_rider_job_payout.sql` → `030_free_delivery_promo.sql`.
2. **Deploy (drag-and-drop)** the changed files below.
3. Set real delivery/rider rates in admin if needed (Settings tab for customer fees, rider.html ค่าจ้างไรเดอร์ tab for wages), and create a "ส่งฟรี" promo in the โปรโมชัน tab.

## Open follow-ups (offered, not yet built)

- Customer-facing banner "🚛 สั่งครบ 2 แก้ว ส่งฟรี!" to advertise the promo before ordering (lifts basket size).
- Auto-fill rider fee from `rider_gain` in the *manual* "บันทึกงาน" job form.
- Rider's total outstanding shown on their card in the ไรเดอร์ tab.
- Move auto-mark-paid into the `create_order` RPC if it should apply even when no admin has the orders page open (currently client-side only).
- "Cups" currently counts all menus; restrict to drinks only if desired.

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/026_delivery_zones.sql` | New — per-dorm delivery rate table, seeded from CSV |
| `supabase/migrations/027_create_order_dorm_fee.sql` | New — `create_order` resolves + validates fee by dorm |
| `supabase/migrations/028_rider_gain.sql` | New — per-dorm rider wage + order snapshot; updated `create_order` |
| `supabase/migrations/029_rider_job_payout.sql` | New — `rider_jobs.rider_paid` / `rider_paid_at` |
| `supabase/migrations/030_free_delivery_promo.sql` | New — free_delivery promo type + `min_qty`; updated `create_order` |
| `index.html` | Dorm dropdown + detail box; per-dorm fee; free-delivery display |
| `admin/index.html` | Delivery-rate manager (Settings); free-delivery promo type in โปรโมชัน |
| `admin/rider.html` | ค่าจ้างไรเดอร์ wage tab; job-history date filter, wage subtotal, paid/unpaid column |
| `admin/orders.html` | Dispatch uses `rider_gain`; rider-button recolor; double-confirm cancel; auto-mark-paid flag |
| `glongnom-dorms.csv` | Added `rider_gain` column (source for the 028 seed) |

---

# Session Update — 2026-08-09
**Focus:** Customer Survey · letter/mailbox animation · public response wall · Admin moderation

Created a new branded customer-feedback page at `/survey.html`. The page follows the existing Glongnom cream, pink, and brown palette and uses Sarabun + Itim typography.

## Customer Survey UI

- Three optional questions; the customer must answer at least one:
  1. Food / matcha menu requests
  2. Deliciousness review
  3. Private improvement feedback
- Questions 1 and 2 are compact cards on the first row. Question 3 is a full-width card below them.
- Each question card has a gentle floating animation with staggered timing.
- Optional customer display-name field and a branded send button.
- On successful submission, the form animates into a flying envelope and mailbox, followed by a thank-you card.
- Responsive mobile layout keeps the form compact and moves the public response section close to the form.
- Removed the original survey eyebrow, `Dear Glongnom` heading, dotted card borders, and `MATCHA • RICE` tagline during visual refinement.

## Public response wall

- Default tab is **รีวิวความอร่อย**; customers can switch to **เมนูที่อยากกิน**.
- Approved responses appear as small floating paper notes with staggered motion.
- Improvement feedback is never rendered publicly.
- New responses are hidden by default and require shop approval before appearing.

## Admin moderation

- When an authenticated user with role `admin` or `manager` opens `/survey.html`, a **มุมจัดการจดหมาย** section appears at the bottom.
- The shop can independently publish/hide the menu request and review from each response.
- Controls now clearly say `＋ แสดง...` when private and `✓ กำลังแสดง · กดเพื่อซ่อน` when public.
- Private improvement feedback is visible to Admin/Manager only and has no public toggle.

## Supabase and privacy

| Migration | Detail |
|---|---|
| `032_customer_survey.sql` | Adds `survey_responses`, public anonymous insert, approved-only anonymous reads, Admin/Manager reads and moderation updates, and column-level protection that prevents anonymous clients from selecting `improvement`. |
| `033_survey_optional_answers.sql` | Makes all three answer columns nullable while enforcing that at least one answer is present. Safe upgrade for a database where migration 032 had already run. |

The live Supabase REST endpoint was verified to return HTTP 200 for public reads and HTTP 201 for a valid insert. A hidden diagnostic row named `system-check` may be removed from Supabase Table Editor.

## Submission bugs fixed

1. Public response loading no longer waits for the Admin session check. Network calls have bounded timeouts and a retry state.
2. Direct REST submission was tested, then submission was returned to the same Supabase client proven to load Admin history correctly.
3. The misleading `(network)` fallback was replaced with the real Supabase error code/message.
4. Fixed the successful-insert animation crash: `event.currentTarget` becomes `null` after an asynchronous `await`, so the form reference is now captured before submission. Animation elements are also null-safe. This bug caused the database insert to succeed while the UI incorrectly reported failure.

## Git / deployment

| Commit | Detail |
|---|---|
| `09a0ac3` | Add customer survey and moderation |
| `8e22351` | Fix survey submission client |
| `d4dffbc` | Clarify survey moderation controls |
| `bb72105` | Fix survey success animation |

All commits were pushed to `origin/main`. Netlify must publish commit `bb72105` (or later); after deployment, use a hard refresh or incognito window to avoid the previous cached `survey.html`.

## Files Changed This Session

| File | Type of Change |
|---|---|
| `survey.html` | New customer Survey UI, animations, public response wall, Admin moderation, submission and loading fixes |
| `supabase/migrations/032_customer_survey.sql` | New survey table, RLS policies, privacy-oriented grants |
| `supabase/migrations/033_survey_optional_answers.sql` | Optional-answer schema upgrade with at-least-one-answer constraint |

---

---

# Customer Membership Card Page
**Session Date:** 2026-09-02
**Scope:** New public `membership.html` — phone-gated loyalty card, order history, loyalty ledger, and program rules

---

## Deliverables

| # | Deliverable | Files |
|---|---|---|
| 1 | Public membership page — phone gate, card, history, rules | `membership.html` |
| 2 | Card artwork template (sample data painted out) | `assets/membership-card.png` |
| 3 | Public lookup RPC — the only anon-reachable path to CRM data | `supabase/migrations/034_membership_lookup.sql` |

**⚠️ Migration 034 must be run manually in the Supabase SQL Editor before the page will work.**

---

## Task 1 — Reproducing the printed card

`Glongnom_Membership_Card.pdf` is a Canva export: a single flattened 1050x600 raster
image (3.5in x 2in at 300 dpi). There is no live text and no embedded font, so the
card could not simply be "read" into HTML.

Approach — **original artwork + live text overlay**:

1. Rendered the PDF page to a 1050x600 bitmap.
2. Painted out the five sample data fields, leaving the artwork untouched:
   - Left data block — rebuilt with a **Coons patch** interpolated from all four
     clean edges. A simple row-wise blend left a visible rectangle because the
     brown background is a radial vignette, not a linear gradient.
   - Badge text — refilled with flat `#FFCBD6`, on an inner rect kept clear of the
     rounded corners so the white ring is never clipped.
3. Saved as `assets/membership-card.png` (32 KB). The arched **Glongnom matcha**
   wordmark, the pink tier badge, and **membership ♥** are the original pixels.
4. Live values are drawn as an inline `<svg viewBox="0 0 1050 600">` layered over
   the image, at coordinates measured off the PDF, so text lands on the original
   baselines.

### Measured values (1050 x 600 space)

| Element | Value |
|---|---|
| Card background | `#47241D` with a subtle radial vignette |
| Cream text | `#FFEFE4` |
| Badge pink / ring | `#FFCBD6` / `#FFFFFF` |
| Badge box | x 585–960, y 225–413, corner radius ~44, 6px white ring |
| Data line baselines | y = 258, 330, 404 · left edge x = 61 · font-size 44 |
| Badge line baselines | y = 294, 372 · centred on x = 773 · font-size 48 |

### Fonts

The Canva font is proprietary and was flattened into the bitmap, so it cannot be
embedded. Closest free substitutes, loaded from Google Fonts:

| Role | Font | Matches |
|---|---|---|
| Data lines | `Italiana` | Thin art-nouveau serif, circular bowls, high contrast |
| Badge lines | `Roboto Slab 700` + grey `paint-order: stroke` | Bold outlined slab serif |
| Thai fallback | `Sarabun` | Italiana has no Thai glyphs |

`fitCardText()` shrinks any line that would overflow its slot (long names, large
point totals) and re-runs on `document.fonts.ready` for cold visits.

---

## Task 2 — Public data access (migration 034)

Migration 022 removed the permissive `using (true)` SELECT policies from `orders`
and `order_items`, and `customers` / `loyalty_ledger` only allow reads when
`auth.uid() IS NOT NULL`. An anon page therefore **cannot** query those tables —
by design.

`get_membership(p_phone text)` is a single narrow `SECURITY DEFINER` function
(same pattern as `create_order` from migration 021) returning one JSON payload:

| Key | Contents |
|---|---|
| `customer` | name, phone, member_since, tier, points |
| `summary` | total_orders, total_spent (both exclude cancelled orders) |
| `orders` | last 50 orders — order_no, date, status, total, items, points earned |
| `ledger` | last 50 loyalty ledger rows — delta, reason, note, order_no |

| Detail | Reason |
|---|---|
| Phone compared on digits only | Stored values may contain spaces or dashes |
| Validates `^0\d{9}$` server-side | Same rule as the ordering app |
| Orders matched on `customer_id` **OR** `customer_phone` | Orders placed before the Phase 3 `customer_id` fix have a null `customer_id` but still carry the phone snapshot |
| Two expression indexes on normalised phone | Keeps the lookup off a sequential scan |
| `REVOKE ALL` then `GRANT EXECUTE TO anon, authenticated` | Only the function is exposed, never the tables |

**Privacy trade-off (accepted, worth revisiting):** the phone number is the only
credential, so the endpoint is enumerable — anyone who knows a customer's number
can see that customer's name, points, and order history. Acceptable for a small
shop loyalty card. If that ever matters, gate it behind Supabase phone OTP and
switch the lookup to `auth.uid()`.

---

## Task 3 — Page layout

| Area | Contents |
|---|---|
| **Gate** | Phone input (10 digits), inline validation, friendly not-found state linking to `/` |
| **Card** | Artwork + live SVG text, "เปลี่ยนเบอร์โทร" to return to the gate |
| **Stat row** | ออร์เดอร์ทั้งหมด · ยอดใช้จ่ายรวม · คะแนนคงเหลือ |
| **Tier progress** | Progress bar to the next tier + baht estimate to reach it |
| **History panel** | Tabs — ประวัติการสั่งซื้อ (items, total, status, points earned) / ประวัติคะแนนสะสม (ledger) |
| **Rules sidebar** | Earning formula, tier ranges, per-tier perks, reward redemption, fine print |

- Sticky sidebar on desktop; stacks below the card under 980px.
- Perks and rewards carry a **ยังไม่สรุป** chip since they are not finalised.
- Rewards show live progress ("อีก 190 คะแนน" / "✓ แลกได้แล้ว") against the
  customer's actual balance.

### `RULES` config object

All loyalty copy and numbers live in one object at the top of the script — baht
per point, tier thresholds/colours/perks, and the reward list. Editing that object
updates the sidebar, the tier table, the progress bar, and the reward list together.

**⚠️ Tier thresholds are duplicated in `accrue_loyalty_for_order()` (migrations 006
and 009), which is what actually writes `customers.tier`. Change both together.**

---

## Behaviour notes

| Behaviour | Detail |
|---|---|
| Phone remembered | Reuses the existing `glongnom_phone` localStorage key set by `index.html` |
| Prefill vs auto-open | A saved number is prefilled but never auto-opened (shared devices). Only an explicit `?phone=0XXXXXXXXX` link opens the card directly |
| Card date format | English CE, `16 Aug. 2026` — matches the printed sample exactly |
| History dates | Thai locale, to match the rest of the page |

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `membership.html` | New public membership card page |
| `assets/membership-card.png` | New — card artwork with sample data removed |
| `supabase/migrations/034_membership_lookup.sql` | New — `get_membership()` RPC + normalised-phone indexes |

---

## Revision — Layout + Tier Rule Change

### Page adjustments (`membership.html`)

| # | Change | Detail |
|---|---|---|
| 1 | Header removed | The sticky topbar is gone; the card now sits near the top with `padding-top: clamp(20px, 4.5vh, 44px)` on `.wrap` |
| 2 | Points tile removed | The balance is already on the card itself |
| 3 | Compact stat strip | ออร์เดอร์ทั้งหมด / ยอดใช้จ่ายรวม / เป้าหมายถัดไป — three tiles in **one row at every width**, divider borders instead of separate cards, with a 6px progress bar underneath. Replaced the old stat row + separate progress panel (~180px tall) with a single ~110px panel |
| 4 | History collapsed | Tabs replaced with two native `<details>` accordions (ประวัติการสั่งซื้อ, ประวัติคะแนนสะสม), both closed by default, each showing a row count in the summary |
| 5 | Tier + perks merged | One sidebar card, one row per tier: identity + baht range on the left, perks on the right, split by a dashed border |
| 6 | Tier by spend | See below |
| 7 | Card float | `cardFloat` — 6s ease-in-out, ±9px translateY with a 0.22° rotate. The reduced-motion block now also sets `animation-iteration-count: 1` |

Stat tiles and tier ranges use a no-decimal baht format so they fit the narrow
mobile columns; order totals keep two decimals.

### Tier now follows lifetime spend (migration 035)

Points are a **currency** — redeeming a reward deducts them — so they cannot
also represent status, or a Gold member who cashes in 500 points gets silently
demoted. Tier now follows lifetime spend, which only ever grows.

| Tier | Old (points) | New (lifetime spend) |
|---|---|---|
| Bronze | 0 – 299 pts | ฿0 – ฿1,499 |
| Silver | 300 – 999 pts | ฿1,500 – ฿2,999 |
| Gold | 1,000+ pts | ฿3,000+ |

This had to change at the source, not just in the display, or the customer's
card and the admin CRM would disagree. Migration `035_tier_by_spend.sql`:

| Step | Change |
|---|---|
| 1 | `customers.lifetime_spend numeric(12,2)` added |
| 2 | `tier_for_spend(numeric)` — the one place the baht thresholds live |
| 3 | `recalc_customer_tier(uuid)` — sums non-cancelled orders (by `customer_id` **or** phone snapshot) and writes `lifetime_spend` + `tier` |
| 4 | `accrue_loyalty_for_order` — points logic unchanged; tier recalc moved **outside** the idempotency guard so repeat calls and sub-฿10 orders still refresh the tier |
| 5 | `adjust_loyalty_points` — **no longer touches tier**. This is the fix |
| 6 | Backfills every existing customer |
| 7 | `get_membership` replaced — returns `tier_for_spend(total_spent)` and adds `summary.lifetime_spend` |

`membership.html` also derives the tier client-side from the spend total it
displays, so the badge on the card can never disagree with the tile beside it.

### Knock-on fix (`admin/customers.html`)

The CRM tier badge reads `customers.tier`, so it follows the new rule
automatically — but its progress bar was hardcoded to the points thresholds.
Rewrote it against `totalSpent` with the ฿1,500 / ฿3,000 targets and added a
`fmtBaht()` helper. Left alone: the manual point-adjust tool, which is still
correct since points remain the reward currency.

### Run order

1. `034_membership_lookup.sql`
2. `035_tier_by_spend.sql`

Both are safe to re-run. Remember `assets/membership-card.png` must be included
in the Netlify drag-and-drop upload.

### Bug fix — rules list sentences fragmenting

`.rules-list li` was `display: flex`, which makes **every inline child its own
flex item**. A bullet containing `<b>` tags was therefore split into separate
boxes that wrapped independently:

    ♡ | คะแนน | ใช้แลกของรางวัล · | ระดับสมาชิก | วัดจากยอดใช้จ่ายสะสม...

Replaced the flex row with a hanging indent (`position: relative` +
`padding-left` on the `li`, absolutely positioned `::before` heart) so inline
tags stay in the text flow. The points-vs-tier bullet was also split into two
separate bullets, since it was two distinct rules in one sentence.

Other flex containers on the page (`.order-top`, `.ledger-row`, `.rules-title`,
`.tp-name`, `.reward-row`, `.acc > summary`) are label/value layout rows whose
children are single runs by design — checked, none affected.

---

---

# Pre-order System
**Session Date:** 2026-09-25
**Scope:** Per-menu pre-order capability, closed-shop ordering for pre-order items, admin pre-order queue

---

## Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Schema — `menus.is_preorder` + `orders.is_preorder` columns | `supabase/migrations/037_preorder.sql` |
| 2 | `create_order` rewrite — pre-order-aware shop-closed guard + order flag | `supabase/migrations/037_preorder.sql` |
| 3 | Pre-order toggle column (beside Status) + Add/Edit modal checkbox | `admin/index.html` |
| 4 | Pre-order badge on menu cards + closed-shop ordering for pre-order items | `index.html` |
| 5 | Branded pre-order confirm pop-up on add-to-cart | `index.html` |
| 6 | "Pre-order" order queue section (same card, no timer) | `admin/orders.html` |

---

## The Core Problem

Order creation is **server-authoritative** — the browser calls the `create_order`
RPC (migrations 021/027/030), which recomputes every price and, until now,
**rejected every order when the shop was closed** (`SHOP_CLOSED`). Feature 2
("pre-order works while closed") could not be done client-side alone; the RPC
had to learn the rule.

## Business Rule (confirmed with MM)

| Situation | Behaviour |
|---|---|
| Shop **open** | Everything as before. Any order containing ≥1 pre-order item is flagged `is_preorder = true` and shown in the Pre-order queue |
| Shop **closed** | Order accepted **only if EVERY item is a pre-order item** (`v_all_preorder`). A single normal item still raises `SHOP_CLOSED` |
| Mixed cart | If ANY item is pre-order → whole order is pre-order (one delivery can't be split) |

## Schema + RPC (migration `037_preorder.sql`)

| Change | Detail |
|---|---|
| `menus.is_preorder` | `boolean NOT NULL DEFAULT false` — item may be ordered ahead, stays orderable while closed |
| `orders.is_preorder` | `boolean NOT NULL DEFAULT false` — set to `v_any_preorder` in the finalize UPDATE |
| Guard **moved** | The `SHOP_CLOSED` check moved from step 1 to step 6b (after pricing pass 1), because acceptance now depends on cart composition. Raising there aborts the transaction, rolling back the shell + items already inserted |
| Flags | `v_all_preorder` (AND) and `v_any_preorder` (OR) accumulated per item in pass 1 from `COALESCE(is_preorder, false)` |

Supersedes migration 030's `create_order`. Additive and safe to run.

## Customer App (`index.html`)

| # | Change |
|---|---|
| 1 | `MENU` mapping carries `preorder: !!item.is_preorder` |
| 2 | `🗓 Pre-order` badge top-left of card (drops below the sale ribbon when both apply); amber card border `.is-preorder` |
| 3 | Add button stays enabled when closed for pre-order items: `isSoldOut \|\| (!SHOP_OPEN && !item.preorder)` |
| 4 | `openModal` opens pre-order items even while closed |
| 5 | Branded confirm pop-up (`#preorderModal`) before a pre-order item enters the cart; `confirmAddToCart(preorderConfirmed)` gate |
| 6 | Cart line shows a small "Pre-order" tag; `cartAllPreorder()` helper mirrors the server rule |
| 7 | `submitOrder` allows checkout while closed only when `cartAllPreorder()`; load no longer force-disables the submit button |

## Admin Order Queue (`admin/orders.html`)

| # | Change |
|---|---|
| 1 | New full-width "Pre-order" section below the live columns; hidden when empty |
| 2 | `renderAll` splits `orders` into `is_preorder` vs active; live columns render active only |
| 3 | `renderCard(order, opts)` — `opts.hideTimer` omits the live timer, `opts.preorder` swaps the age badge for a "Pre-order" badge |

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `037_preorder.sql` | Pre-order columns + pre-order-aware `create_order` |

## Deploy

1. Supabase → SQL Editor → run `037_preorder.sql` (**first** — pages show no pre-order behaviour until the column exists).
2. Netlify drag-and-drop: `index.html`, `admin/index.html`, `admin/orders.html`.

## Verification Note

Full end-to-end could not be run this session — the behaviour only activates once
migration 037 is applied to the live Supabase (a manual production step). All three
files' inline JS passed a `node --check` syntax pass; the SQL control flow was
traced by hand.

---

# Customer Page Redesign — "Matcha Lab" (2026-10-21 / 2026-10-22)

**Scope:** Make `index.html` (customer ordering page) professional, aesthetic and "wow" without slowing the order flow. Most customers are on **iOS**, so effects were picked for Safari. Everything stays a single vanilla-JS file; `create_order` still re-prices server-side.
**Status:** All phases tested by MM on a real iPhone (local server `python -m http.server 8000`, `http://<PC-IP>:8000/`). **NOT deployed yet.**

## Earlier on 2026-10-21 — Layout redesign (LINE MAN style)

| # | Change |
|---|---|
| 1 | Option modal → bottom sheet: one choice per row (radio = required, checkbox = optional), sticky footer with qty stepper + "เพิ่มลงตะกร้า · ฿total" |
| 2 | Cream page, sticky scrolling category tabs, 2 equal columns on phones, full-width add button |
| 3 | Cart: `renderCartInto()` for desktop panel + mobile sheet, thumbnails, −/+ stepper, free-delivery progress; full-width bottom cart bar |
| 4 | Checkout: form first, summary last, fee chip under dorm, submit pinned with total |
| 5 | Cart persisted in localStorage (`glongnom_cart`, 3 h TTL, rebuilt from live MENU); green LINE pay button on the confirmation screen |

## Phase 1 — Motion foundation (no DB)

| # | Change |
|---|---|
| 1 | Motion tokens in `:root` (`--ease-out/-sheet/-pop/-pour`, `--dur-tap` 120 ms, `--dur-sheet` 280 ms); animate transform/opacity only |
| 2 | `@media (prefers-reduced-motion)` block — iPhone "Reduce Motion" users get no animation |
| 3 | Skeleton cards on first load + staggered card reveal (`renderSkeleton`, `revealMenu`); loading overlay now only used for order submit |
| 4 | Frosted-glass cart bar (`-webkit-backdrop-filter`) |
| 5 | Fly-to-cart: the glass (or photo) flies into the cart count and bumps it (`captureFlySource`, `flyToCart`) |
| 6 | Price count-up for the sheet price and cart total (`countUp`) |
| — | Haptics skipped: `navigator.vibrate` is unsupported on iOS |

## Phase 2 — Live matcha glass (semi-realistic SVG, "style B")

| # | Change |
|---|---|
| 1 | Migration **`038_visual_key.sql`** — `visual_key text` on `menus` (recipe tokens: `matcha`, body `milk/water/coconut/earlgrey/taro`, sauce `strawberry/blueberry/caramel/honey/biscoff/oreo`) and on `option_template_choices` (`grade_original/yame`, `milk_oat/cow`, `sweet_0..150`, `ice_in/side/none`, `matcha_in/side`, `top_konjac`). Backfills NULL rows only. **Applied by MM.** |
| 2 | Admin pickers: recipe preset in `admin/index.html` menu form, choice key in `admin/options.html` — both only sent when the column exists |
| 3 | Menu fetch falls back without `visual_key` on Postgres `42703` (works before the migration) |
| 4 | Glass stage at the top of the option sheet on a dark "display case" background; layers pour/drift as options change (`glassSVG`, `applyGlass`, `updateGlass`) |
| 5 | Separation rules (MM): แยกน้ำแข็ง + แยกมัทฉะ → ice in glass, layered liquid in a zip bag, matcha in a small cup; แยกน้ำแข็ง + เทมัทฉะ → ice in glass, one matcha-coloured liquid in the bag |
| 6 | Honey Matcha: water layer is clear (`GLASS_WATER_CLEAR`, 45 % opacity) because the drink is layered; Pure Matcha stays green |

## Hero — MM's own artwork

| # | Change |
|---|---|
| 1 | A dark/gold/neon hero was built, then rejected by MM; three light options were mocked up, then MM supplied their own art |
| 2 | Hero = `assets/hero-main.jpg` (1290×800, aspect-ratio box, max-width 480 px on desktop) + only the open/closed status on the blue note card + a small TH/EN toggle. No name, tagline, chips, glass or pre-order button (MM's choice) |
| 3 | Status text (font **Mali**) centred in the blue card (x 11.2–48.4 %, y 39.4–69.4 %), sizes in `cqw` so it scales with the image; message clamped to 2 lines — keep `close_message` short |
| 4 | Page background: `assets/bg-paper.jpg` (600×600 tile). Images re-compressed: hero 657→95 KB, paper 284→28 KB |

## Phase 3 — Faster repeat orders (no DB)

| # | Change |
|---|---|
| 1 | **Order again** card above the menu ("↻ สั่งเหมือนครั้งก่อน"): last successful order saved as ids only (`glongnom_last_order`), rebuilt from the live menu via `rebuildCartItem` (sold-out/changed items dropped, current prices); hidden while closed unless all pre-order; "All" tab only |
| 2 | **Saved-customer checkout**: when name/phone/dorm/detail are all valid, one "จัดส่งให้" card replaces the form, with "แก้ไข"; any validation error re-opens the form |
| — | Built then **removed** at MM's request: remembered option choices (order-again covers it) and the success-ritual glass on the confirmation screen (🎉 kept) |

## Delivery location picker

| # | Change |
|---|---|
| 1 | Native `<select>` (45 zones, iOS wheel) → button "📍 name · fee ›" that opens a bottom sheet; value kept in hidden `#customerDorm` so submit/validation are unchanged |
| 2 | One flat list sorted by fee (cheap → expensive), then A–Z then ก–ฮ (`Intl.Collator(['en','th'], {numeric:true})`); fee pill on the right of every row (free = green "ฟรี", then 3 tints by fee rank) |
| 3 | Search with Thai/English aliases (`DORM_ALIASES`: ดีคอนโด, เคฟ, มธ, …); "not found" state with "ดูทั้งหมด" |
| 4 | Mock-up: https://claude.ai/artifact/GdBrTeASxH7p5c9D62qcKm (MM then asked for no recent row, no fee groups, no brand grouping) |

## iOS fixes

| # | Change |
|---|---|
| 1 | Safari auto-zoom on focus: inputs/selects/textareas are 16 px on iOS only (`@supports (-webkit-touch-callout: none)`); desktop/Android keep 0.88 rem |

## Temporary test button - removed 2026-10-22

The `?test=1` simulate-order button was deleted from `index.html` before deploy.

## Backups (restore = copy over `index.html`)

| File | State |
|---|---|
| `backups/index_2026-10-21_pre-phase1.html` | Before Phase 1 |
| `backups/index_2026-10-21_pre-hero.html` | Before the first hero redesign |
| `backups/index_2026-10-22_pre-image-hero.html` | Before MM's image hero |
| `backups/index_2026-10-22_pre-phase3.html` | Before Phase 3 |
| `backups/index_2026-10-22_pre-phase3-fixes.html` | Before removing prefs/ritual, honey/zoom fixes |
| `backups/index_2026-10-22_pre-dorm-picker.html` | Before the delivery picker |
| `backups/index_2026-10-22_pre-deploy-halloween.html` | Halloween skin, still with the test button |

## Halloween skin (2026-10-22)

- Switch in `index.html` `<head>`: `SHOP_SKIN = 'auto'` (Halloween 20 Oct – 1 Nov) / `'halloween'` / `'normal'`. `?theme=halloween|normal` overrides for testing. Sets `<html data-skin="halloween">` before first paint.
- `themes/halloween.css`: every rule scoped to `[data-skin="halloween"]`. Navy BG, Halloween hero, status text in the white box (Creepster; Thai falls back to Sriracha), orange add/cart/submit buttons, cards unchanged.
- `themes/halloween.js`: exits at once in the normal skin. Hero bats, slanted ticker, ghost/spider/cobweb on menu cards, spider drops on the cart bar when the count rises, ghosts float up on the confirmation screen, tap sparks. Watches the DOM only; no order/price logic touched. Reduce Motion turns the moving parts off.
- Images: `assets/hero-halloween.jpg` (198 KB) and `assets/bg-halloween.jpg` (22 KB), compressed from MM's originals.
- Turn it off: set `SHOP_SKIN = 'normal'` and redeploy `index.html`.
- MM tested every part on a real iPhone over the LAN server (2026-10-22): all OK.

## Deploy (prepared 2026-10-22)

Clean deploy folder: `C:/Users/Teekatat/Glongnom-deploy-2026-10-22` (6.3 MB). Contains the site pages, `admin/`, `css/`, `js/`, `themes/`, `assets/` (without the unused `Glongnom_*` originals), `netlify/functions/` and `netlify.toml`. Left out on purpose: `backups/`, `supabase/`, `.git`, `.claude`, `.env.example`, `*.md`, CSV/PDF.

1. Test button removed; inline JS and `themes/halloween.js` pass `node --check`; every key file served 200 from the deploy folder.
2. Migrations: nothing new to run (latest is 038, already applied).
3. Netlify -> Deploys -> drag the **whole** deploy folder in.
4. Check on iPhone in a private tab: Halloween hero, open/closed text in the white box, place one real order end to end.
5. After 1 Nov the skin turns off by itself (`SHOP_SKIN = 'auto'`).

## Open ideas (Phase 4 — not started)

Card → sheet morph (View Transitions), Prompt font for headings, bento strip (order again / today's promo / cups to free delivery), time-based dark mode.

## Verification

Every change: inline JS `node --check` + headless-Chrome screenshots at 390 px; MM confirmed each phase on a real iPhone. No real order was placed during testing.
