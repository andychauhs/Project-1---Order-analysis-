https://www.kaggle.com/datasets/sticktogethertm/business-analysis-junior/data

SELECT * FROM business_analyst_junior.sales_2020;
SELECT * FROM sales_2019
#1) How much did the seller earn on new products in 2020?
#2) Find the product with the biggest increase in 2020 compared to 2019.
#3) Conduct an ABC analysis and calculate the number of goods in group A for 2 years.
#4) Analyze customer revenue growth in 2020.
#5) Conduct an RFM analysis.
#6) Check the seller's income by month. Is there seasonality?
#7) Conduct an analysis of what influenced the increase in the income of the seller.



ALTER TABLE sales_2019
CHANGE `Order number` order_number DOUBLE,
CHANGE `CLient ID` client_id DOUBLE,
CHANGE `Product code` product_code DOUBLE,
CHANGE `Date of delivery` date_of_delivery DATE;

UPDATE sales_2019
SET ` Delivery amount` = REPLACE(REPLACE(` Delivery amount`, ',', ''), '.', '')
WHERE ` Delivery amount` IS NOT NULL;
ALTER TABLE sales_2019
CHANGE ` Delivery amount` delivery_amount BIGINT;

SELECT * FROM sales_2019;


#2020 table 
UPDATE sales_2020
SET ` Delivery amount` = REPLACE(REPLACE(` Delivery amount`, ',', ''), '.', '')
WHERE ` Delivery amount` IS NOT NULL;

ALTER TABLE sales_2020
CHANGE `Order number` order_number DOUBLE,
CHANGE `CLient ID` client_id DOUBLE,
CHANGE `Product code` product_code DOUBLE,
CHANGE `Date of delivery` date_of_delivery DATE,
CHANGE ` Delivery amount` delivery_amount BIGINT;

#Null handling 
#1. Directly drop rows that contain null in either column
DELETE FROM sales_2020
WHERE product_code IS NULL 
   OR order_number IS NULL 
   OR client_id IS NULL 
   OR product_code IS NULL 
   OR date_of_delivery IS NULL 
   OR delivery_amount IS NULL;
   
#2. create table that contains non null rows
CREATE TABLE sales_2019_non_nulls AS
	SELECT * 
	FROM sales_2019
	WHERE product_code IS NOT NULL 
		AND order_number IS NOT NULL 
		AND delivery_amount IS NOT NULL 
		AND client_id IS NOT NULL 
		AND date_of_delivery IS NOT NULL;
  
  CREATE TABLE sales_2020_non_nulls AS
	SELECT * 
	FROM sales_2020
	WHERE product_code IS NOT NULL 
		AND order_number IS NOT NULL 
		AND delivery_amount IS NOT NULL 
		AND client_id IS NOT NULL 
		AND date_of_delivery IS NOT NULL;
    
#1) How much did the seller earn on new products in 2020?
#earn per new product code 
SELECT DISTINCT s20.product_code AS unique_product_code, sum(s20.delivery_amount) AS total_sales 
FROM sales_2020_non_nulls s20
LEFT JOIN sales_2019_non_nulls s19 ON s20.product_code = s19.product_code
WHERE s19.product_code IS NULL
GROUP BY unique_product_code

#total amount for new products
SELECT sum(s20.delivery_amount) AS total_sales 
FROM sales_2020_non_nulls s20
LEFT JOIN sales_2019_non_nulls s19 ON s20.product_code = s19.product_code
WHERE s19.product_code IS NULL
GROUP BY unique_product_code
 
 
 #2) Find the product with the biggest increase in 2020 compared to 2019.
SELECT s19.product_code, 
	sum(s19.delivery_amount) AS 2019_sales, 
	sum(s20.delivery_amount) AS 2020_sales,
	ROUND((sum(s20.delivery_amount) - sum(s19.delivery_amount)) / sum(s19.delivery_amount) * 100 , 2)AS improvement_percentage_change
FROM sales_2019_non_nulls s19
JOIN sales_2020_non_nulls s20
ON s19.product_code = s20.product_code 
GROUP BY s19.product_code
ORDER BY improvement_percentage_change DESC 
LIMIT 1

#3) Conduct an ABC analysis and calculate the number of goods in group A for 2 years.
#ABC analysis - threadshold 80/15/5 in revenue 
CREATE TEMPORARY TABLE sales_2019_abc AS
WITH temp_2019 AS (
    SELECT 
        product_code,
        SUM(delivery_amount) AS total_delivery
    FROM 
        sales_2019_non_nulls
    GROUP BY 
        product_code
),
total_sum AS (
    SELECT SUM(total_delivery) AS total_sum_2019 FROM temp_2019
)

SELECT 
    t.product_code,
    t.total_delivery,
    (t.total_delivery / ts.total_sum_2019 * 100) AS part,
    ROUND((@cumulative_sum := @cumulative_sum + (t.total_delivery / ts.total_sum_2019 * 100)),2) AS cum_part,
    CASE 
        WHEN @cumulative_sum < 80 THEN 'A'
        WHEN @cumulative_sum >= 80 AND @cumulative_sum < 95 THEN 'B'
        ELSE 'C'
    END AS abc_group
FROM 
    temp_2019 t,
    total_sum ts,
    (SELECT @cumulative_sum := 0) AS init  -- Initialize the variable
ORDER BY total_delivery DESC



CREATE TEMPORARY TABLE sales_2020_abc AS
WITH temp_2020 AS (
    SELECT 
        product_code,
        SUM(delivery_amount) AS total_delivery
    FROM 
        sales_2020_non_nulls
    GROUP BY 
        product_code
),
total_sum AS (
    SELECT SUM(total_delivery) AS total_sum_2019 FROM temp_2020
)

SELECT 
    t.product_code,
    t.total_delivery,
    (t.total_delivery / ts.total_sum_2019 * 100) AS part,
    ROUND((@cumulative_sum := @cumulative_sum + (t.total_delivery / ts.total_sum_2019 * 100)),2) AS cum_part,
    CASE 
        WHEN @cumulative_sum < 80 THEN 'A'
        WHEN @cumulative_sum >= 80 AND @cumulative_sum < 95 THEN 'B'
        ELSE 'C'
    END AS abc_group
FROM 
    temp_2020 t,
    total_sum ts,
    (SELECT @cumulative_sum := 0) AS init  -- Initialize the variable
ORDER BY total_delivery DESC

SELECT 
	2020 AS year,
	SUM(CASE WHEN abc_group = 'A' THEN 1 ELSE 0 END) AS A, 
    SUM(CASE WHEN abc_group = 'B' THEN 1 ELSE 0 END) AS B,
    SUM(CASE WHEN abc_group = 'C' THEN 1 ELSE 0 END) AS C, 
	COUNT(abc_group) AS total 
FROM sales_2020_abc
UNION 
SELECT 
	2019 year,
	SUM(CASE WHEN abc_group = 'A' THEN 1 ELSE 0 END) AS A, 
    SUM(CASE WHEN abc_group = 'B' THEN 1 ELSE 0 END) AS B,
    SUM(CASE WHEN abc_group = 'C' THEN 1 ELSE 0 END) AS C, 
	COUNT(abc_group) AS total 
FROM sales_2019_abc


#4) Analyze customer revenue growth in 2020.
SELECT s20.client_id,
	SUM(s19.delivery_amount) AS last_year_total_revenue, 
	SUM(s20.delivery_amount) AS total_revenue, 
    (SUM(s20.delivery_amount) - SUM(s19.delivery_amount)) / SUM(s19.delivery_amount) * 100 AS revenue_grwoth
FROM sales_2020_non_nulls s20, sales_2019_non_nulls s19
GROUP BY client_id
ORDER BY revenue_grwoth DESC


#5) Conduct an RFM analysis: RFM analysis is an analysis method that allows you to segment customers by the frequency and amount of purchases and identify those customers who bring more money.
• Recency — prescription (how long ago your users bought something from you);
• Frequency — frequency (how often they buy from you);
• Monetary - money (the total amount of purchases).

CREATE TEMPORARY TABLE rfm_2020 AS
SELECT order_number, client_id, date_of_delivery, sum(delivery_amount) As total_purchase
FROM sales_2020_non_nulls 
GROUP BY order_number, client_id, date_of_delivery
ORDER BY client_id, date_of_delivery

#FRM
WITH rfm_2020_temp AS (
	SELECT
		client_id,
		date_of_delivery, 
		LAG(date_of_delivery) OVER(PARTITION BY client_id ORDER BY date_of_delivery) as last_purchase,
		DATEDIFF(date_of_delivery, LAG(date_of_delivery) OVER(PARTITION BY client_id ORDER BY date_of_delivery)) AS date_diff,
		total_purchase
	FROM rfm_2020
)
#assume today is 2021/1/1
SET @today = '2021-01-01';
SELECT client_id,	
	DATEDIFF(@today, MAX(date_of_delivery))AS recency,
    COUNT(client_id) AS frequency,
    SUM(total_purchase) AS monetary
FROM rfm_2020_temp
GROUP BY client_id
	
#6) Check the seller's income by month. Is there seasonality?
WITH monthly_sales_2019 AS(
	SELECT 
		MONTH(s19.date_of_delivery) as monthly,
		SUM(delivery_amount) as monthly_revenue_19
	FROM sales_2019_non_nulls s19
	GROUP BY monthly
), monthly_sales_2020 AS(
	SELECT 
		MONTH(date_of_delivery) as monthly, 
		SUM(delivery_amount) as monthly_revenue
	FROM sales_2020_non_nulls
	GROUP BY monthly
)
SELECT s20.monthly,
	s19.monthly_revenue_19, 
    s20.monthly_revenue AS monthly_revenue_20
FROM monthly_sales_2019 s19
RIGHT JOIN monthly_sales_2020 s20
ON s19.monthly = s20.monthly 
ORDER BY monthly 
-- 2019 great perfromance in FEB, JUNE - SEP are is consider as off season, OCT to the first quarter of the coming year show continuous sales increase 
-- 2020 better performance in first half year, decline significantly after june, SEP and after are consider as off season



#7) Conduct an analysis of what influenced the increase in the income of the seller.
SELECT DATE_FORMAT(date_of_delivery, '%Y-%m') AS month,
	COUNT(DISTINCT order_number) AS number_of_order, 
    SUM(delivery_amount) as monthly_revenue,
    ROUND(SUM(delivery_amount) / COUNT(DISTINCT order_number), 2) AS avg_order_size
from sales_2020_non_nulls
GROUP BY month

# overall product performance 
WITH product_overall_performance_2020 AS(
	 SELECT product_code, 
		COUNT(product_code) as number_of_order, 
        SUM(delivery_amount) as total_amount 
     FROM sales_2020_non_nulls
     GROUP BY product_code
), product_overall_performance_2019 AS(
	SELECT product_code, 
		COUNT(product_code) as number_of_order, 
		SUM(delivery_amount) as total_amount 
	FROM sales_2019_non_nulls
	GROUP BY product_code
)

SELECT s20.product_code,
	s19.number_of_order AS s19_number_of_order, 
    s20.number_of_order AS s20_number_of_order,
    s19.total_amount AS s19_total_amount,
    s20.total_amount AS s20_total_amount
FROM product_overall_performance_2020 s20
LEFT JOIN product_overall_performance_2019 s19
ON s20.product_code = s19.product_code
-- the main reason of sales increase in 2020 is due to the introduction of new products that outperformed traditional products, increasing the comapany offerings variety to improve company's profitability
