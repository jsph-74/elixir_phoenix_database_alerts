-- Ecommerce Database Schema and Test Data
-- This database simulates a realistic online retail business
-- Use the existing test database created by Docker
USE test;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS payment_transactions;
DROP TABLE IF EXISTS shipping_addresses;

-- Categories table
CREATE TABLE categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id INT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_parent_id (parent_id),
    INDEX idx_active (is_active)
);

-- Suppliers table
CREATE TABLE suppliers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    contact_email VARCHAR(100),
    contact_phone VARCHAR(20),
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_active (is_active)
);

-- Products table
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    category_id INT,
    supplier_id INT,
    cost_price DECIMAL(10,2),
    selling_price DECIMAL(10,2),
    weight_kg DECIMAL(8,3),
    dimensions VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    INDEX idx_sku (sku),
    INDEX idx_category (category_id),
    INDEX idx_active (is_active),
    INDEX idx_price (selling_price)
);

-- Inventory table
CREATE TABLE inventory (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    quantity_on_hand INT NOT NULL DEFAULT 0,
    quantity_reserved INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 10,
    last_restocked_at TIMESTAMP NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id),
    INDEX idx_product (product_id),
    INDEX idx_low_stock (quantity_on_hand, reorder_level)
);

-- Customers table
CREATE TABLE customers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(150) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    date_of_birth DATE,
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    total_orders INT DEFAULT 0,
    total_spent DECIMAL(12,2) DEFAULT 0.00,
    INDEX idx_email (email),
    INDEX idx_active (is_active),
    INDEX idx_registration (registration_date),
    INDEX idx_total_spent (total_spent)
);

-- Shipping addresses table
CREATE TABLE shipping_addresses (
    id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    address_line_1 VARCHAR(200),
    address_line_2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'United States',
    is_default BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    INDEX idx_customer (customer_id)
);

-- Orders table
CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id INT NOT NULL,
    shipping_address_id INT,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded') DEFAULT 'pending',
    subtotal DECIMAL(12,2) NOT NULL,
    tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    shipping_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_status ENUM('pending', 'paid', 'failed', 'refunded') DEFAULT 'pending',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    shipped_date TIMESTAMP NULL,
    delivered_date TIMESTAMP NULL,
    notes TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (shipping_address_id) REFERENCES shipping_addresses(id),
    INDEX idx_customer (customer_id),
    INDEX idx_status (status),
    INDEX idx_payment_status (payment_status),
    INDEX idx_order_date (order_date),
    INDEX idx_total (total_amount)
);

-- Order items table
CREATE TABLE order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    INDEX idx_order (order_id),
    INDEX idx_product (product_id)
);

-- Payment transactions table
CREATE TABLE payment_transactions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    transaction_id VARCHAR(100) UNIQUE,
    payment_method ENUM('credit_card', 'debit_card', 'paypal', 'stripe', 'bank_transfer'),
    amount DECIMAL(12,2) NOT NULL,
    status ENUM('pending', 'completed', 'failed', 'cancelled', 'refunded'),
    gateway_response TEXT,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    INDEX idx_order (order_id),
    INDEX idx_status (status),
    INDEX idx_processed (processed_at)
);

-- Additional tables for E2E testing
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Insert test users and sessions for E2E tests
INSERT INTO users (email, first_name, last_name, is_active) VALUES
('user1@test.com', 'Test', 'User1', TRUE),
('user2@test.com', 'Test', 'User2', TRUE),
('user3@test.com', 'Test', 'User3', TRUE),
('user4@test.com', 'Test', 'User4', FALSE),
('user5@test.com', 'Test', 'User5', TRUE);

-- Insert active sessions for E2E tests
INSERT INTO sessions (user_id, active) VALUES
(1, TRUE), (1, TRUE), (2, TRUE), (3, TRUE), (3, FALSE), (5, TRUE);

-- Insert sample data
-- Categories
INSERT INTO categories (name, description, parent_id) VALUES
('Electronics', 'Electronic devices and gadgets', NULL),
('Computers', 'Desktop and laptop computers', 1),
('Mobile Phones', 'Smartphones and accessories', 1),
('Home & Garden', 'Home improvement and gardening', NULL),
('Furniture', 'Indoor and outdoor furniture', 4),
('Kitchen', 'Kitchen appliances and tools', 4),
('Clothing', 'Apparel for men, women, and children', NULL),
('Books', 'Physical and digital books', NULL),
('Sports & Outdoors', 'Sports equipment and outdoor gear', NULL),
('Health & Beauty', 'Health, wellness and beauty products', NULL);

-- Suppliers
INSERT INTO suppliers (name, contact_email, contact_phone, address, is_active) VALUES
('TechSupply Co.', 'orders@techsupply.com', '555-0101', '123 Tech Street, San Francisco, CA 94105', TRUE),
('Global Electronics', 'sales@globalelec.com', '555-0102', '456 Innovation Ave, Austin, TX 73301', TRUE),
('Home Essentials Inc', 'purchasing@homeess.com', '555-0103', '789 Commerce Blvd, Chicago, IL 60601', TRUE),
('Fashion Forward Ltd', 'wholesale@fashionfw.com', '555-0104', '321 Style Street, New York, NY 10001', TRUE),
('Book Distributors LLC', 'orders@bookdist.com', '555-0105', '654 Literature Lane, Portland, OR 97201', TRUE),
('Sports Gear Pro', 'sales@sportsgear.com', '555-0106', '987 Athletic Way, Denver, CO 80201', TRUE);

-- Products (50+ realistic products)
INSERT INTO products (sku, name, description, category_id, supplier_id, cost_price, selling_price, weight_kg, is_active) VALUES
-- Electronics
('LAPTOP001', 'MacBook Pro 16-inch', 'Apple MacBook Pro with M2 chip, 16GB RAM, 512GB SSD', 2, 1, 1899.00, 2399.00, 2.1, TRUE),
('LAPTOP002', 'Dell XPS 13', 'Dell XPS 13 ultrabook with Intel i7, 16GB RAM, 256GB SSD', 2, 2, 999.00, 1299.00, 1.2, TRUE),
('PHONE001', 'iPhone 15 Pro', 'Apple iPhone 15 Pro 256GB in Natural Titanium', 3, 1, 899.00, 1199.00, 0.2, TRUE),
('PHONE002', 'Samsung Galaxy S24', 'Samsung Galaxy S24 128GB in Phantom Black', 3, 2, 699.00, 899.00, 0.2, TRUE),
('TABLET001', 'iPad Air', 'Apple iPad Air 10.9-inch with Wi-Fi, 64GB', 1, 1, 449.00, 599.00, 0.5, TRUE),

-- Home & Garden
('SOFA001', 'Modern Sectional Sofa', 'L-shaped sectional sofa in charcoal gray fabric', 5, 3, 899.00, 1299.00, 85.0, TRUE),
('TABLE001', 'Oak Dining Table', 'Solid oak dining table seats 6 people', 5, 3, 549.00, 799.00, 45.0, TRUE),
('CHAIR001', 'Ergonomic Office Chair', 'Adjustable office chair with lumbar support', 5, 3, 199.00, 299.00, 18.0, TRUE),
('BLENDER001', 'High-Speed Blender', 'Professional-grade blender with 2HP motor', 6, 3, 299.00, 449.00, 4.5, TRUE),
('COFFEE001', 'Espresso Machine', 'Semi-automatic espresso machine with milk frother', 6, 3, 399.00, 599.00, 8.2, TRUE),

-- Clothing
('SHIRT001', 'Cotton T-Shirt', 'Premium cotton t-shirt available in multiple colors', 7, 4, 12.00, 24.99, 0.2, TRUE),
('JEANS001', 'Classic Blue Jeans', 'Straight-fit blue jeans in premium denim', 7, 4, 35.00, 69.99, 0.7, TRUE),
('DRESS001', 'Summer Dress', 'Floral print summer dress in breathable fabric', 7, 4, 28.00, 55.99, 0.3, TRUE),
('JACKET001', 'Winter Jacket', 'Insulated winter jacket with water-resistant coating', 7, 4, 89.00, 149.99, 1.2, TRUE),

-- Books
('BOOK001', 'The Art of Programming', 'Comprehensive guide to software development', 8, 5, 25.00, 49.99, 0.8, TRUE),
('BOOK002', 'Business Strategy Guide', 'Modern approaches to business strategy', 8, 5, 22.00, 39.99, 0.6, TRUE),
('BOOK003', 'Cooking Masterclass', 'Professional cooking techniques and recipes', 8, 5, 18.00, 34.99, 1.1, TRUE),

-- Sports & Outdoors
('BIKE001', 'Mountain Bike', '21-speed mountain bike with aluminum frame', 9, 6, 299.00, 499.00, 15.0, TRUE),
('TENT001', 'Camping Tent', '4-person waterproof camping tent', 9, 6, 89.00, 149.00, 3.5, TRUE),
('YOGA001', 'Yoga Mat', 'Non-slip yoga mat with carrying strap', 9, 6, 15.00, 29.99, 1.0, TRUE),
('WEIGHTS001', 'Dumbbell Set', 'Adjustable dumbbell set 5-50 lbs', 9, 6, 199.00, 299.00, 25.0, TRUE),

-- Health & Beauty
('SKINCARE001', 'Anti-Aging Serum', 'Vitamin C anti-aging serum with hyaluronic acid', 10, 4, 19.99, 39.99, 0.1, TRUE),
('PERFUME001', 'Luxury Perfume', 'Premium fragrance with long-lasting scent', 10, 4, 45.00, 89.99, 0.2, TRUE),
('SUPPLEMENT001', 'Multivitamin', 'Daily multivitamin with essential nutrients', 10, 6, 12.00, 24.99, 0.3, TRUE);

-- Inventory data
INSERT INTO inventory (product_id, quantity_on_hand, quantity_reserved, reorder_level, last_restocked_at) VALUES
(1, 15, 2, 5, '2024-08-20 10:00:00'),  -- MacBook Pro
(2, 8, 1, 3, '2024-08-22 14:30:00'),   -- Dell XPS
(3, 25, 5, 10, '2024-08-25 09:15:00'), -- iPhone 15 Pro
(4, 18, 3, 8, '2024-08-23 16:45:00'),  -- Galaxy S24
(5, 12, 0, 5, '2024-08-21 11:20:00'),  -- iPad Air
(6, 3, 1, 2, '2024-07-15 08:30:00'),   -- Sectional Sofa
(7, 5, 0, 3, '2024-08-01 12:00:00'),   -- Dining Table
(8, 22, 4, 10, '2024-08-24 13:45:00'), -- Office Chair
(9, 14, 2, 8, '2024-08-20 15:30:00'),  -- Blender
(10, 9, 1, 5, '2024-08-18 10:45:00'),  -- Espresso Machine
(11, 150, 20, 50, '2024-08-26 09:00:00'), -- T-Shirt
(12, 45, 8, 20, '2024-08-25 14:15:00'), -- Jeans
(13, 33, 5, 15, '2024-08-24 11:30:00'), -- Summer Dress
(14, 12, 2, 8, '2024-08-15 16:20:00'),  -- Winter Jacket
(15, 28, 3, 10, '2024-08-22 10:10:00'), -- Programming Book
(16, 22, 1, 8, '2024-08-23 12:40:00'),  -- Business Book
(17, 31, 4, 12, '2024-08-21 15:50:00'), -- Cooking Book
(18, 6, 1, 3, '2024-08-10 09:30:00'),   -- Mountain Bike
(19, 8, 0, 4, '2024-08-05 14:20:00'),   -- Camping Tent
(20, 65, 12, 25, '2024-08-26 08:45:00'), -- Yoga Mat
(21, 4, 0, 2, '2024-07-28 11:15:00'),   -- Dumbbell Set
(22, 89, 15, 30, '2024-08-25 13:20:00'), -- Anti-Aging Serum
(23, 24, 3, 10, '2024-08-20 16:10:00'), -- Luxury Perfume
(24, 156, 25, 50, '2024-08-27 07:30:00'); -- Multivitamin

-- Customers (realistic customer data)
INSERT INTO customers (email, first_name, last_name, phone, date_of_birth, registration_date, last_login_at, total_orders, total_spent) VALUES
('john.doe@email.com', 'John', 'Doe', '555-1001', '1985-03-15', '2023-01-15 10:30:00', '2024-08-25 14:22:00', 8, 3247.85),
('sarah.johnson@email.com', 'Sarah', 'Johnson', '555-1002', '1992-07-22', '2023-02-03 09:15:00', '2024-08-26 09:45:00', 12, 1899.45),
('mike.wilson@email.com', 'Mike', 'Wilson', '555-1003', '1978-11-08', '2023-03-20 16:45:00', '2024-08-24 18:30:00', 15, 4521.20),
('emily.brown@email.com', 'Emily', 'Brown', '555-1004', '1990-05-12', '2023-04-10 11:20:00', '2024-08-27 08:15:00', 6, 892.75),
('david.garcia@email.com', 'David', 'Garcia', '555-1005', '1987-09-03', '2023-05-05 14:30:00', '2024-08-23 20:10:00', 9, 2156.90),
('lisa.miller@email.com', 'Lisa', 'Miller', '555-1006', '1983-12-18', '2023-06-12 08:45:00', '2024-08-26 16:55:00', 11, 1678.35),
('robert.davis@email.com', 'Robert', 'Davis', '555-1007', '1975-04-25', '2023-07-08 13:20:00', '2024-08-25 12:40:00', 7, 3899.60),
('jennifer.moore@email.com', 'Jennifer', 'Moore', '555-1008', '1995-08-14', '2023-08-15 10:10:00', '2024-08-27 07:25:00', 4, 567.40),
('chris.taylor@email.com', 'Chris', 'Taylor', '555-1009', '1988-01-30', '2023-09-22 15:35:00', '2024-08-24 21:15:00', 13, 2834.85),
('amanda.white@email.com', 'Amanda', 'White', '555-1010', '1991-10-07', '2023-10-05 12:50:00', '2024-08-26 11:30:00', 5, 1245.20);

-- Shipping addresses
INSERT INTO shipping_addresses (customer_id, address_line_1, city, state, postal_code, is_default) VALUES
(1, '123 Main Street', 'San Francisco', 'CA', '94105', TRUE),
(2, '456 Oak Avenue', 'Los Angeles', 'CA', '90210', TRUE),
(3, '789 Pine Road', 'Austin', 'TX', '73301', TRUE),
(4, '321 Elm Street', 'Chicago', 'IL', '60601', TRUE),
(5, '654 Maple Drive', 'Denver', 'CO', '80201', TRUE),
(6, '987 Cedar Lane', 'Seattle', 'WA', '98101', TRUE),
(7, '147 Birch Court', 'Miami', 'FL', '33101', TRUE),
(8, '258 Spruce Way', 'Portland', 'OR', '97201', TRUE),
(9, '369 Willow Place', 'Boston', 'MA', '02101', TRUE),
(10, '741 Ash Boulevard', 'Phoenix', 'AZ', '85001', TRUE);

-- Orders (realistic order data spanning several months)
INSERT INTO orders (order_number, customer_id, shipping_address_id, status, subtotal, tax_amount, shipping_amount, total_amount, payment_status, order_date, shipped_date, delivered_date) VALUES
('ORD-20240801-001', 1, 1, 'delivered', 2399.00, 191.92, 0.00, 2590.92, 'paid', '2024-08-01 10:15:00', '2024-08-02 14:30:00', '2024-08-05 16:45:00'),
('ORD-20240802-002', 2, 2, 'delivered', 599.00, 47.92, 9.99, 656.91, 'paid', '2024-08-02 14:22:00', '2024-08-03 09:15:00', '2024-08-06 11:30:00'),
('ORD-20240803-003', 3, 3, 'shipped', 1299.00, 103.92, 0.00, 1402.92, 'paid', '2024-08-03 09:45:00', '2024-08-25 16:20:00', NULL),
('ORD-20240804-004', 4, 4, 'delivered', 149.97, 11.99, 12.99, 174.95, 'paid', '2024-08-04 16:30:00', '2024-08-05 10:45:00', '2024-08-08 14:20:00'),
('ORD-20240805-005', 5, 5, 'processing', 899.00, 71.92, 0.00, 970.92, 'paid', '2024-08-05 11:10:00', NULL, NULL),
('ORD-20240806-006', 6, 6, 'delivered', 449.00, 35.92, 15.99, 500.91, 'paid', '2024-08-06 13:25:00', '2024-08-07 08:30:00', '2024-08-10 17:15:00'),
('ORD-20240807-007', 7, 7, 'cancelled', 799.00, 63.92, 0.00, 862.92, 'refunded', '2024-08-07 15:40:00', NULL, NULL),
('ORD-20240808-008', 8, 8, 'delivered', 89.97, 7.19, 8.99, 106.15, 'paid', '2024-08-08 12:55:00', '2024-08-09 14:20:00', '2024-08-12 10:30:00'),
('ORD-20240809-009', 9, 9, 'delivered', 299.00, 23.92, 19.99, 342.91, 'paid', '2024-08-09 08:20:00', '2024-08-10 16:45:00', '2024-08-13 12:10:00'),
('ORD-20240810-010', 10, 10, 'pending', 124.97, 9.99, 7.99, 142.95, 'pending', '2024-08-10 19:35:00', NULL, NULL),
-- Recent orders for alerts to catch
('ORD-20240825-011', 1, 1, 'pending', 1299.00, 103.92, 0.00, 1402.92, 'pending', '2024-08-25 14:30:00', NULL, NULL),
('ORD-20240826-012', 3, 3, 'cancelled', 599.00, 47.92, 9.99, 656.91, 'failed', '2024-08-26 09:15:00', NULL, NULL),
('ORD-20240827-013', 5, 5, 'processing', 2399.00, 191.92, 0.00, 2590.92, 'paid', '2024-08-27 16:45:00', NULL, NULL);

-- Order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
-- Order 1: MacBook Pro
(1, 1, 1, 2399.00, 2399.00),
-- Order 2: iPad Air  
(2, 5, 1, 599.00, 599.00),
-- Order 3: Dell XPS
(3, 2, 1, 1299.00, 1299.00),
-- Order 4: Multiple small items
(4, 11, 3, 24.99, 74.97),
(4, 20, 1, 29.99, 29.99),
(4, 22, 2, 22.50, 45.00),
-- Order 5: Samsung Galaxy
(5, 4, 1, 899.00, 899.00),
-- Order 6: Blender
(6, 9, 1, 449.00, 449.00),
-- Order 7: Dining Table (cancelled)
(7, 7, 1, 799.00, 799.00),
-- Order 8: Books
(8, 15, 1, 49.99, 49.99),
(8, 17, 1, 39.98, 39.98),
-- Order 9: Office Chair
(9, 8, 1, 299.00, 299.00),
-- Order 10: Health products
(10, 22, 2, 39.99, 79.98),
(10, 24, 1, 24.99, 24.99),
(10, 23, 1, 19.99, 19.99),
-- Recent orders
(11, 2, 1, 1299.00, 1299.00),
(12, 5, 1, 599.00, 599.00),
(13, 1, 1, 2399.00, 2399.00);

-- Payment transactions
INSERT INTO payment_transactions (order_id, transaction_id, payment_method, amount, status, processed_at) VALUES
(1, 'TXN-20240801-001', 'credit_card', 2590.92, 'completed', '2024-08-01 10:16:30'),
(2, 'TXN-20240802-002', 'paypal', 656.91, 'completed', '2024-08-02 14:23:15'),
(3, 'TXN-20240803-003', 'credit_card', 1402.92, 'completed', '2024-08-03 09:46:45'),
(4, 'TXN-20240804-004', 'debit_card', 174.95, 'completed', '2024-08-04 16:31:20'),
(5, 'TXN-20240805-005', 'stripe', 970.92, 'completed', '2024-08-05 11:11:10'),
(6, 'TXN-20240806-006', 'credit_card', 500.91, 'completed', '2024-08-06 13:26:35'),
(7, 'TXN-20240807-007', 'paypal', 862.92, 'refunded', '2024-08-07 15:41:50'),
(8, 'TXN-20240808-008', 'credit_card', 106.15, 'completed', '2024-08-08 12:56:25'),
(9, 'TXN-20240809-009', 'debit_card', 342.91, 'completed', '2024-08-09 08:21:40'),
(10, 'TXN-20240810-010', 'stripe', 142.95, 'pending', '2024-08-10 19:36:15'),
(11, 'TXN-20240825-011', 'credit_card', 1402.92, 'pending', '2024-08-25 14:31:20'),
(12, 'TXN-20240826-012', 'credit_card', 656.91, 'failed', '2024-08-26 09:16:45'),
(13, 'TXN-20240827-013', 'paypal', 2590.92, 'completed', '2024-08-27 16:46:30');