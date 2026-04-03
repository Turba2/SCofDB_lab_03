\timing on
\echo '=== BEFORE OPTIMIZATION ==='

-- Рекомендуемые настройки для сравнимых замеров
SET max_parallel_workers_per_gather = 0;
SET work_mem = '32MB';
ANALYZE;

-- ============================================
-- Набор запросов для диагностики:
-- Q1: история заказов самого активного пользователя
-- Q2: paid-заказы за период с сортировкой по дате
-- Q3: join orders + order_items с агрегированием по выручке
-- Q4: полный агрегат по месяцам и статусам (сложно ускорить только индексами)
-- ============================================

\echo '--- Q1: Фильтрация + сортировка (пример класса запроса) ---'
EXPLAIN (ANALYZE, BUFFERS)
WITH busiest_user AS (
    SELECT user_id
    FROM orders
    GROUP BY user_id
    ORDER BY count(*) DESC, user_id
    LIMIT 1
)
SELECT
    id,
    user_id,
    status,
    total_amount,
    created_at
FROM orders
WHERE user_id = (SELECT user_id FROM busiest_user)
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Q2: Фильтрация по статусу + диапазону дат ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    id,
    user_id,
    total_amount,
    created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-01-01 00:00:00+00'
  AND created_at < TIMESTAMPTZ '2025-04-01 00:00:00+00'
ORDER BY created_at DESC
LIMIT 100;

\echo '--- Q3: JOIN + GROUP BY ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    oi.product_name,
    count(*) AS items_count,
    round(sum(oi.subtotal)::numeric, 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.created_at >= TIMESTAMPTZ '2025-07-01 00:00:00+00'
  AND o.created_at < TIMESTAMPTZ '2025-10-01 00:00:00+00'
GROUP BY oi.product_name
ORDER BY revenue DESC
LIMIT 20;

\echo '--- Q4: Полный агрегат по всему диапазону ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('month', created_at) AS month_bucket,
    status,
    count(*) AS orders_count,
    round(sum(total_amount)::numeric, 2) AS revenue
FROM orders
GROUP BY 1, 2
ORDER BY 1, 2;
