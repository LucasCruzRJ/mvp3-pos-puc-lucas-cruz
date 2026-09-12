-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## Transformação Bronze → Silver: fato_pedidos
-- MAGIC Objetivo: consolidar dados de pedidos, itens, pagamentos e avaliações
-- MAGIC em uma única tabela no grão "item de pedido", com nomes em português
-- MAGIC e tipos corrigidos.

-- COMMAND ----------

SELECT * FROM mvp_pos_puc_lucascruz.bronze.bronze_orders LIMIT 5;

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.silver.fato_pedidos AS
SELECT
  oi.order_id            AS id_pedido,
  o.customer_id           AS id_cliente,
  oi.seller_id            AS id_vendedor,
  oi.product_id           AS id_produto,
  pg.payment_type         AS tipo_pagamento,
  pg.payment_installments AS num_parcelas,
  CAST(o.order_purchase_timestamp AS DATE) AS data_pedido,
  oi.price                AS valor_item,
  oi.freight_value        AS valor_frete,
  CAST(o.order_estimated_delivery_date AS DATE) AS data_entrega_estimada,
  CAST(o.order_delivered_customer_date AS DATE) AS data_entrega_real,
  r.review_score           AS nota_avaliacao
FROM mvp_pos_puc_lucascruz.bronze.bronze_order_items oi
JOIN mvp_pos_puc_lucascruz.bronze.bronze_orders o
  ON oi.order_id = o.order_id
LEFT JOIN (
  -- um pedido pode ter mais de um pagamento; pego o de maior valor como principal
  SELECT order_id, payment_type, payment_installments,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_value DESC) AS rn
  FROM mvp_pos_puc_lucascruz.bronze.bronze_order_payments
) pg ON oi.order_id = pg.order_id AND pg.rn = 1
LEFT JOIN mvp_pos_puc_lucascruz.bronze.bronze_order_reviews r
  ON oi.order_id = r.order_id;

-- COMMAND ----------

SELECT COUNT(*) AS total_linhas FROM mvp_pos_puc_lucascruz.silver.fato_pedidos;
SELECT * FROM mvp_pos_puc_lucascruz.silver.fato_pedidos LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Transformação Bronze → Silver: dim_clientes
-- MAGIC Objetivo: consolidar dados únicos de cliente (id, cidade, estado),
-- MAGIC com nomes em português, a partir da tabela bruta de clientes.

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.silver.dim_clientes AS
SELECT DISTINCT
  customer_id AS id_cliente,
  customer_city AS cidade,
  customer_state AS estado
FROM mvp_pos_puc_lucascruz.bronze.bronze_customers;

-- COMMAND ----------

SELECT COUNT(*) FROM mvp_pos_puc_lucascruz.silver.dim_clientes;
SELECT * FROM mvp_pos_puc_lucascruz.silver.dim_clientes LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Transformação Bronze → Silver: dim_vendedores
-- MAGIC Objetivo: consolidar dados únicos de vendedor (id, cidade, estado).

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.silver.dim_vendedores AS
SELECT DISTINCT
  seller_id AS id_vendedor,
  seller_city AS cidade,
  seller_state AS estado
FROM mvp_pos_puc_lucascruz.bronze.bronze_sellers;

-- COMMAND ----------

SELECT COUNT(*) FROM mvp_pos_puc_lucascruz.silver.dim_vendedores;
SELECT * FROM mvp_pos_puc_lucascruz.silver.dim_vendedores LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Transformação Bronze → Silver: dim_produtos
-- MAGIC Objetivo: consolidar produtos com a categoria já traduzida para português,
-- MAGIC usando a tabela de tradução de categorias.

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.silver.dim_produtos AS
SELECT
  p.product_id AS id_produto,
  COALESCE(t.product_category_name_english, p.product_category_name) AS categoria
FROM mvp_pos_puc_lucascruz.bronze.bronze_products p
LEFT JOIN mvp_pos_puc_lucascruz.bronze.bronze_category_translation t
  ON p.product_category_name = t.product_category_name;

-- COMMAND ----------

SELECT COUNT(*) FROM mvp_pos_puc_lucascruz.silver.dim_produtos;
SELECT * FROM mvp_pos_puc_lucascruz.silver.dim_produtos LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Qualidade de Dados: fato_pedidos
-- MAGIC Verificação de nulos, duplicatas e valores fora do esperado.

-- COMMAND ----------

SELECT
  COUNT(*) AS total_linhas,
  SUM(CASE WHEN id_cliente IS NULL THEN 1 ELSE 0 END) AS nulos_cliente,
  SUM(CASE WHEN id_vendedor IS NULL THEN 1 ELSE 0 END) AS nulos_vendedor,
  SUM(CASE WHEN id_produto IS NULL THEN 1 ELSE 0 END) AS nulos_produto,
  SUM(CASE WHEN valor_item IS NULL THEN 1 ELSE 0 END) AS nulos_valor,
  SUM(CASE WHEN data_entrega_real IS NULL THEN 1 ELSE 0 END) AS nulos_entrega_real,
  SUM(CASE WHEN nota_avaliacao IS NULL THEN 1 ELSE 0 END) AS nulos_avaliacao
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos;

-- COMMAND ----------

SELECT id_pedido, id_produto, COUNT(*) AS qtd
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos
GROUP BY id_pedido, id_produto
HAVING COUNT(*) > 1;

-- COMMAND ----------

SELECT id_pedido, id_produto, COUNT(*) AS qtd
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos
GROUP BY id_pedido, id_produto
HAVING COUNT(*) > 1
ORDER BY qtd DESC
LIMIT 5;

-- COMMAND ----------

SELECT *
FROM mvp_pos_puc_lucascruz.bronze.bronze_order_items
WHERE order_id = 'ab14fdcfbe524636d65ee38360e22ce8'
  AND product_id = '9571759451b1d780ee7c15012ea109d4';

-- COMMAND ----------

SELECT
  MIN(valor_item) AS min_valor, MAX(valor_item) AS max_valor,
  MIN(valor_frete) AS min_frete, MAX(valor_frete) AS max_frete,
  MIN(nota_avaliacao) AS min_nota, MAX(nota_avaliacao) AS max_nota
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos;

-- COMMAND ----------

SELECT COUNT(*) AS entregas_antes_do_pedido
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos
WHERE data_entrega_real < data_pedido;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Qualidade de Dados: dim_clientes

-- COMMAND ----------

SELECT
  COUNT(*) AS total_linhas,
  COUNT(DISTINCT id_cliente) AS ids_unicos,
  SUM(CASE WHEN cidade IS NULL THEN 1 ELSE 0 END) AS nulos_cidade,
  SUM(CASE WHEN estado IS NULL THEN 1 ELSE 0 END) AS nulos_estado,
  COUNT(DISTINCT estado) AS qtd_estados_distintos
FROM mvp_pos_puc_lucascruz.silver.dim_clientes;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Qualidade de Dados: dim_vendedores

-- COMMAND ----------

SELECT
  COUNT(*) AS total_linhas,
  COUNT(DISTINCT id_vendedor) AS ids_unicos,
  SUM(CASE WHEN cidade IS NULL THEN 1 ELSE 0 END) AS nulos_cidade,
  SUM(CASE WHEN estado IS NULL THEN 1 ELSE 0 END) AS nulos_estado,
  COUNT(DISTINCT estado) AS qtd_estados_distintos
FROM mvp_pos_puc_lucascruz.silver.dim_vendedores;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Qualidade de Dados: dim_produtos

-- COMMAND ----------

SELECT
  COUNT(*) AS total_linhas,
  COUNT(DISTINCT id_produto) AS ids_unicos,
  SUM(CASE WHEN categoria IS NULL THEN 1 ELSE 0 END) AS nulos_categoria,
  COUNT(DISTINCT categoria) AS qtd_categorias_distintas
FROM mvp_pos_puc_lucascruz.silver.dim_produtos;

-- COMMAND ----------

SELECT
  SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS sem_categoria_na_origem,
  COUNT(*) AS total
FROM mvp_pos_puc_lucascruz.bronze.bronze_products;

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.silver.dim_produtos AS
SELECT
  p.product_id AS id_produto,
  COALESCE(t.product_category_name_english, p.product_category_name, 'nao_informado') AS categoria
FROM mvp_pos_puc_lucascruz.bronze.bronze_products p
LEFT JOIN mvp_pos_puc_lucascruz.bronze.bronze_category_translation t
  ON p.product_category_name = t.product_category_name;

-- COMMAND ----------

SELECT COUNT(*) FROM mvp_pos_puc_lucascruz.silver.dim_produtos WHERE categoria IS NULL;