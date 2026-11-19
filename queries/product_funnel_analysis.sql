-- ============================================================================
-- 1. Product Catalog & Pricing Audit
-- ============================================================================
SELECT 
  product_id,
  COUNT(*) AS total_orders,
  ROUND(MIN(amount), 2) AS min_price,
  ROUND(AVG(amount), 2) AS avg_order_amount,
  ROUND(MAX(amount), 2) AS max_price,
  ROUND(SUM(amount), 2) AS total_revenue
FROM `project.dataset.user_events`
WHERE event_type = 'purchase'
GROUP BY product_id
ORDER BY total_revenue DESC;


-- ============================================================================
-- 2. Product-Level Conversion Funnel
-- ============================================================================
WITH product_funnel AS (
  SELECT 
    product_id,
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS views,
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS carts,
    COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS checkouts,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchases
  FROM `project.dataset.user_events`
  GROUP BY product_id
)
SELECT 
  product_id,
  views,
  carts,
  purchases,
  ROUND(SAFE_DIVIDE(carts, views) * 100, 2) AS view_to_cart_pct,
  ROUND(SAFE_DIVIDE(purchases, carts) * 100, 2) AS cart_to_purchase_pct,
  ROUND(SAFE_DIVIDE(purchases, views) * 100, 2) AS overall_conversion_pct
FROM product_funnel
ORDER BY overall_conversion_pct DESC;


-- ============================================================================
-- 3. Cart Abandonment & Lost Revenue Valuation
-- ============================================================================
WITH product_prices AS (
  -- Calculate the average order value per product from completed purchases
  SELECT 
    product_id,
    AVG(amount) AS avg_product_value
  FROM `project.dataset.user_events`
  WHERE event_type = 'purchase'
  GROUP BY product_id
),
user_product_status AS (
  -- Flag each user-product pair by their furthest funnel action
  SELECT 
    user_id,
    product_id,
    MAX(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS added_to_cart,
    MAX(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) AS started_checkout,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
  FROM `project.dataset.user_events`
  GROUP BY user_id, product_id
)
SELECT 
  u.product_id,
  SUM(CASE WHEN u.added_to_cart = 1 AND u.purchased = 0 THEN 1 ELSE 0 END) AS abandoned_carts,
  SUM(CASE WHEN u.started_checkout = 1 AND u.purchased = 0 THEN 1 ELSE 0 END) AS abandoned_checkouts,
  ROUND(p.avg_product_value, 2) AS avg_item_value,
  ROUND(
    SUM(CASE WHEN u.added_to_cart = 1 AND u.purchased = 0 THEN 1 ELSE 0 END) * p.avg_product_value, 
    2
  ) AS estimated_lost_revenue
FROM user_product_status u
JOIN product_prices p 
  ON u.product_id = p.product_id
GROUP BY u.product_id, p.avg_product_value
ORDER BY estimated_lost_revenue DESC;
