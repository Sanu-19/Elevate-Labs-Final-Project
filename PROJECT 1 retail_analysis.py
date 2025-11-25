
# retail_analysis.py
# Python (Pandas) script for correlation between inventory_days and profitability,
# plus sample plots and outputs.
# Assumes a CSV file 'sales.csv' with columns:
# order_id, order_date, region, category, sub_category, product_id, product_name,
# quantity, unit_price, cost_price, inventory_days, stock_on_hand

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Load data
df = pd.read_csv('sales.csv', parse_dates=['order_date'])

# Basic cleaning
df = df.dropna(subset=['order_id','order_date','product_id','quantity','unit_price','cost_price'])
df['revenue'] = df['quantity'] * df['unit_price']
df['cost'] = df['quantity'] * df['cost_price']
df['profit'] = df['revenue'] - df['cost']
df['profit_margin'] = np.where(df['revenue'] == 0, 0, df['profit'] / df['revenue'])

# Aggregate by product
prod = df.groupby(['product_id','product_name','category','sub_category']).agg(
    total_qty_sold = ('quantity','sum'),
    total_revenue = ('revenue','sum'),
    total_cost = ('cost','sum'),
    total_profit = ('profit','sum'),
    avg_margin = ('profit_margin','mean'),
    avg_inventory_days = ('inventory_days','mean'),
    avg_stock_on_hand = ('stock_on_hand','mean')
).reset_index()

# Correlation between avg_inventory_days and avg_margin
corr = prod[['avg_inventory_days','avg_margin']].corr().iloc[0,1]
print(f"Pearson correlation between inventory days and profit margin: {corr:.3f}")

# Scatter plot
plt.figure(figsize=(8,5))
plt.scatter(prod['avg_inventory_days'], prod['avg_margin'])
plt.xlabel('Average Inventory Days')
plt.ylabel('Average Profit Margin')
plt.title('Inventory Days vs Profit Margin')
plt.grid(True)
plt.tight_layout()
plt.savefig('inventory_vs_margin.png')
print('Saved plot to inventory_vs_margin.png')

# Identify slow-moving overstocked items
slow_overstock = prod[(prod['avg_inventory_days'] > 60) & (prod['total_qty_sold'] < 20)]
slow_overstock = slow_overstock.sort_values('avg_inventory_days', ascending=False)
slow_overstock.to_csv('slow_overstock.csv', index=False)
print('Saved slow/overstocked items to slow_overstock.csv')
