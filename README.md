# Palm & Agave Nursery

Premium agave plants and palm trees for Hillsborough County and the Tampa Bay region.

## What this is

A premium Florida nursery website built with Astro, focused on two product families:

- **Agave plants** — architectural, compact, specimen, and landscape-ready agaves
- **Palm trees** — cold-hardy palms, specimen palms, field-grown palms, and bulk palm orders

Primary market: Hillsborough County, Florida (Tampa, Brandon, Riverview, Plant City, Valrico, Lutz, Wesley Chapel, and surrounding areas).

## Tech stack

- **Framework:** Astro (static + server rendering)
- **Hosting:** Vercel (intended deployment target)
- **Database & Auth:** Supabase (PostgreSQL, Auth, Storage)
- **Payments:** Square (sandbox for development; production credentials required)
- **Email:** Transactional email provider (configurable — Resend, SendGrid, etc.)

## Repository structure

```
palm-agate-nursery/
├── astro.config.mjs          # Astro configuration + sitemap
├── .env.example              # Environment variable template
├── public/                   # Static assets (favicon, etc.)
├── src/
│   ├── env.d.ts              # TypeScript env declarations
│   ├── styles/
│   │   └── tokens.css        # Design tokens (colors, typography, spacing)
│   ├── layouts/
│   │   └── Layout.astro      # Base layout (header slot, footer slot, SEO)
│   ├── components/
│   │   ├── Header.astro      # Sticky header + mobile menu
│   │   └── Footer.astro      # Footer with links and business info
│   ├── pages/
│   │   ├── index.astro       # Homepage
│   │   ├── cart.astro        # Shopping cart
│   │   ├── checkout.astro    # Checkout flow
│   │   ├── about.astro       # About page
│   │   ├── contact.astro     # Contact form
│   │   ├── shop/
│   │   │   ├── agaves/
│   │   │   │   ├── index.astro   # Agave catalog
│   │   │   │   └── [slug].astro  # Agave product detail
│   │   │   └── palms/
│   │   │       ├── index.astro   # Palm catalog
│   │   │       └── [slug].astro  # Palm product detail
│   │   ├── wholesale/
│   │   │   ├── index.astro       # Wholesale & trade overview
│   │   │   └── bulk-quote.astro  # Bulk quote request form
│   │   └── guides/
│       ├── index.astro           # Guides listing
│       ├── agave-care.astro      # Agave selection & care
│       ├── palm-care.astro       # Palm height, trunk, mature size
│       ├── hillsborough-plants.astro
│       ├── landscape-design.astro
│       ├── container-growing.astro
│       └── cold-tolerance.astro
├── supabase/
│   └── schema.sql            # Full Supabase PostgreSQL schema + RLS
└── package.json
```

## Getting started

### 1. Install dependencies

```bash
npm install
```

### 2. Configure environment

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

At minimum, you need:
- `PUBLIC_SITE_URL` — your deployed site URL
- `PUBLIC_BUSINESS_NAME` — business name shown in header/footer/SEO
- Supabase project URL and anon key
- Square sandbox credentials (for payment testing)

See `.env.example` for all available settings.

### 3. Set up Supabase

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL in `supabase/schema.sql` in the Supabase SQL Editor
3. Create the storage buckets: `product-images` and `specimen-images`
4. Copy your project URL and anon key into `.env`

### 4. Run locally

```bash
npm run dev
```

The site will be available at `http://localhost:4321`.

### 5. Build for production

```bash
npm run build
```

Then deploy the `dist/` folder to Vercel or your preferred hosting.

## Database

The full schema is in `supabase/schema.sql`. It includes:

- **Products** — shared fields plus agave-specific and palm-specific attribute tables
- **Product variants** — SKU, price, trade price, inventory, delivery type, dimensions
- **Specimens** — unique specimen records for large individual plants
- **Product images** — with primary image and sort order
- **Related products** — cross-references between products
- **Delivery zones** — configurable service areas and rates
- **Cart items** — server-side cart for logged-in users
- **Orders** — with status history, fulfillment, and payment tracking
- **Trade inquiries** — wholesale, bulk order, and project quote requests
- **Profiles** — extends Supabase auth.users with role, trade pricing, etc.
- **Business config** — site settings, SEO, social links
- **Row Level Security (RLS)** policies for all tables

## Environment variables

| Variable | Purpose |
|----------|---------|
| `PUBLIC_SITE_URL` | Deployed site URL for sitemap, OG, canonical URLs |
| `PUBLIC_BUSINESS_NAME` | Business name displayed site-wide |
| `PUBLIC_SUPABASE_URL` | Supabase project URL (public, safe for client) |
| `PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key (public, safe for client) |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side only. Never expose to frontend. |
| `PUBLIC_SUPABASE_BUCKET_PRODUCTS` | Storage bucket for product images |
| `PUBLIC_SUPABASE_BUCKET_SPECIMENS` | Storage bucket for specimen images |
| `SQUARE_APPLICATION_ID` | Square application ID (sandbox for dev) |
| `SQUARE_ACCESS_TOKEN` | Square access token (sandbox for dev) |
| `SQUARE_WEBHOOK_SIGNATURE_KEY` | For verifying Square webhooks |
| `EMAIL_PROVIDER` | Email provider name |
| `EMAIL_API_KEY` | Email API key |
| `EMAIL_FROM` | From address for order confirmations |

## What is built

### Pages

- **Homepage** — hero, product families, featured agaves, featured palms, landscape inspiration, buyer pathways, geographic focus, plant guides
- **Agave catalog** — category filters, search, price/sun/cold/size filters, sort, product grid
- **Palm catalog** — category filters, search, price/sun/cold/size filters, field-grown checkbox, sort, product grid
- **Agave product detail** — gallery, variants, specs, description, care, delivery, related products
- **Palm product detail** — gallery, variants, specs (overall height, clear trunk, trunk, crown), description, care, delivery, related products
- **Cart** — item list, quantity controls, fulfillment selector, order summary, promo code
- **Checkout** — contact, shipping, delivery zone selection, payment (Square-ready), order summary sidebar
- **Wholesale & trade** — supply overview, account tiers, how it works, trade account application, FAQ
- **Bulk quote** — detailed request form for bulk orders and project quotes
- **Guides** — listing page plus six full guides
- **About** — nursery overview, market, audience, quality approach
- **Contact** — contact details and form

### Design system

Design tokens in `src/styles/tokens.css`:

- **Palette:** Limestone `#F5F2E9`, Deep botanical green `#183D2C`, Forest green `#294F3B`, Sage `#B7C5A5`, Sand `#D8B989`, Charcoal `#262923`, White
- **Typography:** Playfair Display (serif headings), Inter/Manrope (sans body)
- **Spacing:** 8px base system
- **Responsive:** Mobile-first, breaking at 640px, 768px, 900px, 1024px

## What is not yet wired

The following require Supabase connection and/or business details before they function end-to-end:

- Product data (currently seeded with placeholder plants)
- Cart persistence (currently client-side only)
- Order creation and payment (Square sandbox required)
- User accounts and authentication
- Wholesale account approval workflow
- Transactional email
- Image uploads to Supabase Storage
- Admin dashboard
- Real-time inventory reservation and concurrency protection

## Business details required before launch

- Nursery business name (if different from the one in `.env`)
- Physical address or service area confirmation
- Contact email and phone
- Square sandbox and production credentials
- Supabase project URL and keys
- Verified delivery coverage and rates
- Any nursery licenses, permits, or certifications (if applicable)
- Real product images and horticultural data
- Policy content for privacy, terms, refunds, and delivery

## Development status

This is a functional development build with:

- Complete page structure for all required routes
- Working catalog pages with filters and search (frontend-side)
- Product detail pages with variant selection and specs
- Cart and checkout flows (frontend-side, no backend persistence yet)
- Wholesale, trade, and bulk quote pages
- Six plant guides with full content
- Complete Supabase schema ready to apply
- Design system and responsive layout
- SEO metadata on all pages
- Sitemap integration

What remains: connect Supabase, populate real product data, wire payments, add authentication, build the admin dashboard, and verify with real business credentials.

## Competitors referenced in research

- Tree Mart — https://treemart.com/
- Sunscape Landscape Nursery — https://www.sunscapelandscapenursery.com/
- Florida Palm and Plant Co. — https://floridapalmandplant.com/
- Carencia Native Nursery — http://www.carencianursery.com
- Palmco — https://palmco.com/
- Dino's Palms — https://dinospalms.com/shop-all/
- Palm City Tree Farm — https://palmcitytreefarm.com/
- Tampa Bay Wholesale Growers Association — https://www.tbwg.org/
- Florida Association of Native Nurseries — https://www.fann.org/

## License

Proprietary — for the business that commissioned this build.
