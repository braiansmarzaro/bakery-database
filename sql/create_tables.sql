-- =====================================================================
-- DATABASE CREATION SCRIPT FOR A BAKERY
-- Dialect: SQLite
-- Note: It is recommended to enable foreign key support when connecting.
-- In Python: conn.execute("PRAGMA foreign_keys = ON;")
-- =====================================================================

-- Block 1: Core entities without external dependencies.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS employees (
    employee_id INTEGER PRIMARY KEY,
    employee_name TEXT NOT NULL,
    cpf TEXT NOT NULL, -- Brazilian individual taxpayer registry ID
    position TEXT,
    hire_date TEXT NOT NULL,
    salary_cents INTEGER,
    CONSTRAINT uq_employees_cpf UNIQUE (cpf),
    CONSTRAINT ck_employees_salary CHECK (
        salary_cents IS NULL OR (typeof(salary_cents) = 'integer' AND salary_cents >= 0)
    )
);

CREATE TABLE IF NOT EXISTS customers (
    customer_id INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    cpf TEXT,
    phone TEXT,
    email TEXT,
    birth_date TEXT,
    CONSTRAINT uq_customers_cpf UNIQUE (cpf),
    CONSTRAINT uq_customers_email UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id INTEGER PRIMARY KEY,
    supplier_name TEXT NOT NULL,
    cnpj TEXT, -- Brazilian corporate taxpayer registry ID
    phone TEXT,
    email TEXT,
    address TEXT,
    CONSTRAINT uq_suppliers_cnpj UNIQUE (cnpj),
    CONSTRAINT uq_suppliers_email UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL,
    CONSTRAINT uq_categories_name UNIQUE (category_name)
);


-- Block 2: Tables that depend on Block 1.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS products (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    description TEXT,
    sale_price_cents INTEGER NOT NULL,
    unit_of_measure TEXT,
    category_id INTEGER,
    CONSTRAINT fk_products_categories FOREIGN KEY (category_id) REFERENCES categories(category_id),
    CONSTRAINT ck_products_sale_price CHECK (
        typeof(sale_price_cents) = 'integer' AND sale_price_cents >= 0
    )
);

CREATE TABLE IF NOT EXISTS ingredients (
    ingredient_id INTEGER PRIMARY KEY,
    ingredient_name TEXT NOT NULL,
    unit_of_measure TEXT,
    minimum_stock_quantity REAL NOT NULL DEFAULT 0,
    CONSTRAINT ck_ingredients_minimum_stock CHECK (minimum_stock_quantity >= 0)
);

CREATE TABLE IF NOT EXISTS ingredient_suppliers (
    ingredient_id INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    CONSTRAINT pk_ingredient_suppliers PRIMARY KEY (ingredient_id, supplier_id),
    CONSTRAINT fk_ingredient_suppliers_ingredients FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id) ON DELETE CASCADE,
    CONSTRAINT fk_ingredient_suppliers_suppliers FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS till_sessions (
    session_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    opening_timestamp TEXT NOT NULL,
    closing_timestamp TEXT,
    initial_balance_cents INTEGER NOT NULL,
    final_balance_cents INTEGER,
    CONSTRAINT fk_tillsessions_employees FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT ck_tillsessions_initial_balance CHECK (
        typeof(initial_balance_cents) = 'integer' AND initial_balance_cents >= 0
    ),
    CONSTRAINT ck_tillsessions_final_balance CHECK (
        final_balance_cents IS NULL OR (typeof(final_balance_cents) = 'integer' AND final_balance_cents >= 0)
    ),
    CONSTRAINT ck_tillsessions_closing CHECK (
        (closing_timestamp IS NULL AND final_balance_cents IS NULL)
        OR (closing_timestamp >= opening_timestamp AND final_balance_cents IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_tillsessions_open_employee
    ON till_sessions (employee_id)
    WHERE closing_timestamp IS NULL;


-- Block 3: Specialized stock tables (depend on Block 2).
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS product_stock (
    product_id INTEGER PRIMARY KEY,
    current_quantity REAL NOT NULL DEFAULT 0,
    minimum_quantity REAL DEFAULT 0,
    last_updated TEXT DEFAULT (CURRENT_TIMESTAMP),
    CONSTRAINT fk_stock_products FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_stock_current CHECK (current_quantity >= 0),
    CONSTRAINT ck_product_stock_minimum CHECK (minimum_quantity >= 0)
);

CREATE TABLE IF NOT EXISTS ingredient_batches (
    batch_id INTEGER PRIMARY KEY,
    ingredient_id INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    received_timestamp TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    expiration_date TEXT,
    received_quantity REAL NOT NULL,
    current_quantity REAL NOT NULL,
    CONSTRAINT fk_ingredient_batches_supplier FOREIGN KEY (ingredient_id, supplier_id) REFERENCES ingredient_suppliers(ingredient_id, supplier_id) ON DELETE RESTRICT,
    CONSTRAINT ck_ingredient_batches_received CHECK (received_quantity > 0),
    CONSTRAINT ck_ingredient_batches_current CHECK (
        current_quantity >= 0 AND current_quantity <= received_quantity
    ),
    CONSTRAINT ck_ingredient_batches_expiration CHECK (
        expiration_date IS NULL
        OR (
            date(expiration_date) IS NOT NULL
            AND date(expiration_date) = expiration_date
            AND expiration_date >= date(received_timestamp)
        )
    )
);

CREATE INDEX IF NOT EXISTS ix_ingredient_batches_expiration
    ON ingredient_batches (ingredient_id, expiration_date)
    WHERE current_quantity > 0;


-- Block 4: Relationship and transaction tables.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS recipes (
    product_id INTEGER,
    ingredient_id INTEGER,
    quantity REAL NOT NULL,
    CONSTRAINT pk_recipes PRIMARY KEY (product_id, ingredient_id),
    CONSTRAINT fk_recipes_products FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_recipes_ingredients FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    CONSTRAINT ck_recipes_quantity CHECK (quantity > 0)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    employee_id INTEGER NOT NULL,
    order_timestamp TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    order_status TEXT NOT NULL DEFAULT 'In Progress',
    CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_employees FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT ck_orders_status CHECK (order_status IN ('In Progress', 'Completed', 'Cancelled'))
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price_cents INTEGER NOT NULL,
    CONSTRAINT fk_orderitems_orders FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_orderitems_products FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    CONSTRAINT ck_orderitems_quantity CHECK (typeof(quantity) = 'integer' AND quantity > 0),
    CONSTRAINT ck_orderitems_unit_price CHECK (
        typeof(unit_price_cents) = 'integer' AND unit_price_cents >= 0
    )
);

CREATE TABLE IF NOT EXISTS sales (
    sale_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    sale_timestamp TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    payment_method TEXT,
    CONSTRAINT uq_sales_order UNIQUE (order_id),
    CONSTRAINT fk_sales_orders FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_sales_employees FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE VIEW IF NOT EXISTS order_totals AS
SELECT
    orders.order_id,
    COALESCE(SUM(order_items.quantity * order_items.unit_price_cents), 0) AS total_amount_cents
FROM orders
LEFT JOIN order_items ON order_items.order_id = orders.order_id
GROUP BY orders.order_id;

CREATE VIEW IF NOT EXISTS ingredient_stock AS
SELECT
    ingredients.ingredient_id,
    COALESCE(SUM(ingredient_batches.current_quantity), 0) AS current_quantity,
    ingredients.minimum_stock_quantity AS minimum_quantity,
    MIN(
        CASE
            WHEN ingredient_batches.current_quantity > 0 THEN ingredient_batches.expiration_date
        END
    ) AS next_expiration_date
FROM ingredients
LEFT JOIN ingredient_batches ON ingredient_batches.ingredient_id = ingredients.ingredient_id
GROUP BY ingredients.ingredient_id, ingredients.minimum_stock_quantity;

-- =====================================================================
-- End of Script
-- =====================================================================
