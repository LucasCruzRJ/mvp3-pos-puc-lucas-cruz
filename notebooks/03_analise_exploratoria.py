# Databricks notebook source
# Configuração inicial
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

sns.set_style("whitegrid")

# Carregando as tabelas Gold direto para Pandas
df_categoria = spark.sql("SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_receita_por_categoria").toPandas()
df_entrega = spark.sql("SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_entrega_avaliacao").toPandas()
df_regiao = spark.sql("SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_atraso_por_regiao").toPandas()
df_pagamento = spark.sql("SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_pagamento_por_valor").toPandas()
df_vendedor = spark.sql("SELECT * FROM mvp_pos_puc_lucascruz.gold.gold_vendedor_avaliacao_volume").toPandas()

# COMMAND ----------

df_categoria_labels = spark.sql("""
    SELECT
      g.*,
      t.product_category_name AS categoria_original
    FROM mvp_pos_puc_lucascruz.gold.gold_receita_por_categoria g
    LEFT JOIN mvp_pos_puc_lucascruz.bronze.bronze_category_translation t
      ON g.categoria = t.product_category_name_english
""").toPandas()

# COMMAND ----------

# Dicionário de formatação — só para exibição no gráfico
nomes_legiveis = {
    "esporte_lazer": "Esporte/Lazer",
    "moveis_decoracao": "Móveis/Decoração",
    "beleza_saude": "Beleza/Saúde",
    "relogios_presentes": "Relógios/Presentes",
    "cama_mesa_banho": "Cama/Mesa/Banho",
    "informatica_acessorios": "Informática/Acessórios",
    "casa_conforto": "Casa/Conforto",
    "automotivo": "Automotivo",
    "ferramentas_jardim": "Ferramentas/Jardim",
}

df_categoria_labels["label_pt"] = df_categoria_labels["categoria_original"].map(nomes_legiveis).fillna(df_categoria_labels["categoria_original"])

plt.figure(figsize=(10, 6))
top10 = df_categoria_labels.head(10)
sns.barplot(data=top10, y="label_pt", x="receita_total", palette="viridis")
plt.title("Receita total por categoria (Top 10)")
plt.xlabel("Receita total (R$)")
plt.ylabel("Categoria")
plt.tight_layout()
plt.show()

# COMMAND ----------

plt.figure(figsize=(8, 5))
sns.barplot(data=df_entrega, x="nota_avaliacao", y="media_dias_entrega", palette="rocket")
plt.title("Tempo médio de entrega por nota de avaliação")
plt.xlabel("Nota de avaliação")
plt.ylabel("Média de dias para entrega")
plt.tight_layout()
plt.show()

# COMMAND ----------

correlacao = df_entrega["nota_avaliacao"].corr(df_entrega["media_dias_entrega"])
print(f"Correlação entre nota e tempo de entrega: {correlacao:.2f}")

# COMMAND ----------

plt.figure(figsize=(10, 8))
df_regiao_sorted = df_regiao.sort_values("pct_atraso", ascending=False)
sns.barplot(data=df_regiao_sorted, y="estado", x="pct_atraso", palette="mako")
plt.title("Percentual de entregas atrasadas por estado")
plt.xlabel("% de pedidos atrasados")
plt.ylabel("Estado (UF)")
plt.tight_layout()
plt.show()

# COMMAND ----------

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

sns.barplot(data=df_pagamento, x="tipo_pagamento", y="pct_do_total", ax=axes[0], palette="crest")
axes[0].set_title("Participação de cada método de pagamento (%)")
axes[0].set_xlabel("Método de pagamento")
axes[0].set_ylabel("% do total de pedidos")

sns.barplot(data=df_pagamento, x="tipo_pagamento", y="valor_medio_pedido", ax=axes[1], palette="crest")
axes[1].set_title("Valor médio do pedido por método de pagamento")
axes[1].set_xlabel("Método de pagamento")
axes[1].set_ylabel("Valor médio (R$)")

plt.tight_layout()
plt.show()

# COMMAND ----------

plt.figure(figsize=(8, 6))
sns.scatterplot(data=df_vendedor, x="qtd_vendas", y="media_avaliacao", alpha=0.5)
plt.title("Volume de vendas x média de avaliação por vendedor")
plt.xlabel("Quantidade de vendas")
plt.ylabel("Média de avaliação")
plt.tight_layout()
plt.show()

# COMMAND ----------

print(df_vendedor["qtd_vendas"].min())

# COMMAND ----------

correlacao_vendedor = df_vendedor["qtd_vendas"].corr(df_vendedor["media_avaliacao"])
print(f"Correlação entre volume de vendas e média de avaliação: {correlacao_vendedor:.2f}")