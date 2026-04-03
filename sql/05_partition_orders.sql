\timing on
\echo '=== PARTITION ORDERS BY DATE ==='

-- ============================================
-- Реализация через shadow-table orders_partitioned,
-- чтобы не ломать внешние ключи исходной OLTP-схемы.
-- ============================================

DROP TABLE IF EXISTS orders_partitioned CASCADE;

CREATE TABLE orders_partitioned (
    id UUID NOT NULL,
    user_id UUID NOT NULL,
    status TEXT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_partitioned_2024_q1 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2024-01-01 00:00:00+00') TO ('2024-04-01 00:00:00+00');
CREATE TABLE orders_partitioned_2024_q2 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2024-04-01 00:00:00+00') TO ('2024-07-01 00:00:00+00');
CREATE TABLE orders_partitioned_2024_q3 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2024-07-01 00:00:00+00') TO ('2024-10-01 00:00:00+00');
CREATE TABLE orders_partitioned_2024_q4 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2024-10-01 00:00:00+00') TO ('2025-01-01 00:00:00+00');
CREATE TABLE orders_partitioned_2025_q1 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
CREATE TABLE orders_partitioned_2025_q2 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-07-01 00:00:00+00');
CREATE TABLE orders_partitioned_2025_q3 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+00') TO ('2025-10-01 00:00:00+00');
CREATE TABLE orders_partitioned_2025_q4 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');
CREATE TABLE orders_partitioned_default PARTITION OF orders_partitioned
    DEFAULT;

INSERT INTO orders_partitioned (id, user_id, status, total_amount, created_at)
SELECT id, user_id, status, total_amount, created_at
FROM orders;

SELECT 'orders_original' AS table_name, count(*) AS rows_count FROM orders
UNION ALL
SELECT 'orders_partitioned', count(*) FROM orders_partitioned;

CREATE INDEX idx_orders_part_user_created_at_desc
    ON orders_partitioned USING BTREE (user_id, created_at DESC);
CREATE INDEX idx_orders_part_paid_created_at_desc
    ON orders_partitioned USING BTREE (created_at DESC)
    INCLUDE (id, user_id, total_amount)
    WHERE status = 'paid';
CREATE INDEX idx_orders_part_created_at_id
    ON orders_partitioned USING BTREE (created_at, id);

ANALYZE orders_partitioned;

SELECT
    inhrelid::regclass AS partition_name,
    reltuples::bigint AS estimated_rows
FROM pg_inherits
JOIN pg_class ON pg_class.oid = inhrelid
WHERE inhparent = 'orders_partitioned'::regclass
ORDER BY partition_name;
