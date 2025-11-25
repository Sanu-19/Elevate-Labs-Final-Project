
-- retail_analysis.sql
-- SQL queries for Retail Business Performance & Profitability Analysis
-- Assumes a table named sales with columns:
-- order_id, order_date, region, category, sub_category, product_id, product_name,
-- quantity, unit_price, cost_price, inventory_days, stock_on_hand

-- 1. Clean records (example: remove rows with nulls in essential fields)
CREATE TABLE sales_clean AS
SELECT *
FROM sales
WHERE order_id IS NOT NULL
  AND order_date IS NOT NULL
  AND product_id IS NOT NULL
  AND quantity IS NOT NULL
  AND unit_price IS NOT NULL
  AND cost_price IS NOT NULL;

-- 2. Add computed columns: revenue, cost, profit, margin
CREATE TABLE sales_enriched AS
SELECT *,
       quantity * unit_price AS revenue,
       quantity * cost_price AS cost,
       (quantity * unit_price) - (quantity * cost_price) AS profit,
       CASE WHEN quantity * unit_price = 0 THEN 0
            ELSE ((quantity * unit_price) - (quantity * cost_price)) / (quantity * unit_price)
       END AS profit_margin
FROM sales_clean;

-- 3. Profitability by category and sub-category
SELECT category,
       sub_category,
       SUM(revenue) AS total_revenue,
       SUM(cost) AS total_cost,
       SUM(profit) AS total_profit,
       AVG(profit_margin) AS avg_profit_margin,
       COUNT(DISTINCT product_id) AS distinct_products
FROM sales_enriched
GROUP BY category, sub_category
ORDER BY total_profit ASC; -- low-profit categories first

-- 4. Inventory turnover proxy: average inventory_days vs profit_margin
SELECT category,
       sub_category,
       AVG(inventory_days) AS avg_inventory_days,
       AVG(profit_margin) AS avg_profit_margin,
       SUM(stock_on_hand) AS total_stock_on_hand
FROM sales_clean
GROUP BY category, sub_category
ORDER BY avg_inventory_days DESC;

-- 5. Identify slow-moving and overstocked items
-- Slow movers: high avg inventory_days but low sales velocity (sales qty per period)
WITH sales_velocity AS (
  SELECT product_id,
         product_name,
         category,
         sub_category,
         SUM(quantity) AS qty_sold,
         COUNT(DISTINCT order_date) AS active_days,
         AVG(inventory_days) AS avg_inventory_days,
         SUM(stock_on_hand) AS total_stock_on_hand
  FROM sales_clean
  GROUP BY product_id, product_name, category, sub_category
)
SELECT *,
       CASE
         WHEN avg_inventory_days > 90 AND qty_sold < 10 THEN 'Slow & Overstocked'
         WHEN avg_inventory_days > 60 AND qty_sold < 20 THEN 'Slow'
         ELSE 'Normal'
       END AS status
FROM sales_velocity
ORDER BY avg_inventory_days DESC;

-- 6. Seasonal analysis: monthly profit per category
SELECT date_trunc('month', order_date) AS month,
       category,
       SUM(profit) AS total_profit,
       AVG(profit_margin) AS avg_margin
FROM sales_enriched
GROUP BY month, category
ORDER BY month, category;

-- 7. Top loss-making products (largest negative profit)
SELECT product_id, product_name, category, sub_category, SUM(profit) AS total_profit
FROM sales_enriched
GROUP BY product_id, product_name, category, sub_category
HAVING SUM(profit) < 0
ORDER BY total_profit ASC
LIMIT 50;

-- 8. Recommendations helper: compute days to clear stock at avg sales rate
-- avg daily sales per product (over available data)
WITH daily_sales AS (
  SELECT product_id,
         SUM(quantity) / NULLIF(MAX(order_date) - MIN(order_date),0) AS avg_daily_sales,
         MAX(stock_on_hand) AS stock_on_hand
  FROM sales_clean
  GROUP BY product_id
)
SELECT product_id,
       stock_on_hand,
       avg_daily_sales,
       CASE WHEN avg_daily_sales > 0 THEN stock_on_hand / avg_daily_sales ELSE NULL END AS days_to_clear
FROM daily_sales
ORDER BY days_to_clear DESC NULLS LAST;
