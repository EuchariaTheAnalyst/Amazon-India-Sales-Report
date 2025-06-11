CREATE TABLE amazon_sales (
       order_no INT,
       order_id VARCHAR(50),
       order_date VARCHAR(50),
       order_status VARCHAR(50),
       fulfillment VARCHAR(50),
       sales_channel VARCHAR(50),
       ship_service_level VARCHAR(100),
       style VARCHAR(100),
       stock_keeping_unit VARCHAR(100),
       product_category VARCHAR(100),
       product_size VARCHAR(50),
       amazon_standard_id_no VARCHAR(50),
       courier_status VARCHAR(100),
       quantity VARCHAR(20),
       currency VARCHAR(10),
       amount VARCHAR(50),
       ship_city VARCHAR(100),
       ship_state VARCHAR(100),
       ship_postal_code VARCHAR(20),
       ship_country VARCHAR(100),
       promotion_ids TEXT,
       business_to_business VARCHAR(20),
       fulfilled_by VARCHAR(50)
);
       
SELECT *
FROM amazon_sales;
 
SELECT COUNT(*)
FROM amazon_sales; 

-- cleaning, filling/removing blanks, converting order_date, amount and quantity to the required datatype

UPDATE amazon_sales
SET order_date = STR_TO_DATE(order_date, '%m-%d-%y')
WHERE order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$';

UPDATE amazon_sales
SET order_date = STR_TO_DATE(order_date, '%m/%d/%Y')
WHERE order_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

ALTER TABLE amazon_sales
MODIFY COLUMN order_date DATE;

-- CONVERTING AMOUNT AND QUANTITY AND  FILLING BLANKS
UPDATE amazon_sales
SET 
   amount = CASE
        WHEN amount IS NULL OR amount = '' THEN '0'
        ELSE REPLACE(amount, ',', '')
	END;
    
ALTER TABLE amazon_sales
MODIFY amount DECIMAL(10,2),
MODIFY quantity INT;
  
  SET SQL_SAFE_UPDATES = 0;    -- TO TURN OFF SAFE UPDATE MODE
  
-- FILLING AND STANDARDIZING TEXT FIELDS
UPDATE amazon_sales 
SET 
    product_category = CASE
        WHEN product_category IS NULL OR TRIM(product_category) = '' THEN 'Unknown'
        ELSE CONCAT(
			 UPPER(LEFT(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '.' FROM product_category),'(', 1), ',', 1)), 1)),
             LOWER(SUBSTRING(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '.' FROM product_category), '(', 1), ',', 1)), 2))
		)
	END,
    ship_city = CASE
	    WHEN ship_city IS NULL OR TRIM(ship_city) = '' THEN 'Unknown'
        WHEN ship_city REGEXP '^[0-9]+$' OR LOWER(TRIM(ship_city)) IN ('1', 'na', 'null') THEN 'Unknown'
        ELSE
            CONCAT(
				UPPER(LEFT(
					TRIM(
                       REGEXP_REPLACE(
                           SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '.' FROM ship_city), '(', 1), ',', 1),
                           '[^a-zA-Z ]', ''
					   )
					)
				, 1)),
                LOWER(SUBSTRING(
					TRIM(
						REGEXP_REPLACE(
                             SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '.' FROM ship_city), '(', 1), ',', 1),
							'[^a-zA-Z ]', ''
						 )
					), 2))
				)
	  END,
    ship_state = CASE
	    WHEN ship_state IS NULL OR TRIM(ship_state) = '' THEN 'Unknown'
        WHEN ship_state REGEXP '^[0-9]+$' OR LOWER(TRIM(ship_state)) IN ('1', 'na', 'null') THEN 'Unknown'
        ELSE
            CONCAT(
				UPPER(LEFT(
					TRIM(
                       REGEXP_REPLACE(
                           SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '.' FROM ship_state), '(', 1), ',', 1),
                           '[^a-zA-Z ]', ''
					   )
					)
				, 1)),
                LOWER(SUBSTRING(
					TRIM(
						REGEXP_REPLACE(
                             SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '.' FROM ship_state), '(', 1), ',', 1),
							'[^a-zA-Z ]', ''
						 )
					), 2))
				)
	END,
	ship_postal_code = CASE
           WHEN ship_postal_code IS NULL OR TRIM(ship_postal_code) = '' THEN '0000'
           ELSE TRIM(ship_postal_code)
	END,
    ship_country = CASE
           WHEN ship_country IS NULL OR TRIM(ship_country) = '' THEN 'IN'
           ELSE UPPER(TRIM(ship_country))
	END,
    currency = CASE
		    WHEN currency IS NULL OR TRIM(currency) = '' THEN 'INR'
            ELSE UPPER(TRIM(currency))
	END,
	courier_status = CASE
         WHEN courier_status IS NULL OR TRIM(courier_status) = '' THEN 'Cancelled'
         ELSE TRIM(courier_status)
	END
WHERE 1 = 1;
    
-- CREATING A NEW COLUMN FOR ORDER_STATUS
ALTER TABLE amazon_sales
ADD COLUMN grouped_status VARCHAR(50);

UPDATE amazon_sales
SET grouped_status =
     CASE
         WHEN LOWER(order_status) LIKE '%cancelled%' THEN 'Cancelled'
         WHEN LOWER(order_status) LIKE '%pending%' THEN 'Pending'
         WHEN LOWER(order_status) LIKE '%delivered to buyer%' THEN 'Delivered'
         WHEN LOWER(order_status) LIKE '%picked up%' THEN 'Delivered'
         WHEN LOWER(order_status) LIKE '%shipping%' THEN 'In Transit'
         WHEN LOWER(order_status) LIKE '%out for delivery%' THEN 'In Transit'
         WHEN LOWER(order_status) LIKE '%rejected%' THEN 'Returned'
         WHEN LOWER(order_status) LIKE '%returned%' THEN 'Returned'
         WHEN LOWER(order_status) LIKE '%returning%' THEN 'Returned'
         WHEN LOWER(order_status) LIKE '%damaged%' THEN 'Returned'
         WHEN LOWER(order_status) LIKE '%lost%' THEN 'Lost'
         WHEN LOWER(order_status) LIKE '%shipped%' THEN 'In Transit'
         ELSE 'Other'
      END;
      
-- CREATING A NEW COLUMN FOR BUSINESS-TO-BUSINESS AS MYSQL DOES NOT USE TRUE OR FALSE 
ALTER TABLE amazon_sales
ADD COLUMN b2b_flag BOOLEAN;

UPDATE amazon_sales
SET b2b_flag = CASE
     WHEN LOWER(TRIM(business_to_business)) IN ('true') THEN '1'
     ELSE '0'
END;

-- CHECKING FOR DUPLICATES 
SELECT *
FROM (
       SELECT *, ROW_NUMBER() OVER(
             PARTITION BY order_id,order_date,order_status,fulfillment,sales_channel,ship_service_level,
                          style,stock_keeping_unit,product_category,product_size,amazon_standard_id_no,
						  courier_status,quantity,currency,amount,ship_city,ship_state,ship_postal_code,
                          ship_country,business_to_business,b2b_flag,order_year,order_month,order_day,
						  order_weekday,order_quarter,grouped_status
			ORDER BY order_id
		) AS rn
        FROM amazon_sales
) T
WHERE rn > 1;

-- DROPPING IRRELEVANT COLUMNS 
ALTER TABLE amazon_sales
DROP COLUMN promotion_ids,
DROP COLUMN fulfilled_by;

-- DERIVED COLUMN GENERATION
ALTER TABLE amazon_sales
ADD COLUMN order_year INT,
ADD COLUMN order_month INT,
ADD COLUMN order_day INT,
ADD COLUMN order_weekday VARCHAR(15),
ADD COLUMN order_quarter INT;


UPDATE amazon_sales
SET
   order_year = YEAR(order_date),
   order_month = MONTH(order_date),
   order_day = DAY(order_date),
   order_weekday = DAYNAME(order_date),
   order_quarter = QUARTER(order_date)
;

SET SQL_SAFE_UPDATES = 1;    -- TO TURN ON SAFE UPDATE MODE

SELECT DISTINCT ship_state
FROM amazon_sales
GROUP BY ship_state;

SELECT *
FROM amazon_sales;

SHOW COLUMNS FROM amazon_sales;

-- SQL QUESTIONS 

-- NO 1: TOTAL SALES GENERATED PER MONTH ACROSS ALL PRODUCTS
-- CREATE OR REPLACE VIEW total_sales_generated_per_month AS
SELECT 
   DATE_FORMAT(order_date, '%M') AS full_month,
   CONCAT('₹', FORMAT(SUM(amount),0)) AS total_sales
FROM amazon_sales
GROUP BY full_month
ORDER BY STR_TO_DATE(full_month, '%M') 
;

-- N0 2: WHICH PRODUCT LINE OR NAME GENERATED THE HIGHEST TOTAL REVENUE
-- CREATE OR REPLACE VIEW product_with_highest_total_revenue AS
SELECT 
     product_category,
	 CONCAT('₹', FORMAT(SUM(amount),0)) AS total_revenue
FROM amazon_sales
GROUP BY product_category
ORDER BY SUM(amount)DESC
LIMIT 1
;

-- NO 3: CITIES WITH HIGHEST NUMBER OF ORDERS PLACED
-- CREATE OR REPLACE VIEW cities_with_highest_no_of_orders AS
SELECT 
     ship_city,
     COUNT(order_id) AS order_count
FROM amazon_sales
GROUP BY ship_city
ORDER BY order_count DESC
LIMIT 10
;

-- NO 4: AVERAGE SELLING PRICE PER PRODUCT CATEGORY
-- CREATE OR REPLACE VIEW avg_sales_per_product AS
SELECT
    product_category, 
       CONCAT('₹', FORMAT(AVG(amount / NULLIF(quantity, 0)),0)) AS avg_selling_price
FROM amazon_sales
GROUP BY product_category
ORDER BY avg_selling_price DESC
;

-- NO 5: UNITS SOLD FOR EACH PRODUCT TYPE OVER TIME
-- CREATE OR REPLACE VIEW unit_sold_per_product AS
SELECT
    order_year,
    order_month,
    product_category,
    ROUND(SUM(quantity),0) AS total_units_sold
FROM amazon_sales
GROUP BY order_year, order_month, product_category
ORDER BY order_year, order_month
;

--- NO 6: REFUND RATE ACROSS PRODUCT CATEGORY
-- USING GROUPED_STATUS = 'RETURNED'
-- CREATE OR REPLACE VIEW return_rate_per_product AS
SELECT 
     product_category,
     ROUND(COUNT(CASE WHEN grouped_status = 'Returned' THEN 1 END) / COUNT(*) * 100,
     2) AS refund_rate
FROM amazon_sales
GROUP BY product_category
ORDER BY refund_rate DESC
;

-- NO 7: TOP 10 CUSTOMERS BASED ON TOTAL PURCHASE AMOUNT
-- CREATE OR REPLACE VIEW top_ten_customers AS
SELECT 
    order_id,
   CONCAT('₹', FORMAT(SUM(amount),0))AS total_purchase
FROM amazon_sales
GROUP BY order_id
ORDER BY SUM(amount) DESC
LIMIT 10
;

-- NO 8: HOW QUANTITY SOLD RELATE TO PROFIT MARGIN PER ITEM (NO PROFIT)
-- CREATE OR REPLACE VIEW quantity_sold_per_revenue AS
SELECT 
     quantity,
     ROUND(AVG(amount),0) as avg_sale
FROM amazon_sales
GROUP BY quantity
ORDER BY avg_sale DESC
LIMIT 8
;

-- NO 9: DISTRIBUTION OF ORDER STATUS
-- CREATE OR REPLACE VIEW distribution_of_order_staus AS
SELECT 
    grouped_status,
    COUNT(*) AS status_count
FROM amazon_sales
GROUP BY grouped_status 
ORDER BY status_count DESC
;

-- NO 10: SHIPPING MODE FREQUENLY USED AND HOW THEY RELATE TO DELIVERY TIME OR RETURNS
-- CREATE OR REPLACE VIEW most_used_shipping_mode AS
SELECT
    ship_service_level,
    grouped_status,
    COUNT(*) AS total_orders
FROM amazon_sales
GROUP BY ship_service_level, grouped_status
ORDER BY total_orders DESC
;

-- NO 11: DAYS OF THE WEEK WITH THE MOST SALES VOLUME
-- CREATE OR REPLACE VIEW weekday_with_highest_quantity_sold AS
SELECT
    order_weekday,
    SUM(quantity) AS total_quantity_sold
FROM amazon_sales
GROUP BY order_weekday
ORDER BY total_quantity_sold DESC
;

-- NO 12: REVENUE BREAKDOWN BY PRODUCT CATEGORY AND REGION
-- CREATE OR REPLACE VIEW product_per_region AS
SELECT 
    product_category,
    ship_state,
    CONCAT('₹', FORMAT(SUM(amount),0))AS total_revenue
FROM amazon_sales
GROUP BY product_category, ship_state
ORDER BY SUM(amount) DESC
;

-- NO 13 - NO 14 CANNOT BE DONE

-- NO 15 PRODUCTS CONSISTENTLY RETURNED
-- CREATE OR REPLACE VIEW return_rate AS
SELECT
    product_category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN grouped_status = 'Returned' THEN 1 ELSE 0 END) AS return_count,
    ROUND(SUM(CASE WHEN grouped_status = 'Returned' THEN 1 ELSE 0 END) / COUNT(*) * 100,
    2) AS return_rate
FROM amazon_sales  
GROUP BY product_category
HAVING return_count > 0
ORDER BY return_count DESC
LIMIT 5
;



