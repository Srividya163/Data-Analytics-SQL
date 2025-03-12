-- Data Analysis Project
/*
===============================================================================
1).Change Over Time Analysis
===============================================================================
Purpose:
    - To track trends, growth, and changes in key metrics over time.
    - For time-series analysis and identifying seasonality.
    - To measure growth or decline over specific periods.

SQL Functions Used:
    - Date Functions: DATEPART(), DATETRUNC(), FORMAT()
    - Aggregate Functions: SUM(), COUNT(), AVG()
===============================================================================
*/
-- analyze sales Performance over time
select order_date,
	   sum(sales_amount) total_sales
from fact_sales
where order_date is not null
group by order_date
order by order_date;

-- analyze total sales by year
select year(order_date) order_year,
       sum(sales_amount) total_sales,
       count(distinct customer_key) as total_customers,
       sum(quantity) as total_sales
from fact_sales
where order_date is not null
group by year(order_date)
order by year(order_date);

-- analyze total sales by month
select year(order_date) order_year,
       month(order_date) order_month,
       sum(sales_amount) total_sales,
       count(distinct customer_key) as total_customers,
       sum(quantity) as total_sales
from fact_sales
where order_date is not null
group by year(order_date),month(order_date)
order by year(order_date),month(order_date);

-- How many new customers weere added each year
select date_format(Order_date,'%y-%M') as create_year,
       count(distinct customer_key) as total_customers
from fact_sales
where order_date is not null
group by date_format(Order_date,'%y-%M')
order by date_format(Order_date,'%y-%M');

/*
===============================================================================
2).Cumulative Analysis
===============================================================================
Purpose:
    - To calculate running totals or moving averages for key metrics.
    - To track performance over time cumulatively.
    - Useful for growth analysis or identifying long-term trends.

SQL Functions Used:
    - Window Functions: SUM() OVER(), AVG() OVER()
===============================================================================
*/
-- Calculate the total sales per month
-- and the running total of sales over time
select order_date,
       total_sales,
       sum(total_sales) over(partition by order_date order by order_date) as running_total_sales,
	   avg(avg_price) over(partition by order_date order by order_date) as moving_average_price
from
(select date_format(order_date,'%Y-%m-01') as order_date,
       sum(sales_amount) as total_sales,
       round(avg(price),0) as avg_price
from fact_sales
where order_date is not null
group by date_format(order_date,'%Y-%m-01')
order by order_date) t;

-- Using CTE cumulative analysis by year
with sales_data as
	(select ANY_VALUE(order_date) as order_date,
		  year(order_date) as order_year,
		   sum(sales_amount) as total_sales,
		   round(avg(price),0) as avg_price
	from fact_sales
	where order_date is not null
	group by year(order_date) 
	order by order_date) 
select order_date,
       order_year,
       total_sales,
sum(total_sales) over(partition by order_date order by order_date) as running_total_sales,
avg(avg_price) over(partition by order_date order by order_date) as moving_average_price
from sales_data
order by order_year;

/*
===============================================================================
3).Performance Analysis (Year-over-Year, Month-over-Month)
===============================================================================
Purpose:
    - To measure the performance of products, customers, or regions over time.
    - For benchmarking and identifying high-performing entities.
    - To track yearly trends and growth.

SQL Functions Used:
    - LAG(): Accesses data from previous rows.
    - AVG() OVER(): Computes average values within partitions.
    - CASE: Defines conditional logic for trend analysis.
===============================================================================
*/

/*analyze the yearly performance of products by comparing their sales to both the
average sales performance of the product and the previous year's sales */

with yearly_product_sales as(
select 
year(f.order_date) as order_year,
p.product_name,
sum(f.sales_amount) as current_sales
from fact_sales f
left join dim_products p 
on f.product_key=p.product_key
where order_date is not null
group by year(f.order_date),p.product_name)
select 
order_year,
product_name,
current_sales,
avg(current_sales) over(partition by product_name) as avg_sales ,
current_sales-avg(current_sales) over(partition by product_name) as diff_avg,
case when current_sales-avg(current_sales) over(partition by product_name) >0 then 'Above avg'
     when current_sales-avg(current_sales) over(partition by product_name) <0 then 'Below avg'
     else 'Avg'
end avg_change,
-- comapare the current sales with the previous sales by using window function
-- YEAR-TO-YEAR CHANGE
LAG(current_sales) over(PARTITION BY product_name ORDER BY order_year) as py_sales,
current_sales-LAG(current_sales) over(PARTITION BY product_name ORDER BY order_year) as diff_py,
case when current_sales-LAG(current_sales) over(PARTITION BY product_name ORDER BY order_year) >0 then 'Increase'
     when current_sales-LAG(current_sales) over(PARTITION BY product_name ORDER BY order_year) <0 then 'Decrease'
     else 'No change'
end py_change
from yearly_product_sales; 

/*
===============================================================================
4).Part-to-Whole Analysis
===============================================================================
Purpose:
    - To compare performance or metrics across dimensions or time periods.
    - To evaluate differences between categories.
    - Useful for A/B testing or regional comparisons.

SQL Functions Used:
    - SUM(), AVG(): Aggregates values for comparison.
    - Window Functions: SUM() OVER() for total calculations.
===============================================================================
*/

-- which categories contribute the most to overall sales?
with category_sales as (
select 
category,
sum(sales_amount) total_sales
from fact_sales f 
left join dim_products p
on p.product_key=f.product_key
group by category)
select 
category,
total_sales,
sum(total_sales) over() as overall_sales,
concat(round((total_sales/sum(total_sales) over())*100,2),'%') as percentage_of_total
from category_sales
Order by total_sales desc;

/*
===============================================================================
5).Data Segmentation Analysis
===============================================================================
Purpose:
    - To group data into meaningful categories for targeted insights.
    - For customer segmentation, product categorization, or regional analysis.

SQL Functions Used:
    - CASE: Defines custom segmentation logic.
    - GROUP BY: Groups data into segments.
===============================================================================
*/

/* Segment products into cost ranges and 
count how many products fall into each segment*/
with product_segment as (
select 
product_key,
product_name,
cost,
case when cost<100 then 'Below 100'
     when cost between 100 and 500 then '100-500'
     when cost between 500 and 1000 then '500-1000'
     else 'Above 1000'
end cost_range
from dim_products)
select 
cost_range,
count(product_key) as total_products
from product_segment
group by cost_range
order by total_products desc;

/*Group customers into three segments based on their spending behavior:
    -VIP: Customers with at least 12 months of history and spending more time than $5,000. 
    -Regular: Customers with at leats 12 months of history but spending $5000 or less.
    -New: Customers with at lifespan less than 12 months.
And find the total number of customers by each group*/

with customer_spending as (
select 
c.customer_key,
sum(f.sales_amount) as total_spending,
min(order_date) as first_order,
max(order_date) as last_order,
timestampdiff(month,min(order_date),max(order_date)) as lifespan
from fact_sales f 
left join dim_customers c on f.customer_key=c.customer_key
group by c.customer_key)
select 
customer_segment,
count(customer_key) as total_customers
from(
select 
customer_key,
case when lifespan>=12 and total_spending >5000 then 'VIP'
     when lifespan>=12 and total_spending<=5000 then 'Regular'
     else 'New'
end customer_segment
from customer_spending) t
group by customer_segment
order by total_customers desc;

-- 6.Data Reporting
/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend
===============================================================================
*/
CREATE VIEW report_customers as
with base_query as(
/* =============================================================================
1) Base Query: Retrieves core columns from tables
 ============================================================================= */
 select 
 f.order_number,
 f.product_key,
 f.order_date,
 f.sales_amount,
 f.quantity,
 c.customer_key,
 c.customer_number,
 c.first_name,
 c.last_name,
 c.birthdate,
 concat(c.first_name,' ', c.last_name) as customer_name,
 timestampdiff(year,c.birthdate,curdate()) as age
 from fact_sales f 
 left join dim_customers c 
 on f.customer_key=c.customer_key
 where order_date is not null)
 
 , customer_aggregation as(
 /*----------------------------------------------------------------------
 2) Customer Aggregations: Summarizes key metrics at the customer level
 -----------------------------------------------------------------------*/
 select 
 customer_key,
 customer_number,
 customer_name,
 age,
 count(DISTINCT order_number) as total_orders,
 sum(sales_amount) as total_sales,
 sum(quantity) as total_quantity,
 count(DISTINCT product_key) as total_products,
 max(order_date) as last_order_date,
 timestampdiff(month,min(order_date),max(order_date)) as lifespan
 from base_query
 group by customer_key,
 customer_number,
 customer_name,
 age)
 select 
 customer_key,
 customer_number,
 customer_name,
 age,
 case when age<20 then 'Under 20'
      when age between 20 and 29 then '20-29'
      when age between 30 and 39 then '30-39'
      when age between 40 and 49 then '40-49'
      else '50 and above'
end as age_group, 
case when lifespan>=12 and total_sales >5000 then 'VIP'
     when lifespan>=12 and total_sales<=5000 then 'Regular'
     else 'New'
end customer_segment,
timestampdiff(month,last_order_date,curdate()) as recency,
total_orders,
total_sales,
total_quantity,
last_order_date,
lifespan,
-- Computer average order value (avo)
case when total_sales =0 then 0
     else total_sales/total_orders 
end as avg_order_value,
-- Compuate average monthly spend
case when total_sales =0 then 0
     else round(total_sales/lifespan,2) 
end as avg_monthly_spend
from customer_aggregation;

/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
with base_query as(
/*------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from fcat_sales and dimm_products
-------------------------------------------------------------------------------*/
select 
     f.order_number,
     f.order_date,
     f.customer_key,
     f.sales_amount,
     f.quantity,
     p.product_key,
     p.product_name,
     p.category,
     p.subcategory,
     p.cost
from fact_sales f 
left join dim_products p on p.product_key=f.product_key
where order_date is not null -- only consider valid sales dates
),
product_aggregations as(
/*--------------------------------------------------------------------- 
Product Aggregations: Summarizes key metrics at the product level
----------------------------------------------------------------------*/
select 
      product_key,
      product_name,
      category,
      subcategory,
      cost,
      timestampdiff(month,min(order_date),max(order_date)) as lifespan,
      max(order_date) as last_sale_date,
      count(DISTINCT order_number) as total_orders,
      count(DISTINCT customer_key) as total_customers,
      sum(sales_amount) as total_sales,
      sum(quantity) as total_quantity,
      round(avg(sales_amount/nullif(quantity,0)),1) as avg_selling_price
from base_query
group by product_key,
         product_name,
         category,
         subcategory,
         cost
) 
/*-----------------------------------------------------------------------
3) Final Query: Combines all product results into one output
------------------------------------------------------------------------*/
SELECT 
      product_key,
      product_name,
      category,
      subcategory,
      cost,
      last_sale_date,
      TIMESTAMPDIFF(month,last_sale_date,curdate()) as recency_in_months,
      CASE
          WHEN total_sales > 50000 THEN 'High-performer'
          WHEN total_sales >=10000 THEN 'Mid-Range'
          ELSE 'Low-Performer'
	  END AS product_segment,
      lifespan,
      total_orders,
      total_sales,
      total_quantity,
      total_customers,
      avg_selling_price,
      -- average Order Revenue(AOR)
      CASE 
          WHEN total_orders=0 THEN 0
          ELSE total_sales/total_orders
	END AS avg_order_revenue,
    
    -- average Monthly Revenue
    CASE 
        WHEN lifespan=0 THEN 0
        ELSE total_sales/lifespan
	END AS avg_monthly_revenue
FROM product_aggregations;
      
 



 











