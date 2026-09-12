-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## Gold: gold_receita_por_categoria
-- MAGIC Responde à pergunta 1: quais categorias geram mais receita e qual o ticket médio por categoria.

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.gold.gold_receita_por_categoria AS
SELECT
  p.categoria,
  COUNT(*) AS qtd_itens_vendidos,
  ROUND(SUM(f.valor_item), 2) AS receita_total,
  ROUND(AVG(f.valor_item), 2) AS ticket_medio
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos f
JOIN mvp_pos_puc_lucascruz.silver.dim_produtos p
  ON f.id_produto = p.id_produto
GROUP BY p.categoria
ORDER BY receita_total DESC;

-- COMMAND ----------

SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_receita_por_categoria LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Gold: gold_entrega_avaliacao
-- MAGIC Responde à pergunta 2: o tempo de entrega influencia a nota de avaliação do cliente?

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.gold.gold_entrega_avaliacao AS
SELECT
  nota_avaliacao,
  COUNT(*) AS qtd_pedidos,
  ROUND(AVG(DATEDIFF(data_entrega_real, data_pedido)), 1) AS media_dias_entrega
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos
WHERE data_entrega_real IS NOT NULL
  AND nota_avaliacao IS NOT NULL
GROUP BY nota_avaliacao
ORDER BY nota_avaliacao;

-- COMMAND ----------

SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_entrega_avaliacao;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Gold: gold_atraso_por_regiao
-- MAGIC Responde à pergunta 3: existe relação entre a região/estado do cliente e o atraso na entrega?

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.gold.gold_atraso_por_regiao AS
SELECT
  c.estado,
  COUNT(*) AS qtd_pedidos,
  ROUND(AVG(DATEDIFF(f.data_entrega_real, f.data_entrega_estimada)), 1) AS media_dias_atraso,
  SUM(CASE WHEN f.data_entrega_real > f.data_entrega_estimada THEN 1 ELSE 0 END) AS qtd_entregas_atrasadas,
  ROUND(100.0 * SUM(CASE WHEN f.data_entrega_real > f.data_entrega_estimada THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_atraso
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos f
JOIN mvp_pos_puc_lucascruz.silver.dim_clientes c
  ON f.id_cliente = c.id_cliente
WHERE f.data_entrega_real IS NOT NULL
GROUP BY c.estado
ORDER BY pct_atraso DESC;

-- COMMAND ----------

SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_atraso_por_regiao;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Gold: gold_pagamento_por_valor
-- MAGIC Responde à pergunta 4: qual o método de pagamento mais usado e ele varia por valor do pedido?

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.gold.gold_pagamento_por_valor AS
SELECT
  tipo_pagamento,
  COUNT(*) AS qtd_pedidos,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_do_total,
  ROUND(AVG(valor_item + valor_frete), 2) AS valor_medio_pedido,
  ROUND(AVG(num_parcelas), 1) AS media_parcelas
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos
WHERE tipo_pagamento IS NOT NULL
GROUP BY tipo_pagamento
ORDER BY qtd_pedidos DESC;

-- COMMAND ----------

SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_pagamento_por_valor;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Gold: gold_vendedor_avaliacao_volume
-- MAGIC Responde à pergunta 5: vendedores com mais avaliações positivas têm maior volume de vendas?

-- COMMAND ----------

CREATE OR REPLACE TABLE mvp_pos_puc_lucascruz.gold.gold_vendedor_avaliacao_volume AS
SELECT
  f.id_vendedor,
  COUNT(*) AS qtd_vendas,
  ROUND(SUM(f.valor_item), 2) AS receita_total,
  ROUND(AVG(f.nota_avaliacao), 2) AS media_avaliacao
FROM mvp_pos_puc_lucascruz.silver.fato_pedidos f
WHERE f.nota_avaliacao IS NOT NULL
GROUP BY f.id_vendedor
HAVING COUNT(*) >= 10
ORDER BY qtd_vendas DESC;

-- COMMAND ----------

SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_vendedor_avaliacao_volume LIMIT 20;