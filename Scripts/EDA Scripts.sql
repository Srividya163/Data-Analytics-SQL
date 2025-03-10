-- EXPLPORATORY DATA ANALYSIS PROJECT
-- 1.Datavbase Exploration
-- 2.Dimensions Exploration
-- 3.Date Exploration
-- 4.Measures Exploration
-- 5.Magnitude
-- 6.Ranking Analysis

/*
===============================================================================
Database Exploration
===============================================================================
Purpose:
    - To explore the structure of the database, including the list of tables and their schemas.
    - To inspect the columns and metadata for specific tables.

Table Used:
    - INFORMATION_SCHEMA.TABLES
    - INFORMATION_SCHEMA.COLUMNS
===============================================================================
*/
select count(*) from information_schema.tables
where table_schema='datawarehouseanalysis';

select table_name from information_schema.tables
where table_schema='datawarehouseanalysis';

select column_name,data_type from information_schema.columns;

select column_nmae,data_type from information_schema.columns
where table_name='dim_customers';

-- 2.Dimensions Exploration

/*
===============================================================================
Dimensions Exploration
===============================================================================
Purpose:
    - To explore the structure of dimension tables.
	
SQL Functions Used:
    - DISTINCT
    - ORDER BY
===============================================================================
*/
select distinct country from dim_customers;

-- Explore all categories "The major divisions"
select distinct category,subcategory from dim_products;

select DISTINCT category,subcategory,product_name from dim_products
order by 1,2,3; 

-- 3.Date Exploration
/*
===============================================================================
Date Range Exploration 
===============================================================================
Purpose:
    - To determine the temporal boundaries of key data points.
    - To understand the range of historical data.

SQL Functions Used:
    - MIN(), MAX(), DATEDIFF()
===============================================================================
*/
-- Find the date of the first and last order
SELECT 
min(order_date) as first_order_date,
max(order_date) as last_order_date,
timestampdiff(month, MIN(order_date), max(order_date)) as order_range_months
from fact_sales;

-- Find the youngest and the oldest customer
select 
    min(birthdate) as oldest_birthdate,
    timestampdiff(year,(select min(birthdate) from dim_customers),curdate()) AS oldest_age,
    max(birthdate) as youngest_birthdate,
    timestampdiff(year,(select max(birthdate) from dim_customers),curdate()) as young_age 
from dim_customers;

-- 4.Measures Exploration
/*
===============================================================================
Measures Exploration (Key Metrics)
===============================================================================
Purpose:
    - To calculate aggregated metrics (e.g., totals, averages) for quick insights.
    - To identify overall trends or spot anomalies.

SQL Functions Used:
    - COUNT(), SUM(), AVG()
===============================================================================
*/

-- Find the Total sales
select sum(sales_amount) as total_sales from fact_sales;

-- Find how many items are sold
select sum(quantity) as total_quantity from fact_sales;

-- Find the average selling price
select round(avg(price),2) as avg_price from fact_sales;
select * from fact_sales;

-- Find the Total number of orders
select count(order_number) as total_orders from fact_sales;
select count(distinct order_number) as total_orders from fact_sales;

-- Find the Total number of products
select count(product_name) as total_products from dim_products;
select count(distinct product_name) as total_products from dim_products;

-- Find the Total number of customers
select count(customer_key) as total_customers from dim_customers;

-- Find the Total number of customers that has placed an order
select count(distinct customer_key) as total_customers from fact_sales;

-- Generate a report that shows all key metrics of the business
select 'Total Sales' as measure_name , sum(sales_amount) as measure_value from fact_sales
UNION ALL
select 'Total Quantity',sum(quantity) from fact_sales
UNION ALL
select 'Avg Price',round(avg(price),2) from fact_sales
UNION ALL
select 'Total Nm. Orders',count(distinct order_number) from fact_sales
UNION ALL
select 'Total Nm.Products',count(distinct product_name) from dim_products
UNION ALL
select 'Total Nm.customers' ,count(distinct customer_key)  from fact_sales;

-- 5.Magnitude
/*
===============================================================================
Magnitude Analysis
===============================================================================
Purpose:
    - To quantify data and group results by specific dimensions.
    - For understanding data distribution across categories.

SQL Functions Used:
    - Aggregate Functions: SUM(), COUNT(), AVG()
    - GROUP BY, ORDER BY
===============================================================================
*/

-- Find total customer by countries
select country,
       count(customer_key) as total_customer
from dim_customers
group by country
order by 2 desc;

-- Find total customers by gender
select gender,
       count(customer_key) as tptal_customers
from dim_customers
group by gender;

-- Find total products by category
select category,
	   count(product_key) as total_products
from dim_products
group by category
order by total_products desc;

-- What is the average costs in each category?
select category,
	avg(cost) as avg_costs
from dim_products
group by category
order by avg_costs desc;

-- What is the total revenue generated for each category
select 
	d.category,
	sum(f.sales_amount) as total_revenue
from fact_sales f
left join dim_products d on f.product_key=d.product_key
group by d.category
order by total_revenue desc;
 
-- Find total revenue is generated by each customer
select 
      c.customer_key,
      c.first_name,
      c.last_name,
      sum(f.sales_amount) as total_revenue
from fact_sales f
left Join dim_customers c on f.customer_key=c.customer_key
group by c.customer_key,
c.first_name,
c.last_name
order by total_revenue desc;

-- What is the distribution of sold items across countries
select 
      c.country,
      sum(f.quantity) as total_sold_items
from fact_sales f
left Join dim_customers c on f.customer_key=c.customer_key
group by country
order by total_sold_items desc;

-- 6.Ranking Analysis
/*
===============================================================================
Ranking Analysis
===============================================================================
Purpose:
    - To rank items (e.g., products, customers) based on performance or other metrics.
    - To identify top performers or laggards.

SQL Functions Used:
    - Window Ranking Functions: RANK(), DENSE_RANK(), ROW_NUMBER(), TOP
    - Clauses: GROUP BY, ORDER BY
===============================================================================
*/

-- Which 5 products generate the highest revenue?
with ranked_products as(
select 
	d.product_name,
	sum(f.sales_amount) as total_revenue,
    row_number() over(order by sum(f.sales_amount) desc) rank_product
from fact_sales f
left join dim_products d on f.product_key=d.product_key
group by d.product_name)
select * from ranked_products where rank_product<=5;

-- What are the 5 worst-performing products in terms of sales?
with rank_worst_products as (
select  
	d.product_name,
	sum(f.sales_amount) as total_revenue,
    row_number() over(order by sum(f.sales_amount)) rank_product
from fact_sales f
left join dim_products d on f.product_key=d.product_key
group by d.product_name)
select * from rank_worst_products where rank_product<=5;

-- Find the top 10 customers who have generated the highest revenue?
select 
      c.customer_key,
      c.first_name,
      c.last_name,
      sum(f.sales_amount) as total_revenue
from fact_sales f
left Join dim_customers c on f.customer_key=c.customer_key
group by c.customer_key,
c.first_name,
c.last_name
order by total_revenue desc limit 10;

-- The 3 customers with the fewest orders placed?
select 
      c.customer_key,
      c.first_name,
      c.last_name,
      count(Distinct order_number) as total_orders
from fact_sales f
left Join dim_customers c on f.customer_key=c.customer_key
group by c.customer_key,
c.first_name,
c.last_name
order by total_orders limit 3;





























