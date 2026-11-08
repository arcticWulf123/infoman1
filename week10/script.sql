INSERT INTO products(product_name, sku, price, stock_quantity, status) VALUES ("Scientific Calculator", "CMP-001", 120.00, 50,"Active")
INSERT INTO products(product_name, sku, price, stock_quantity, status) VALUES ("Compass", "CMP-001", 120.00, 50,"Active")


UPDATE products SET price = 875 WHERE product_id = 6;
DELETE FROM products WHERE product_id = 5;


SELECT a.employee_name AS employee_name, b.employee_name AS manager_name FROM employees AS a LEFT JOIN employees b ON a.manager_id = b.employee_id;
SELECT colors.color_name, sizes.size_name FROM colors CROSS JOIN sizes;


ALTER TABLE employees ADD contact_number VARCHAR(20)
alter table products modify product_name varchar(100) not null;
insert into products (product_name, sku, price, stock_quantity , status) values ("Smartwatch", "SW-773", 500, 10, "Active")
insert into products (product_name, sku , price, stock_quantity , status) values (null, "CSR-334", 10, 10, "Active")
alter table products modify sku varchar(30) UNIQUE
insert into products (product_name, sku, price, stock_quantity , status) values ("Monitor", "MR-899", 300, 40, "Active")
insert into products (product_name, sku, price, stock_quantity , status) values ("Camera", "MR-899", 100, 5, "Active")
ALTER TABLE products ADD CONSTRAINT check_positive_price CHECK (price > 0);
insert into products (product_name, sku, price, stock_quantity , status) values ("Smartglasses", "SG-645", 3700, 8, "Active")
insert into products (product_name, sku, price, stock_quantity , status) values ("Drone", "DR-142", -20, 2, "Active")
