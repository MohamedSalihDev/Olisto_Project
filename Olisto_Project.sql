--Create leads table

CREATE TABLE leads(
mql_id VARCHAR(50) PRIMARY KEY
,first_contact_date DATE
,landing_page_id VARCHAR(50)
,origin VARCHAR(50)
					);

--Create closed_deals table


CREATE TABLE closed (
mql_id VARCHAR(50)
,seller_id VARCHAR(50)
,sdr_id VARCHAR(50)
,sr_id VARCHAR(50)
,won_date DATE
,business_segment VARCHAR(50)
,lead_type VARCHAR(50)
,lead_behavior_profile VARCHAR(50)
,has_company VARCHAR(5)
,has_gtin VARCHAR(5)
,average_stock VARCHAR(50)
,business_type VARCHAR(50)
,declared_product_size DECIMAL
,declared_monthly_revenue DECIMAL
					);

--Create sellers table
CREATE TABLE sellers(

  seller_id VARCHAR(50)
, seller_zip_code INT
, seller_city VARCHAR(50)
, seller_state VARCHAR(50)
					);
--Create products table

CREATE TABLE order_items
(
order_id VARCHAR(50)
,order_item_id INT
,product_id	VARCHAR(50)
,seller_id VARCHAR(50)
,shipping_limit_date DATE
,price DECIMAL
,freight_value DECIMAL
);

--We want to ascertain the usefulness of the has_company and has_gtin columns in
--the closed table. Return a table that displays the percentages of True, false
--and nulls
select count(*) from closed

--percentages of has_company column
SELECT
	 ROUND(100.0 * (COUNT(*) - COUNT(has_company))/COUNT(*), 2) AS percentage_nulls
	,ROUND(100.0 * SUM(
	 CASE 
	  WHEN has_company = 'True' THEN 1 ELSE 0 END)/COUNT(*), 2) AS percentage_True
	,ROUND(100.0 * SUM(
	 CASE
	  WHEN has_company ='False' THEN 1 ELSE 0 END)/COUNT(*), 2) AS percentage_False
FROM
	closed;
								
--percentages of has_gtin column
		
SELECT
	 ROUND(100.0 * (COUNT(*) - COUNT(has_gtin))/COUNT(*), 2) AS percentage_nulls
	,ROUND(100.0 * SUM(
	 CASE 
	  WHEN has_gtin = 'True' THEN 1 ELSE 0 END)/COUNT(*), 2) AS percentage_True
	,ROUND(100.0 * SUM(
	 CASE
	  WHEN has_gtin ='False' THEN 1 ELSE 0 END)/COUNT(*), 2) AS percentage_False
FROM
	closed;
	
--Note: in the queries for percentages of has_company and has_gtin we used 100.0 (with a decimal point)
--to convert the resluting columns be to 'numeric' type. Otherwise, the count() function
--returns a bigint type, which does not take decimals and would round to zero and
--then multiply by 100, leading to a false result of 0.

--TASK
--Since we have two columns with mostly null data, please remove them from the table.

ALTER TABLE closed
 DROP COLUMN has_company
,DROP COLUMN has_gtin;

--TASK
--Check to see what percentage of the rows in the declared_monthly_income column are NULL

SELECT
	ROUND(100.0 * SUM(CASE 
					  WHEN declared_product_size IS NULL THEN 1 ELSE 0 END)/COUNT(*),2) AS percent_null_declared_product_size
FROM
	closed; --92
	
--TASK
--Since about 92% of declared_product_size in the closed tabe is null, 
-- Replace the nulls with the number of products matched to eash seller from
--the order_items table.

CREATE TABLE order_items_temp AS
	(SELECT 
	 	 product_id AS distinct_product
	 	,seller_id
	 	,COUNT(seller_id) AS seller_product_size
	 FROM
	 	order_items
	 GROUP BY
	 	distinct_product
	 	,seller_id
	);

SELECT * FROM order_items_temp order by seller_id

UPDATE closed
SET 
	declared_product_size = (SELECT
									COUNT(seller_id)
								FROM
									order_items_temp
								WHERE
									order_items_temp.seller_id = closed.seller_id
							 	GROUP BY 
							 		seller_id
							   )
WHERE
	closed.declared_product_size IS NULL;
	
--Check to make sure it worked

SELECT 
	*
FROM
	closed;
--Check to see the new percentage of nulls in declared_product_size
SELECT
	ROUND(100.0 * SUM(CASE 
					  WHEN declared_product_size IS NULL THEN 1 ELSE 0 END)/COUNT(*),2) AS percent_null_declared_product_size
FROM
	closed; 

--47% which is down from 92%. Much better.
	
--TASK
--We want to see if the performance of each sales respresentative was improving with time
--Return a running total of conversions by date

SELECT
	 sr_id
	 , won_date
	,COUNT(*)OVER (
					PARTITION BY
						sr_id
					ORDER BY
						DATE(won_date)
					) AS running_total
FROM
	closed
ORDER BY
	sr_id;


--We want to see how many total leads were sent to Sales Representatives by 
--each Sales Development Representative. Return a total of each from highest to lowest.

SELECT
	sdr_id
	,COUNT(*) AS sales_developed
FROM	
	closed
GROUP BY 
	sdr_id
ORDER BY
	sales_developed DESC;
	
--Task: For each closed deal, return the durantion of time it took to close it.

SELECT
	 l.mql_id
	,AGE(c.won_date, l.first_contact_date) AS time_to_close
FROM
	leads l
JOIN
	closed c
ON
	l.mql_id = c.mql_id
ORDER BY
	time_to_close DESC;

--Task
--We want to assess the responsiveness of each region to the type of media where
--the lead was acquired. For each seller city, return total conversions by each lead type.

SELECT
	 s.seller_city
	,l.origin
	,COUNT(s.seller_city) OVER( 
								 PARTITION BY 
									l.origin
								 ) AS conversions
FROM
	leads l
JOIN
	closed c
ON
	l.mql_id = c.mql_id
JOIN
	sellers s
ON
	s.seller_id = c.seller_id
GROUP BY
	 s.seller_city
	 ,l.origin
ORDER BY 
	s.seller_city
	,conversions DESC;


--Task
--We want to improve closed sales ratio by letting sales reps focus on the landing
--pages where they get the best conversions. Return the total conversions of each sales rep
--partitioned by landing_page_id.

SELECT
	 c.sr_id
	,l.landing_page_id
	,COUNT(c.sr_id)OVER(
					 PARTITION BY
						l.landing_page_id
						) AS conversions_for_landing_page
					 
FROM
	closed c
JOIN
	leads l
ON
	c.mql_id = l.mql_id
GROUP BY
	c.sr_id
	,l.landing_page_id
ORDER BY
	c.sr_id
	,conversions_for_landing_page DESC;

--Task
--We want to get an idea of which media types are not so successful at conversions.
--Return the numbers for qualified leads that did not convert broken down by media
--lead type
WITH unconverted AS(
SELECT 
	 origin
	,COUNT(origin) AS failed_mql
FROM
	leads l
WHERE
	NOT EXISTS(
				SELECT
					mql_id
				FROM
					closed c
				WHERE
					l.mql_id = c.mql_id)
GROUP BY
	origin
ORDER BY
	failed_mql DESC
					)
--select * from unconverted
--select count(origin), origin from leads group by origin				
SELECT
	l.origin
	, u.failed_mql
	,COUNT(l.origin) AS number_of_converted_leads
	,ROUND(100.0 *  (u.failed_mql)/COUNT(l.origin),2) AS percent_unconverted
FROM
	leads l

JOIN
	unconverted u
ON
	l.origin = u.origin
GROUP BY
	l.origin
	,u.failed_mql
	
ORDER BY
	percent_unconverted DESC;





