StockFlow — Inventory Management System
Take-Home Assessment Submission

Author: Your Name
Date: YYYY-MM-DD

Overview

This repository contains my complete solution for the StockFlow B2B SaaS Inventory Management System case-study assessment.
It includes:

Part 1: Code Review, Bug Fixes & Improved API Endpoint

Part 2: Database Schema, Design Decisions & Gaps

Part 3: Low-Stock Alerts API Implementation

Assumptions, Tradeoffs & Reasoning

This assessment demonstrates backend development skills, debugging ability, database design proficiency, and handling real-world SaaS constraints.

Part 1 — Code Review & Debugging
Issues Identified

The original POST /api/products implementation included multiple issues:

Incorrect business logic (product tied to one warehouse)

No SKU uniqueness validation

No atomic transaction (multiple commits)

Missing input validation

Incorrect handling of money/decimal values

Duplicate inventory creation possible

No structured error responses

Race conditions and partial data writes

Fixes Implemented

Added complete request validation

Ensured atomicity using a single transaction

Removed warehouse dependency from Product

Enforced SKU uniqueness

Added Decimal parsing for price

Added inventory upsert handling

Proper HTTP status codes (400, 409, 500, 201)

Added comprehensive error logging and handling

Corrected endpoint is provided in /src/api/products.py.

Part 2 — Database Schema Design
Entities Designed

Key tables include:

companies

warehouses

products

inventory

inventory_movements

suppliers

supplier_products

sales & sale_items

product_thresholds & warehouse_product_thresholds

bundle_components

Design Principles

Products are defined at company-level; not tied to a single warehouse

Inventory is separated per (product, warehouse)

SKU uniqueness enforced through DB constraint

Auditing enabled through inventory_movements

Bundling supported via a composition table

Thresholds customizable per product and warehouse

Strategic indexes ensured efficient querying

Missing Requirements / Questions

To clarify with stakeholders:

Should SKU be globally unique or unique per company?

Should selling a bundle reduce the inventory of its components?

Should initial product quantity require purchase order creation?

Exact definition of recent sales (time window, order status)

Are suppliers shared globally or scoped to companies?

Should inventory support negative values (backorders)?

Expected data volume for indexing and partitioning decisions

Schema DDL is available under /database/schema.sql.

Part 3 — Low-Stock Alerts API
Endpoint
GET /api/companies/{company_id}/alerts/low-stock

Logic Implemented

Finds products with recent sales activity (default window: last 30 days)

Evaluates inventory for all warehouses under the company

Determines threshold using the following order:

warehouse-level threshold

product-level threshold

product-type default threshold

Estimates days until stockout

Retrieves supplier details (lowest lead-time preferred)

Produces alerts for all product-warehouse pairs falling below threshold

Example Response
{
  "alerts": [
    {
      "product_id": 123,
      "product_name": "Widget A",
      "sku": "WID-001",
      "warehouse_id": 456,
      "warehouse_name": "Main Warehouse",
      "current_stock": 5,
      "threshold": 20,
      "days_until_stockout": 12,
      "supplier": {
        "id": 789,
        "name": "Supplier Corp",
        "contact_email": "orders@supplier.com"
      }
    }
  ],
  "total_alerts": 1
}


Full implementation provided in /src/api/alerts.py.

Assumptions

SKU is globally unique (can be changed to per-company)

Recent sales window = 30 days

Prices use NUMERIC(18,4)

company_id determines tenant context

Missing supplier info returns null

No automatic inventory deduction for bundles

Average daily sales used to estimate stock-out prediction

Testing Strategy (Suggested)

Unit tests for:

Product creation

SKU uniqueness handling

Inventory upsert

Threshold resolution

Sales activity filtering

Integration tests for:

Transaction rollback scenarios

Supplier selection

Stockout prediction calculations

Project Structure
/
├── README.md
├── database/
│   └── schema.sql
├── src/
│   ├── api/
│   │   ├── products.py
│   │   └── alerts.py
│   ├── models/
│   │   ├── product.py
│   │   ├── inventory.py
│   │   ├── supplier.py
│   │   └── ...
│   └── utils/
│       └── price.py

Time Allocation
Part	Time Spent
Part 1 – Debugging	~30 mins
Part 2 – Database Design	~25 mins
Part 3 – API Implementation	~35 mins
Total	~90 mins
