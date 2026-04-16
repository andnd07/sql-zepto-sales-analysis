-- =================================================
--          PHASE 1 — SETUP & DATA IMPORT
-- =================================================

CREATE DATABASE zepto_project;
USE zepto_project;

-- NOTE: Table structure reference via CSV wizard
-- CREATE TABLE zepto (
--     sku_id                INT,
--     category              VARCHAR(100),
--     name                  VARCHAR(150),
--     mrp                   DECIMAL(10, 2),
--     DiscountPercent       DECIMAL(5, 2),
--     AvailableQuantity     INT,
--     DiscountedSellingPrice DECIMAL(10, 2),
--     WeightInGms           INT,
--     OutofStock            VARCHAR(10),
--     quantity              INT
-- );

DROP TABLE zepto;
RENAME TABLE zepto_dataset TO zepto;



-- =================================================
--          PHASE 2 — DATA EXPLORATION (EDA)
-- =================================================

-- Q1: Total row count
SELECT COUNT(*) AS total_products 
FROM zepto;

-- Q2: Check for NULL values
SELECT 
COUNT(*) - COUNT(sku_id) AS null_sku,
COUNT(*) - COUNT(category) AS null_category,
COUNT(*) - COUNT(name) AS null_name,
COUNT(*) - COUNT(mrp) AS null_mrp,
COUNT(*) - COUNT(DiscountPercent) AS null_discount,
COUNT(*) - COUNT(AvailableQuantity) AS null_qty,
COUNT(*) - COUNT(DiscountedSellingPrice) AS null_discounted_price,
COUNT(*) - COUNT(WeightInGms) AS null_weight,
COUNT(*) - COUNT(OutofStock) AS null_out_of_stock,
COUNT(*) - COUNT(quantity) AS null_quantity
FROM zepto;

-- Q3: Total unique categories
SELECT COUNT(DISTINCT category) AS total_categories 
FROM zepto;

-- Q4: List all categories
SELECT DISTINCT category 
FROM zepto 
ORDER BY category;

-- Q5: Price range of products
SELECT 
MIN(mrp) AS cheapest_mrp,
MAX(mrp) AS costliest_mrp,
ROUND(AVG(mrp), 2) AS avg_mrp
FROM zepto;

-- -- Q6: In stock vs Out of stock count
SELECT OutofStock, COUNT(*) AS product_count
FROM zepto
GROUP BY OutofStock;

/*
----------------------------------------------------------
Insight:
3700 products total
0 NULL values — clean data 
5 categories — Beverages, Dairy, Fruits, Snacks, Vegetables
Price range ₹10 to ₹499 with avg ₹256
Only 24 products out of stock (rest 3676 are available)
-----------------------------------------------------------
*/



-- =================================================
--        PHASE 3 — BUSINESS QUESTIONS
-- =================================================

-- Q1: Find all products where MRP is greater than 100
-- and they are currently IN stock
SELECT name, category, mrp, OutofStock
FROM zepto
WHERE mrp > 100 AND OutofStock = 'false';

-- Q2: Find top 10 most discounted products
SELECT name, category, mrp, DiscountPercent
FROM zepto
ORDER BY DiscountPercent DESC
LIMIT 10;

 -- Q3: How many products are there in each category?
SELECT category, COUNT(*) AS total_products
FROM zepto
GROUP BY category
ORDER BY total_products DESC;

-- Q4: Average discount percentage per category
SELECT category, ROUND(AVG(DiscountPercent), 2) AS avg_discount
FROM zepto
GROUP BY category
ORDER BY avg_discount DESC;

-- Q5: Find all OUT OF STOCK products
SELECT name, category, mrp
FROM zepto
WHERE OutofStock = 'true'
ORDER BY category;

-- Q6: Find products where discounted price is less than 100
SELECT name, category, mrp, DiscountedSellingPrice
FROM zepto
WHERE DiscountedSellingPrice < 100
ORDER BY DiscountedSellingPrice ASC;

-- Q7: Total inventory value per category
-- (how much stock is worth in each category)
SELECT category,
ROUND(SUM(DiscountedSellingPrice * AvailableQuantity), 2) AS total_inventory_value
FROM zepto
GROUP BY category
ORDER BY total_inventory_value DESC;

-- Q8: Find products with more than 20% discount
SELECT name, category, mrp, DiscountPercent, DiscountedSellingPrice
FROM zepto
WHERE DiscountPercent > 20
ORDER BY DiscountPercent DESC;



-- =================================================
--        PHASE 4 — INTERMEDIATE ANALYSIS
-- =================================================


-- Q1: Categorize products by price range using CASE WHEN
SELECT name, category, mrp,
CASE 
	WHEN mrp < 100 THEN 'Budget'
	WHEN mrp BETWEEN 100 AND 300 THEN 'Mid Range'
	WHEN mrp > 300 THEN 'Premium'
END AS price_category
FROM zepto
ORDER BY mrp DESC;


-- Q2: Find categories where average MRP is greater than 200
SELECT category, ROUND(AVG(mrp), 2) AS avg_mrp
FROM zepto
GROUP BY category
HAVING AVG(mrp) > 200
ORDER BY avg_mrp DESC;


-- Q3: Find products that are more expensive than 
-- the average MRP of their own category (Subquery)
SELECT name, category, mrp, ROUND((SELECT AVG(mrp) FROM zepto z2 
WHERE z2.category = z1.category), 2) AS category_avg
FROM zepto z1
WHERE mrp > (SELECT AVG(mrp) FROM zepto z2 
WHERE z2.category = z1.category)
ORDER BY category, mrp DESC;


-- Q4: Rank products by MRP within each category
SELECT name, category, mrp,
RANK() OVER (PARTITION BY category ORDER BY mrp DESC) AS price_rank
FROM zepto;


-- Q5: Find top 3 most expensive products in each category
-- (Window Function + Subquery combined!)
SELECT name, category, mrp, price_rank
FROM (
SELECT name, category, mrp,
RANK() OVER (PARTITION BY category ORDER BY mrp DESC) AS price_rank
FROM zepto
) ranked_products
WHERE price_rank <= 3;


-- Q6: Calculate discount savings amount for each product
-- and label it as High / Medium / Low saving
SELECT name, category, mrp, DiscountPercent,
ROUND(mrp - DiscountedSellingPrice, 2) AS saving_amount,
CASE
	WHEN (mrp - DiscountedSellingPrice) > 100 THEN 'High Saving'
	WHEN (mrp - DiscountedSellingPrice) BETWEEN 50 AND 100 THEN 'Medium Saving'
	ELSE 'Low Saving'
END AS saving_category
FROM zepto
ORDER BY saving_amount DESC;


-- Q7: Find categories where MORE THAN 5 products 
-- are out of stock (HAVING with condition)
SELECT category, COUNT(*) AS out_of_stock_count
FROM zepto
WHERE OutofStock = 'true'
GROUP BY category
HAVING COUNT(*) > 5;


-- Q8: Running total of inventory value by category
-- (Advanced Window Function)
SELECT category, name, DiscountedSellingPrice,
ROUND(SUM(DiscountedSellingPrice) OVER (PARTITION BY category ORDER BY DiscountedSellingPrice DESC), 2) AS running_total
FROM zepto;



-- =================================================
--        PHASE 5 — BUSINESS INSIGHTS & VIEWS
-- =================================================


-- INSIGHT 1: Which category gives the best value to customers?
-- (Highest avg discount + lowest avg price)
SELECT category,
ROUND(AVG(DiscountPercent), 2) AS avg_discount,
ROUND(AVG(mrp), 2) AS avg_mrp,
ROUND(AVG(DiscountedSellingPrice), 2) AS avg_final_price
FROM zepto
GROUP BY category
ORDER BY avg_discount DESC;


-- INSIGHT 2: Stock health report per category
-- (How many in stock vs out of stock per category)
SELECT category,
COUNT(*) AS total_products,
SUM(CASE WHEN OutofStock = 'false' THEN 1 ELSE 0 END) AS in_stock,
SUM(CASE WHEN OutofStock = 'true'  THEN 1 ELSE 0 END) AS out_of_stock,
ROUND(SUM(CASE WHEN OutofStock = 'true' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS out_of_stock_pct
FROM zepto
GROUP BY category
ORDER BY out_of_stock_pct DESC;


-- INSIGHT 3: Revenue opportunity report
-- (Products out of stock — how much revenue is being lost)
SELECT category, name, mrp, DiscountedSellingPrice, AvailableQuantity,
ROUND(DiscountedSellingPrice * AvailableQuantity, 2) AS potential_revenue
FROM zepto
WHERE OutofStock = 'false'
GROUP BY category, name, mrp, DiscountedSellingPrice, AvailableQuantity
ORDER BY potential_revenue DESC
LIMIT 10;


-- INSIGHT 4: Weight vs Price analysis
-- (Do heavier products cost more?)
SELECT category,
ROUND(AVG(WeightInGms), 2) AS avg_weight_gms,
ROUND(AVG(mrp), 2) AS avg_mrp,
ROUND(AVG(mrp)/AVG(WeightInGms) * 100, 2) AS price_per_100gms
FROM zepto
GROUP BY category
ORDER BY price_per_100gms DESC;


-- INSIGHT 5: Best discount deals right now
-- (In stock products with highest discount)
SELECT name, category, mrp, DiscountPercent, DiscountedSellingPrice,
ROUND(mrp - DiscountedSellingPrice, 2) AS you_save
FROM zepto
WHERE OutofStock = 'false'
ORDER BY DiscountPercent DESC
LIMIT 10;



-- =================================================
--             CREATE VIEWS 
-- =================================================

-- VIEW 1: Always up to date stock summary
CREATE VIEW stock_summary AS
SELECT category,
COUNT(*) AS total_products,
SUM(CASE WHEN OutofStock = 'false' THEN 1 ELSE 0 END) AS in_stock,
SUM(CASE WHEN OutofStock = 'true'  THEN 1 ELSE 0 END) AS out_of_stock
FROM zepto
GROUP BY category;

-- Query the view
SELECT * FROM stock_summary;

-- VIEW 2: Premium products view
CREATE VIEW premium_products AS
SELECT name, category, mrp, DiscountPercent, DiscountedSellingPrice
FROM zepto
WHERE mrp > 300 AND OutofStock = 'false'
ORDER BY mrp DESC;

-- Query the view
SELECT * FROM premium_products;

-- VIEW 3: Best deals view
CREATE VIEW best_deals AS
SELECT name, category, mrp, DiscountPercent, DiscountedSellingPrice,
ROUND(mrp - DiscountedSellingPrice, 2) AS savings
FROM zepto
WHERE DiscountPercent > 20 AND OutofStock = 'false'
ORDER BY DiscountPercent DESC;

-- Query the view
SELECT * FROM best_deals;



-- =================================================
--        PHASE 6 — FINAL DOCUMENTATION
-- =================================================


-- PROJECT SUMMARY
-- -----------------------------------------------
-- Project Title : Zepto Product & Inventory Analysis
-- Tool Used     : MySQL
-- Dataset       : Zepto Products (Kaggle)
-- Total Records : 3700 rows
-- Author        : Anand Prajapati
-- Date          : 16 Mar 2026
-- -----------------------------------------------

-- BUSINESS OBJECTIVE:
-- Analyze Zepto's product catalog to understand
-- pricing strategy, discount patterns, inventory
-- health and category performance.
-- -----------------------------------------------

-- KEY FINDINGS:
-- 1. Only 24 out of 3700 products are out of stock
--    showing strong inventory management
-- 2. All 5 categories have products ranging from
--    budget (₹10) to premium (₹499)
-- 3. Some products offer more than 20% discount
--    making them best value deals for customers
-- 4. Dairy and Vegetables dominate in product count
-- 5. Premium products (MRP > ₹300) are mostly in stock
-- -----------------------------------------------

-- SKILLS DEMONSTRATED:
-- ✓ Database creation and table setup
-- ✓ Data cleaning and NULL checks
-- ✓ Exploratory Data Analysis (EDA)
-- ✓ Aggregations (SUM, AVG, COUNT, MIN, MAX)
-- ✓ Filtering (WHERE, HAVING)
-- ✓ Conditional logic (CASE WHEN)
-- ✓ Subqueries
-- ✓ Window Functions (RANK, SUM OVER, PARTITION BY)
-- ✓ Views creation
-- ✓ Business insight generation
-- -----------------------------------------------