-- =====================================================================
-- SAMPLE DATA INSERTION SCRIPT FOR BAKERY DATABASE
-- Dialect: SQLite
-- =====================================================================

-- To ensure data integrity, especially on re-runs, it's good practice
-- to wrap insertions in a transaction and enable foreign keys.
-- PRAGMA foreign_keys = ON;
-- BEGIN TRANSACTION;

-- Block 1: Inserting data into core entities (no dependencies).
-- ---------------------------------------------------------------------

INSERT INTO employees (employee_id, employee_name, cpf, position, hire_date, salary_cents) VALUES
(1, 'Alice Smith', '111.111.111-11', 'Cashier', '2024-05-10', 220000),
(2, 'Robert Johnson', '222.222.222-22', 'Head Baker', '2023-08-15', 280000);

INSERT INTO customers (customer_id, customer_name, cpf, email, birth_date) VALUES
(1, 'John Doe', '333.333.333-33', 'john.doe@email.com', '1985-04-23'),
(2, 'Mary Jane', '444.444.444-44', 'mary.jane@email.com', '1992-11-12');

INSERT INTO suppliers (supplier_id, supplier_name, cnpj, email) VALUES
(1, 'Flour & Co.', '12.345.678/0001-99', 'contact@flourco.com'),
(2, 'Good Taste Dairy', '98.765.432/0001-11', 'sales@goodtastedairy.com');

INSERT INTO categories (category_id, category_name) VALUES
(1, 'Breads'),
(2, 'Cakes'),
(3, 'Savories'),
(4, 'Beverages');

-- Block 2: Inserting data into tables that depend on Block 1.
-- ---------------------------------------------------------------------

INSERT INTO products (product_id, product_name, sale_price_cents, category_id, unit_of_measure) VALUES
(1, 'French Bread', 80, 1, 'unit'),
(2, 'Grandma''s Chocolate Cake', 3500, 2, 'unit'),
(3, 'Chicken Coxinha', 750, 3, 'unit'),
(4, 'Soda Can', 500, 4, 'unit'),
(5, 'Whole Milk Carton', 650, 4, 'unit');

INSERT INTO ingredients (ingredient_id, ingredient_name, unit_of_measure, minimum_stock_quantity) VALUES
(101, 'All-Purpose Flour', 'kg', 20.0),
(102, 'Dry Yeast', 'g', 0),
(103, 'Whole Milk', 'liter', 12.0),
(104, 'Eggs', 'unit', 0),
(105, '50% Cocoa Powder', 'kg', 0);

INSERT INTO ingredient_suppliers (ingredient_id, supplier_id) VALUES
(101, 1),
(102, 1),
(103, 2),
(104, 2),
(105, 1);

INSERT INTO till_sessions (session_id, employee_id, opening_timestamp, initial_balance_cents) VALUES
(1, 1, '2025-09-10 08:00:00', 10000);


-- Block 3: Populating stock tables.
-- ---------------------------------------------------------------------

INSERT INTO product_stock (product_id, current_quantity, minimum_quantity) VALUES
(1, 150.0, 50.0), -- 150 French Breads
(2, 5.0, 2.0),    -- 5 Chocolate Cakes
(4, 48.0, 12.0);  -- 48 Soda Cans

INSERT INTO ingredient_batches (
	batch_id,
	ingredient_id,
	supplier_id,
	received_timestamp,
	expiration_date,
	received_quantity,
	current_quantity
) VALUES
(1, 101, 1, '2025-09-01 08:00:00', '2026-06-30', 20.0, 20.0),
(2, 101, 1, '2025-09-08 08:00:00', '2026-12-31', 30.0, 30.0),
(3, 103, 2, '2025-09-08 08:00:00', '2025-09-25', 24.0, 24.0);


-- Block 4: Populating relationship and transaction tables.
-- ---------------------------------------------------------------------

-- A sample recipe for the chocolate cake
INSERT INTO recipes (product_id, ingredient_id, quantity) VALUES
(2, 101, 0.500), -- 500g of flour
(2, 103, 0.250), -- 250ml of milk
(2, 104, 3),  -- 3 eggs
(2, 105, 0.100); -- 100g of cocoa powder

-- Simulating a complete sale for Customer 1 (John Doe)
INSERT INTO orders (order_id, customer_id, employee_id, order_timestamp, order_status) VALUES
(101, 1, 1, '2025-09-10 17:30:00', 'Completed');

-- Items for Order 101
INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents) VALUES
(101, 1, 10, 80), -- 10 French Breads @ $0.80
(101, 5, 1, 650), -- 1 Milk Carton @ $6.50
(101, 3, 1, 500); -- 1 Chicken drumstick @ $5.00 (price changed for this sale)


-- The Sale is registered from Order 101
INSERT INTO sales (sale_id, order_id, employee_id, sale_timestamp, payment_method) VALUES
(1, 101, 1, '2025-09-10 17:32:00', 'Debit Card');


-- Simulating another sale for Customer 2 (Mary Jane)
INSERT INTO orders (order_id, customer_id, employee_id, order_timestamp, order_status) VALUES
(102, 2, 1, '2025-09-10 18:15:00', 'Completed');

-- Items for Order 102
INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents) VALUES
(102, 2, 1, 3500), -- 1 Chocolate Cake @ $35.00
(102, 4, 1, 500);  -- 1 Soda Can @ $5.00

-- The Sale is registered from Order 102
INSERT INTO sales (sale_id, order_id, employee_id, sale_timestamp, payment_method) VALUES
(2, 102, 1, '2025-09-10 18:16:00', 'Cash');

-- COMMIT; -- Use this if you started a transaction.
-- =====================================================================
-- End of Script
-- =====================================================================
