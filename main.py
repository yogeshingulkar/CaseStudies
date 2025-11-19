
# Assumptions for this snippet:
# - Flask app and SQLAlchemy (db) are already configured.
# - Models: Product, Inventory exist.
# - Product has columns: id, company_id, name, sku (unique per company/global), price (Numeric/DECIMAL)
# - Inventory has unique constraint on (product_id, warehouse_id)
# - We use SQLAlchemy 1.x/2.x session/transaction pattern.

from decimal import Decimal, InvalidOperation
from flask import request, jsonify
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select
from contextlib import contextmanager

# helper: validate and parse decimal price
def parse_price(value):
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise ValueError("price must be a decimal-compatible number")

@app.route('/api/products', methods=['POST'])
def create_product():
    data = request.get_json(force=True)
    # Required fields
    name = data.get('name')
    sku = data.get('sku')
    price_raw = data.get('price')
    company_id = data.get('company_id')  # must be provided in multi-tenant system
    warehouse_id = data.get('warehouse_id')   # optional: if initial inventory is provided
    initial_quantity = data.get('initial_quantity')

    # Basic validation
    if not name or not sku or price_raw is None or company_id is None:
        return jsonify({"error": "missing required fields: name, sku, price, company_id"}), 400

    try:
        price = parse_price(price_raw)
        if price < 0:
            return jsonify({"error": "price must be >= 0"}), 400
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    if initial_quantity is not None:
        try:
            initial_quantity = int(initial_quantity)
            if initial_quantity < 0:
                return jsonify({"error": "initial_quantity must be >= 0"}), 400
        except (TypeError, ValueError):
            return jsonify({"error": "initial_quantity must be an integer"}), 400

    # Atomic transaction for product + (optional) inventory creation
    try:
        with db.session.begin_nested():  # start subtransaction
            # Check if SKU already exists (global). The DB should also enforce unique constraint.
            existing = db.session.execute(
                select(Product).where(Product.sku == sku)
            ).scalar_one_or_none()
            if existing:
                return jsonify({"error": "SKU already exists", "product_id": existing.id}), 409

            product = Product(
                name=name,
                sku=sku,
                price=price,
                company_id=company_id
            )
            db.session.add(product)
            db.session.flush()  # get product.id without committing

            # If initial inventory provided, upsert inventory for (product, warehouse)
            if warehouse_id is not None and initial_quantity is not None:
                # Ensure inventory uniqueness by checking existing record
                inv = db.session.execute(
                    select(Inventory).where(
                        Inventory.product_id == product.id,
                        Inventory.warehouse_id == warehouse_id
                    )
                ).scalar_one_or_none()
                if inv:
                    # If exists, set quantity (business decision: set vs add; here we set initial)
                    inv.quantity = initial_quantity
                else:
                    inv = Inventory(
                        product_id=product.id,
                        warehouse_id=warehouse_id,
                        quantity=initial_quantity
                    )
                    db.session.add(inv)

        db.session.commit()
    except IntegrityError as e:
        db.session.rollback()
        # Common case: unique constraint violation on SKU or inventory unique index
        return jsonify({"error": "database integrity error", "detail": str(e.orig)}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "internal server error", "detail": str(e)}), 500

    return jsonify({"message": "Product created", "product_id": product.id}), 201
