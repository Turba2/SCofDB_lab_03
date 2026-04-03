\timing on
\echo '=== APPLY INDEXES ==='

-- ============================================
-- Индексы под выбранные диагностические запросы
-- ============================================

-- Q1: быстро находить заказы пользователя уже в нужном порядке.
CREATE INDEX IF NOT EXISTS idx_orders_user_created_at_desc
    ON orders USING BTREE (user_id, created_at DESC);

-- Q2: частичный покрывающий индекс под paid-заказы по диапазону дат.
CREATE INDEX IF NOT EXISTS idx_orders_paid_created_at_desc
    ON orders USING BTREE (created_at DESC)
    INCLUDE (id, user_id, total_amount)
    WHERE status = 'paid';

-- Q3: фильтрация по created_at с последующим join по id.
CREATE INDEX IF NOT EXISTS idx_orders_created_at_id
    ON orders USING BTREE (created_at, id);

-- Q3: внешний ключ не создаёт индекс автоматически, поэтому ускоряем join
-- из отфильтрованного набора orders к order_items.
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items USING BTREE (order_id);

-- Не забудьте обновить статистику после создания индексов
ANALYZE;
