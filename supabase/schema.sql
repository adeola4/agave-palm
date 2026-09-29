-- ============================================================
-- Palm & Agave Nursery — Supabase PostgreSQL Schema
-- Target: Supabase project (PostgreSQL 15+)
-- Run via Supabase SQL Editor or `psql -f schema.sql`
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for product search

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE product_family AS ENUM ('agave', 'palm');
CREATE TYPE product_status AS ENUM ('draft', 'active', 'archived', 'sold_out');
CREATE TYPE inventory_status AS ENUM ('available', 'reserved', 'sold', 'damaged', 'unavailable');
CREATE TYPE variant_type AS ENUM ('container_size', 'specimen_grade', 'height_class');
CREATE TYPE fulfillment_type AS ENUM ('pickup', 'local_delivery', 'regional_delivery', 'freight', 'quote_required');
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
CREATE TYPE user_role AS ENUM ('customer', 'trade', 'admin');

-- ============================================================
-- BUSINESS CONFIG
-- ============================================================

CREATE TABLE business_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- USERS / AUTH (extends Supabase auth.users)
-- ============================================================

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  phone TEXT,
  role user_role DEFAULT 'customer',
  company TEXT,
  trade_approved BOOLEAN DEFAULT FALSE,
  trade_price_override NUMERIC(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX profiles_role_idx ON profiles(role);
CREATE INDEX profiles_trade_approved_idx ON profiles(trade_approved) WHERE role = 'trade';

-- ============================================================
-- DELIVERY ZONES
-- ============================================================

CREATE TABLE delivery_zones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  county TEXT,
  city TEXT,
  zip_codes TEXT[], -- array of ZIP codes
  delivery_type fulfillment_type NOT NULL,
  base_rate NUMERIC(10,2) NOT NULL,
  per_mile_rate NUMERIC(10,2) DEFAULT 0,
  min_order NUMERIC(10,2) DEFAULT 0,
  max_order NUMERIC(10,2), -- null = no max
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX delivery_zones_county_idx ON delivery_zones(county);

-- ============================================================
-- PRODUCTS
-- ============================================================

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sku TEXT UNIQUE NOT NULL,
  family product_family NOT NULL,
  botanical_name TEXT NOT NULL,
  common_name TEXT,
  cultivar TEXT,
  category TEXT,
  subcategory TEXT,
  description TEXT NOT NULL,
  short_description TEXT,
  sun_exposure TEXT,
  water_requirements TEXT,
  soil_drainage TEXT,
  cold_tolerance TEXT,
  growth_rate TEXT,
  landscape_applications TEXT,
  mature_height TEXT,
  mature_spread TEXT,
  planting_care TEXT,
  delivery_notes TEXT,
  seo_title TEXT,
  seo_description TEXT,
  seo_keywords TEXT,
  slug TEXT UNIQUE NOT NULL,
  featured BOOLEAN DEFAULT FALSE,
  status product_status DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agave-specific attributes
CREATE TABLE product_agave_attributes (
  product_id UUID PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  rosette_diameter TEXT,
  plant_height TEXT,
  leaf_shape TEXT,
  spine_characteristics TEXT,
  marginal_teeth TEXT,
  variegation TEXT,
  offsets_propagation TEXT,
  container_size_common TEXT
);

-- Palm-specific attributes
CREATE TABLE product_palm_attributes (
  product_id UUID PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  overall_height TEXT,
  clear_trunk_height TEXT,
  trunk_characteristics TEXT,
  crown_spread TEXT,
  field_grown BOOLEAN DEFAULT FALSE,
  growth_habit TEXT,
  planting_handling_considerations TEXT
);

CREATE INDEX products_family_idx ON products(family);
CREATE INDEX products_status_idx ON products(status);
CREATE INDEX products_slug_idx ON products(slug);
CREATE INDEX products_botanical_search ON products USING gin(botanical_name gin_trgm_ops);
CREATE INDEX products_common_search ON products USING gin(COALESCE(common_name, '') gin_trgm_ops);

-- ============================================================
-- PRODUCT VARIANTS
-- ============================================================

CREATE TABLE product_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  variant_type variant_type NOT NULL,
  value TEXT NOT NULL,
  sku TEXT UNIQUE NOT NULL,
  container_size TEXT,
  price NUMERIC(10,2) NOT NULL,
  trade_price NUMERIC(10,2),
  inventory_count INTEGER DEFAULT 0,
  low_stock_threshold INTEGER DEFAULT 3,
  delivery_type fulfillment_type DEFAULT 'quote_required',
  dimensions TEXT, -- JSON: height, width, weight, etc.
  is_available BOOLEAN DEFAULT TRUE,
  specimen_id UUID, -- links to specimen record if unique plant
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX product_variants_product_idx ON product_variants(product_id);
CREATE INDEX product_variants_sku_idx ON product_variants(sku);
CREATE INDEX product_variants_price_idx ON product_variants(price);

-- ============================================================
-- UNIQUE SPECIMENS (for large/single plants)
-- ============================================================

CREATE TABLE specimens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_variant_id UUID UNIQUE REFERENCES product_variants(id) ON DELETE CASCADE,
  specimen_label TEXT NOT NULL, -- e.g. "Specimens A-001"
  height NUMERIC(6,2), -- feet
  clear_trunk_height NUMERIC(6,2), -- feet (palms)
  crown_width NUMERIC(6,2), -- feet
  container_size TEXT,
  weight_estimate NUMERIC(8,2), -- lbs
  images TEXT[], -- array of image URLs/paths
  notes TEXT,
  status inventory_status DEFAULT 'available',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX specimens_status_idx ON specimens(status);

-- ============================================================
-- PRODUCT IMAGES
-- ============================================================

CREATE TABLE product_images (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  alt_text TEXT,
  sort_order INTEGER DEFAULT 0,
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX product_images_product_idx ON product_images(product_id);

-- ============================================================
-- RELATED PRODUCTS
-- ============================================================

CREATE TABLE related_products (
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  related_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sort_order INTEGER DEFAULT 0,
  PRIMARY KEY (product_id, related_product_id)
);

-- ============================================================
-- CART (server-side, stored in DB for logged-in users)
-- ============================================================

CREATE TABLE cart_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, variant_id)
);

CREATE INDEX cart_items_user_idx ON cart_items(user_id);

-- ============================================================
-- ORDERS
-- ============================================================

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number TEXT UNIQUE NOT NULL,
  user_id UUID NOT NULL REFERENCES profiles(id),
  status order_status DEFAULT 'pending',
  items JSONB NOT NULL, -- [{variant_id, name, sku, quantity, price, trade_price, dimensions}]
  subtotal NUMERIC(12,2) NOT NULL,
  delivery_cost NUMERIC(12,2) DEFAULT 0,
  tax NUMERIC(12,2) DEFAULT 0,
  total NUMERIC(12,2) NOT NULL,
  fulfillment_type fulfillment_type NOT NULL,
  delivery_zone_id UUID REFERENCES delivery_zones(id),
  shipping_address JSONB, -- {name, address, city, state, zip, phone}
  pickup_time TIMESTAMPTZ,
  payment_status TEXT DEFAULT 'pending', -- pending, paid, refunded
  payment_intent_id TEXT,
  square_order_id TEXT,
  notes TEXT,
  internal_notes TEXT,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX orders_user_idx ON orders(user_id);
CREATE INDEX orders_status_idx ON orders(status);
CREATE INDEX orders_order_number_idx ON orders(order_number);

-- ============================================================
-- ORDER STATUS HISTORY (audit trail)
-- ============================================================

CREATE TABLE order_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status order_status,
  to_status order_status NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX order_status_history_order_idx ON order_status_history(order_id);

-- ============================================================
-- WHOLESALE / TRADE ACCOUNTS & QUOTES
-- ============================================================

CREATE TABLE trade_inquiries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  inquiry_type TEXT NOT NULL, -- 'wholesale_account', 'bulk_order', 'project_quote'
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  project_specifications JSONB,
  requested_products JSONB, -- [{sku, quantity, notes}]
  delivery_address JSONB,
  budget_range TEXT,
  timeline TEXT,
  status TEXT DEFAULT 'new', -- new, contacted, quoted, closed, declined
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX trade_inquiries_status_idx ON trade_inquiries(status);

-- ============================================================
-- SEED DATA: Business config defaults
-- ============================================================

INSERT INTO business_config (key, value) VALUES
  ('site_settings', '{"businessName":"Palm & Agave Nursery","tagline":"Premium agaves and palm trees for Hillsborough County and the Tampa Bay region.","contactEmail":"orders@your-domain.com","contactPhone":"","address":"","serviceArea":"Hillsborough County, Florida — primary market. Regional delivery available to Pasco, Polk, Manatee, Pinellas, Hernando, and Sarasota counties upon request."}'),
  ('seo', '{"organizationName":"Palm & Agave Nursery","areaServed":"Hillsborough County, Florida","telephone":""}'),
  ('social', '{"instagram":"","facebook":"","pinterest":""}')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- SEED DATA: Delivery zones (Hillsborough County focus)
-- ============================================================

INSERT INTO delivery_zones (name, county, city, zip_codes, delivery_type, base_rate, per_mile_rate, min_order, notes) VALUES
  ('Hillsborough County — Local', 'Hillsborough', NULL, NULL, 'local_delivery', 75.00, 0, 200, 'Delivery within Hillsborough County. Flat rate for standard orders.'),
  ('Tampa Metro', 'Hillsborough', 'Tampa', ARRAY['33602','33603','33604','33605','33606','33607','33609','33610','33611','33612','33613','33614','33615','33616','33617','33619','33620','33621','33622','33623','33624','33625','33626','33627','33628','33629','33630','33631','33632','33633','33634','33635','33637','33639','33647','33649','33650','33654','33669'], 'local_delivery', 65.00, 0, 200, 'Tampa metro delivery.'),
  ('Pickup — Nursery', NULL, NULL, NULL, 'pickup', 0, 0, 0, 'Customer picks up at nursery. Appointment preferred for large specimens.'),
  ('Regional — Pasco County', 'Pasco', NULL, NULL, 'regional_delivery', 125.00, 0, 500, 'Pasco County delivery. Minimum order applies.'),
  ('Regional — Pinellas County', 'Pinellas', NULL, NULL, 'regional_delivery', 125.00, 0, 500, 'Pinellas County delivery. Minimum order applies.'),
  ('Quote Required', NULL, NULL, NULL, 'quote_required', 0, 0, 0, 'For large specimens, bulk orders, freight, and project deliveries. We will provide a custom quote.');

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Orders: auto-generate order_number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_number IS NULL THEN
    NEW.order_number := 'PALM' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(NEW.id::TEXT, 8, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_product_variants_updated_at
  BEFORE UPDATE ON product_variants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER generate_order_number_trigger
  BEFORE INSERT ON orders
  FOR EACH ROW EXECUTE FUNCTION generate_order_number();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_agave_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_palm_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE related_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_config ENABLE ROW LEVEL SECURITY;

-- Profiles: users see own profile; admins see all
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Products: public read for active products
CREATE POLICY "Public can view active products" ON products
  FOR SELECT USING (status = 'active' OR status = 'sold_out');
CREATE POLICY "Public can view active product attributes" ON product_agave_attributes
  FOR SELECT USING (EXISTS (SELECT 1 FROM products WHERE id = product_agave_attributes.product_id AND status = 'active'));
CREATE POLICY "Public can view active palm attributes" ON product_palm_attributes
  FOR SELECT USING (EXISTS (SELECT 1 FROM products WHERE id = product_palm_attributes.product_id AND status = 'active'));
CREATE POLICY "Public can view product images" ON product_images
  FOR SELECT USING (EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND status = 'active'));
CREATE POLICY "Public can view related products" ON related_products
  FOR SELECT USING (EXISTS (SELECT 1 FROM products WHERE id = related_products.product_id AND status = 'active'));

-- Product variants: public read for active products
CREATE POLICY "Public can view active variants" ON product_variants
  FOR SELECT USING (EXISTS (SELECT 1 FROM products WHERE id = product_variants.product_id AND status = 'active'));

-- Delivery zones: public read for active zones
CREATE POLICY "Public can view active delivery zones" ON delivery_zones
  FOR SELECT USING (is_active = TRUE);

-- Cart: users manage own cart
CREATE POLICY "Users manage own cart" ON cart_items
  FOR ALL USING (auth.uid() = user_id);

-- Orders: users see own orders; admins see all
CREATE POLICY "Users view own orders" ON orders
  FOR SELECT USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "Users create own orders" ON orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Trade inquiries: users manage own; admins see all
CREATE POLICY "Users manage own trade inquiries" ON trade_inquiries
  FOR ALL USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Business config: public read
CREATE POLICY "Public can view business config" ON business_config
  FOR SELECT USING (TRUE);

-- ============================================================
-- STORAGE BUCKETS (run once via Supabase dashboard or SQL)
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public) VALUES
--   ('product-images', 'product-images', true),
--   ('specimen-images', 'specimen-images', true);
