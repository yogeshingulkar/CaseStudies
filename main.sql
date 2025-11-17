-- Companies
CREATE TABLE companies (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Warehouses belonging to companies
CREATE TABLE warehouses (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (company_id, name)
);

-- Suppliers
CREATE TABLE suppliers (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_email TEXT,
  contact_phone TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Products
CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  sku TEXT NOT NULL,                -- SKU unique across platform or per company
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(18,4) NOT NULL DEFAULT 0,
  product_type TEXT DEFAULT 'standard', -- e.g., 'standard', 'bundle', 'service'
  is_bundle BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (sku) -- or UNIQUE (company_id, sku) if SKUs can repeat across companies
);

-- Bundle components (if product is a bundle)
CREATE TABLE bundle_components (
  bundle_product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  component_product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity INT NOT NULL DEFAULT 1,
  PRIMARY KEY (bundle_product_id, component_product_id)
);

-- Inventory: quantity of product in a warehouse
CREATE TABLE inventory (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  quantity BIGINT NOT NULL DEFAULT 0,
  reserved_quantity BIGINT NOT NULL DEFAULT 0, -- for pending orders
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (product_id, warehouse_id)
);

-- Inventory movements / audit (tracks when inventory levels change)
CREATE TABLE inventory_movements (
  id BIGSERIAL PRIMARY KEY,
  inventory_id BIGINT NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
  change BIGINT NOT NULL, -- positive for in, negative for out
  reason TEXT,            -- 'purchase', 'sale', 'adjustment', 'transfer', etc.
  related_id BIGINT,      -- optional FK to sale/order/purchase - depends on implementation
  created_by BIGINT,      -- user id
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Suppliers supply products (many-to-many)
CREATE TABLE supplier_products (
  supplier_id BIGINT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  supplier_sku TEXT,
  lead_time_days INT DEFAULT 7,
  price NUMERIC(18,4),
  PRIMARY KEY (supplier_id, product_id)
);

-- Sales (orders) and items, used to compute recent sales activity
CREATE TABLE sales (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id BIGINT,
  status TEXT NOT NULL, -- 'completed', 'pending', ...
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE sale_items (
  id BIGSERIAL PRIMARY KEY,
  sale_id BIGINT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  warehouse_id BIGINT, -- from which warehouse it shipped/was reserved
  quantity INT NOT NULL,
  unit_price NUMERIC(18,4) NOT NULL
);

-- Low-stock thresholds (per product; optional per warehouse override)
CREATE TABLE product_thresholds (
  product_id BIGINT PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  threshold INT NOT NULL DEFAULT 10,
  use_warehouse_override BOOLEAN DEFAULT FALSE
);

CREATE TABLE warehouse_product_thresholds (
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  threshold INT NOT NULL,
  PRIMARY KEY (product_id, warehouse_id)
);

-- Indexes for performance
CREATE INDEX idx_inventory_product ON inventory (product_id);
CREATE INDEX idx_inventory_warehouse ON inventory (warehouse_id);
CREATE INDEX idx_sale_items_product_createdat ON sale_items (product_id);
CREATE INDEX idx_sales_company_createdat ON sales (company_id, created_at);
