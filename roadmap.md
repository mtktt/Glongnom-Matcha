# Restaurant/Cafe POS System — Development Roadmap

## Project Goal

Build a scalable full-stack POS ecosystem for restaurant/cafe operations including:

* POS ordering
* Kitchen workflow
* Inventory management
* CRM
* Analytics
* Financial operations
* AI forecasting

---

## Tech Stack (Locked In)

| Layer | Tool |
|---|---|
| Database + Auth | Supabase (PostgreSQL) |
| Real-time (KDS) | Supabase Realtime subscriptions |
| File Storage | Supabase Storage (images, receipts, payment slips) |
| Frontend | Vanilla JS |
| Hosting | Vercel or Netlify |

> No separate backend server. All backend logic runs through Supabase client SDK and Supabase Edge Functions where needed.

---

# PHASE 1A — Core POS Loop

## Goal

Get a fully closed transaction working: customer orders → pays → shop sees it → can manage it.

Estimated Timeline: **6–8 Weeks**

---

## 1. Project Foundation

### Tasks

* Create Supabase project
* Connect frontend to Supabase client SDK
* Set up Vercel/Netlify hosting
* Git repository + environment configuration
* Define `.env` variables (Supabase URL, anon key)

### Deliverables

* Live project URL
* Supabase project connected
* Development and production environments working

---

## 2. Database Design

### Categories

```text
categories
- id (uuid, PK)
- name
- sort_order
- is_active
- created_at
```

### Shop Config

```text
shops
- id (uuid, PK)
- name
- branch_code
- address
- phone
- opening_hours (jsonb)
- is_open (boolean)
- tax_rate
- created_at
```

### Users / Auth

```text
users (extends Supabase auth.users)
- id (uuid, FK → auth.users)
- name
- role  — admin | manager | cashier | kitchen | staff
- shop_id
- is_active
- created_at
```

### Menu

```text
menus
- id (uuid, PK)
- category_id (FK → categories)
- name
- description
- base_price
- image_url
- is_active
- created_at
```

### Option Groups

```text
option_groups
- id (uuid, PK)
- menu_id (FK → menus)
- name          — e.g. "Sweetness", "Ice Level"
- is_required
- sort_order
```

### Option Choices

```text
option_choices
- id (uuid, PK)
- group_id (FK → option_groups)
- name          — e.g. "Low", "Medium", "High"
- additional_price
- sort_order
```

### Customers

```text
customers
- id (uuid, PK)
- name
- phone (unique)
- address
- line_user_id
- created_at
```

### Orders

```text
orders
- id (uuid, PK)
- order_no (sequential, human-readable)
- customer_id (FK → customers)
- order_type    — delivery | pickup | dine-in
- table_no
- status        — new | preparing | ready | served | cancelled
- payment_status — pending | paid | refunded
- payment_enabled (boolean, default false)
- subtotal
- delivery_fee
- total_price
- note
- created_at
- updated_at
```

### Order Items

```text
order_items
- id (uuid, PK)
- order_id (FK → orders)
- menu_id (FK → menus)
- qty
- unit_price
- note
- created_at
```

### Order Item Options

```text
order_item_options
- id (uuid, PK)
- order_item_id (FK → order_items)
- choice_id (FK → option_choices)
- choice_name (snapshot at order time)
- additional_price (snapshot at order time)
```

### Kitchen Queue

```text
kitchen_queue
- id (uuid, PK)
- order_id (FK → orders)
- order_item_id (FK → order_items)
- station
- status        — pending | preparing | ready
- started_at
- completed_at
```

---

## 3. Authentication System

### Features

* Login / Logout via Supabase Auth
* JWT token managed by Supabase SDK
* Password hashing handled by Supabase
* Session persistence
* Role-based access control (RBAC) via Row Level Security (RLS) policies

### Roles

* Admin
* Manager
* Cashier
* Kitchen
* Staff

### Security

* Supabase RLS policies enforce per-role data access at the database level
* Rate limiting via Supabase built-in
* Anon key exposed to frontend is safe — RLS prevents unauthorized access

---

## 4. Admin Panel UI

### Shop Management

* Edit shop info (name, address, phone, hours)
* Toggle shop open/closed
* Tax rate settings

### Menu Management

* Category CRUD
* Menu item CRUD
* Option group + option choice CRUD
* Upload menu photos → Supabase Storage
* Availability toggle (active/inactive per item)
* Drag-and-drop sort order

### Order Management View

* Live order queue (new + preparing)
* Action buttons per order: Start Preparing / Mark Ready / Cancel
* Order detail modal with full item + option breakdown
* Mark as Paid button (updates `payment_status`)

---

## 5. Customer Web Ordering App

### Features

* Port existing `index.html` to use Supabase instead of Google Apps Script
* Browse menu (served from Supabase)
* Add to cart, customize options
* Order summary + checkout
* Customer info form (name, phone, address)
* Submit order → saved to Supabase `orders` table
* Post-order confirmation with order number

### UI Requirements

* Mobile-first, responsive
* Fast loading
* PWA support (offline menu cache)
* Language toggle TH/EN (carry over from existing)

---

## 6. Payment — PromptPay QR (Built, Disabled)

> **Status: Built but disabled by default.**
> `payment_enabled = false` in the orders table and in shop config.
> The feature is complete and ready — flip the flag to activate when needed.

### What Gets Built

* PromptPay QR code generated at checkout using `promptpay-qr` JS library (no API key, no gateway)
* QR displayed after order confirmation
* Customer uploads payment slip image
* Slip saved to Supabase Storage, link stored in order record
* Shop owner manually confirms via Order Management View → "Mark as Paid"

### How to Enable

Set `payment_enabled = true` in the shop Config row in Supabase. The frontend reads this flag and conditionally shows the QR + slip upload UI.

---

# PHASE 1A Deliverables

* Supabase project live
* Auth with role-based access
* Admin panel (shop, menu, order management)
* Customer ordering app (Supabase-backed)
* PromptPay QR built and togglable (disabled by default)

---

# PHASE 1B — Kitchen & Hardware Layer

## Goal

Real-time kitchen operations and physical receipt output.

Estimated Timeline: **3–4 Weeks after Phase 1A**

---

## 1. Kitchen Display System (KDS)

### Features

* Live incoming orders via **Supabase Realtime** subscriptions
* Order cards with item list, options, customer note
* Cooking timer per order (starts when status → preparing)
* Status buttons: Preparing → Ready
* Order priority indicators
* Sound notification on new order

### Status Flow

```text
new → preparing → ready → served
```

### Technical

* Supabase Realtime — no WebSocket server needed, subscriptions built into SDK
* Dedicated `kitchen.html` page (separate from admin panel)
* Role: Kitchen users only (RLS enforced)

---

## 2. Receipt System

### Phase 1B (Browser PDF — shipped first)

* Print-to-PDF receipt via browser `window.print()` with print-specific CSS
* Customer receipt: order number, items, options, total, timestamp
* Kitchen receipt: items + options + notes only (no price)

### Stretch Goal (ESC/POS Printer)

* ESC/POS compatible thermal printer
* Requires a local print agent running on shop machine (bridge between browser and printer)
* Multi-station printer routing (kitchen vs cashier)
* Deferred until browser PDF is proven insufficient in operations

---

# PHASE 1B Deliverables

* KDS live with Supabase Realtime
* Browser PDF receipt for customer and kitchen
* ESC/POS printer (stretch goal)

---

# PHASE 2 — Inventory & Costing System

## Goal

Build inventory intelligence and food cost tracking.

Estimated Timeline: **6–10 Weeks**

---

## 1. Recipe / BOM System

### Database

```text
ingredients
- id
- name
- unit
- current_stock
- reorder_level
- cost_per_unit
- created_at
```

```text
recipe_bom
- id
- menu_id (FK → menus)
- ingredient_id (FK → ingredients)
- quantity_used
```

### Workflow

```text
Order completed:
  Matcha Latte sold
  → deduct matcha powder (5g)
  → deduct milk (200ml)
  → deduct syrup (10ml)
```

---

## 2. Inventory Deduction Engine

### Features

* Automatic stock deduction on order completion
* Stock validation (warn if stock insufficient before accepting order)
* Manual inventory adjustment with reason log
* Wastage logging

---

## 3. Unit Cost Calculation

### Features

* Ingredient cost tracking (cost per unit)
* Auto-calculate recipe total cost from BOM
* Gross margin per menu item
* Suggested selling price

### Formula

```text
Food Cost % = Ingredient Cost / Selling Price × 100
Suggested Price = Ingredient Cost / Target Food Cost %
```

---

## 4. Inventory Management

### Features

* Buy-in stock (add stock from supplier delivery)
* Supplier management
* Purchase order tracking
* Low stock alert (notify when stock ≤ reorder level)
* Expiry date tracking
* Batch tracking
* Physical stock count workflow

---

# PHASE 2 Deliverables

* BOM engine (auto-deduct on order)
* Food cost calculation per item
* Supplier + purchase order management
* Low stock alerts

---

# PHASE 3 — Operations & Business Intelligence

## Goal

Improve operational efficiency and customer retention.

Estimated Timeline: **6–8 Weeks**

---

## 1. Staff Management

### Features

* Staff profile management
* Shift scheduling
* Clock in / clock out
* Attendance records
* Sales performance per staff

---

## 2. CRM System

### Features

* Customer profile (built from order history)
* Full order history per customer
* Loyalty points system
* Membership tier (Bronze / Silver / Gold)
* Coupon / discount code system
* Birthday rewards

---

## 3. Reporting & Dashboard

### Sales Dashboard

* Daily / weekly / monthly revenue
* Hourly sales heatmap
* Best-selling items
* Average ticket size
* Revenue by order type (delivery / pickup / dine-in)

### Inventory Dashboard

* Food cost %
* Waste analysis
* Fast-moving vs slow-moving items
* Stock valuation

### Staff Dashboard

* Productivity metrics
* Sales by staff member

---

# PHASE 3 Deliverables

* Staff management module
* CRM with loyalty system
* Full business intelligence dashboards

---

# PHASE 4 — Enterprise & AI Layer

## Goal

Enterprise-grade intelligence and governance.

Estimated Timeline: **8–12 Weeks**

---

## 1. Accounting Integration

### Features

* Journal entries per transaction
* Tax summary report
* Expense tracking
* Invoice management

### Integrations

* Xero
* QuickBooks

---

## 2. Finance Module

### Features

* Profit & loss statement
* Cash flow tracking
* Budgeting
* Cost center allocation

---

## 3. AI Analytics & Forecasting

### Features

* Demand forecasting (predict sales by item per day/hour)
* Inventory prediction (auto suggest purchase quantities)
* Staff scheduling suggestion (based on forecast demand)
* Dynamic pricing suggestion
* Sales anomaly detection

### AI Models

* ARIMA — time series baseline
* Prophet — handles seasonality and holidays
* XGBoost — feature-rich tabular forecasting

> Note: AI models run as Python scripts or Supabase Edge Functions. Training data comes from the orders and inventory tables built in earlier phases.

---

## 4. Audit Log & Permission System

### Audit Logs

Track all sensitive actions:

* Login / logout
* Order edit or cancel
* Refund issued
* Price change
* Inventory adjustment
* Role change

### Permission Matrix

| Module | Admin | Manager | Cashier | Kitchen |
|---|---|---|---|---|
| Menu Management | YES | YES | NO | NO |
| Inventory | YES | YES | NO | NO |
| Refund | YES | YES | LIMITED | NO |
| Reports | YES | YES | LIMITED | NO |
| Audit Log | YES | NO | NO | NO |

---

# PHASE 4 Deliverables

* Finance and accounting module
* AI forecasting engine
* Full audit trail
* Enterprise permission control

---

# FUTURE WORK (Not in Current Roadmap)

* GPS delivery tracking
* Driver management app
* Self-order kiosk (tablet mode)
* Voice ordering AI
* Multi-country tax engine
* Franchise / multi-location management
* QR table ordering (dine-in scan-to-order)

---

# Development Priority Order

### Critical (Phase 1A)

1. Supabase setup + database schema
2. Authentication + roles
3. Admin panel (menu + order management)
4. Customer ordering app
5. PromptPay QR (built, disabled)

### Operational (Phase 1B)

6. Kitchen Display System (Supabase Realtime)
7. Receipt printing (PDF first, ESC/POS stretch)

### Important (Phase 2–3)

8. Inventory + BOM engine
9. Reporting dashboards
10. CRM + loyalty

### Advanced (Phase 4)

11. AI forecasting
12. Finance + accounting
13. Enterprise governance

---

# API Structure (Supabase-based)

All data access goes through Supabase client SDK with RLS policies.
Edge Functions used only where client SDK is insufficient (e.g. payment webhooks, scheduled jobs).

```text
Supabase Tables (direct client access, RLS enforced):
  /rest/v1/menus
  /rest/v1/orders
  /rest/v1/order_items
  /rest/v1/kitchen_queue
  /rest/v1/inventory
  /rest/v1/customers

Supabase Edge Functions (server-side logic):
  /functions/v1/create-order      — validate + atomic order creation
  /functions/v1/update-order-status
  /functions/v1/deduct-inventory  — BOM deduction on order complete
  /functions/v1/send-line-notify  — LINE push notification
```

---

# Final Goal

Build a scalable restaurant operating system that connects:

* customer ordering
* kitchen operation
* inventory
* finance
* analytics
* AI intelligence

into one unified platform — built on Supabase, deployed on Vercel, accessible from any device.

---

---

# COMMERCIALIZATION — Selling the POS as a Real Product
**Added:** 2026-06-13 (advisory notes for turning Glongnom POS into a sellable product)

## Core Shift: Single-tenant → Multi-tenant

Today the system is **single-tenant** (one system = one shop, Glongnom). To sell to real shops there are two models:

| Model | Meaning | Best for |
|---|---|---|
| A. Per-shop deployment | Copy the system per shop, separate DB | Selling a few shops, install/setup work |
| **B. Multi-tenant SaaS** ⭐ | One system, shops sign up and share it, isolated by `shop_id` | Selling at scale, recurring revenue |

**Foundation already exists:** every table has `shop_id` + RLS, which is exactly the basis for multi-tenant isolation. The architecture was built the right way from the start.

## Tools / Database Recommendations

### Database — stay on PostgreSQL / Supabase
- POS data is highly relational (order ↔ item ↔ option ↔ inventory ↔ accounting) → relational Postgres fits best. Avoid NoSQL (reporting/accounting becomes painful).
- Supabase = managed Postgres + Auth + Realtime + API. No vendor lock-in — can later move to Neon / AWS RDS since it's standard Postgres.

### Frontend — move to a framework (Next.js / React) eventually
- Current Vanilla JS duplicates sidebar/auth across 13 pages (review finding C3) — a long-term maintenance burden for a product.
- Next.js gives reusable components + built-in API routes (move logic server-side, matching the "don't trust the client" lesson from the create_order RPC work).
- **Do not rewrite prematurely** — migrate incrementally once there are real customers.

### Backend logic — shift server-side
- The `create_order` RPC pattern (server owns pricing/logic) is the correct direction. A commercial product should have a clear backend layer (Next.js API routes or Supabase Edge Functions), not logic floating in the browser.

### New pieces needed to "sell"
| Need | Recommended tool |
|---|---|
| 💳 Charge shops a monthly fee | Stripe (intl) / Omise, 2C2P (Thailand) |
| 📊 Error / uptime monitoring | Sentry (free tier) |
| 📧 System email (invite, reset) | Resend / Postmark |
| 🔔 Notifications | Telegram (already built) |

## Hosting vs Domain — what they are, are they necessary

- **Domain** = the web address (e.g. `glongnom-pos.com`). Rented yearly from a registrar (Cloudflare, Namecheap, or TH: Z.com, Hostatom), ~300–500 THB/year for `.com`. Currently using the free `glongnom-pos.netlify.app` subdomain.
  - *Necessary?* Works without it, but **buy one when selling for real** — professionalism, branding, trust, and you own it (can move hosts without changing the URL). Cheap insurance.
- **Hosting** = where the app lives so it's reachable 24/7. **Netlify already is the host** (free tier).
  - *Necessary?* **Yes, always** — the app must live somewhere. For a product, just upgrade the tier or move to a better fit (Vercel suits Next.js).

> Mnemonic: **Domain = the shop's signboard (address)** · **Hosting = the building the shop operates in (where things actually live).** The signboard is optional-ish; the building is mandatory.

## Cost Ladder (approximate, per month)

| Stage | Stack | Cost |
|---|---|---|
| Now (experimenting) | All free + Telegram | ~0 THB |
| Selling first 1–10 shops | Supabase Pro ($25) + domain (~35฿/mo) + Vercel free | ~1,000 THB/mo |
| Growing 50+ shops | Supabase Team + Vercel Pro + Stripe + Sentry | ~3,000–6,000 THB/mo |

> Pay for **Supabase Pro** first — no project pausing, more egress, backups.

## Recommended Go-to-Market Roadmap (no rush, stepwise)

1. **Now:** use Glongnom as the reference shop — make the system stable and feature-complete (in progress).
2. **Before selling:** add self-serve **shop signup** (signup → auto-create a new `shop_id`) = the step into true multi-tenancy.
3. **First 1–3 shops:** buy a domain + upgrade to Supabase Pro + add monthly subscription billing.
4. **When managing many shops gets hard:** consider the Next.js frontend rewrite for long-term sustainability.

## Summary

- **DB:** stay on Postgres/Supabase — fits POS and is already multi-tenant-ready.
- **Tools:** later move frontend to Next.js + add Stripe/Omise (billing), Sentry (monitoring).
- **Hosting:** necessary (already have Netlify) — just upgrade when selling.
- **Domain:** not required to function, but **should buy** when selling (a few hundred baht/year, worth it for credibility).
