
# 🛒 Amazon India Sales Analysis (SQL + Power BI)
**Tools Used:** MySQL Workbench, Power BI  
**Dataset Size:** 128,975 rows | 21 columns


## Table of Content

1. [Project Objectives](#ProjectObjectives)
2. [Data Overview](#DataOverview)
3. [Data Cleaning](#DataCleaning)
4. [Power Bi Dashbord Features](#PowerBiDashboardFeatures)
5. [Recommendations](#Recommendations)
6. [Conclusions](#Conclusions)


# 🛒 Amazon India Sales Analysis (SQL + Power BI)

**Tools Used:** MySQL Workbench, Power BI  
**Dataset Size:** 128,975 rows | 21 columns

---

## 📌 Project Objective

To uncover key performance metrics, identify returned product categories, evaluate shipping method outcomes, understand customer behavior across segments and regions using SQL and Power BI with the goal of transforming raw sales data into actionable insights for business improvement .

---

## 📁 Dataset Overview

The dataset contains 128,975 records and 21 columns, with fields including:

- Order details: `order_id`, `order_date`, `order_status`, `courier_status`
- Product details: `category`, `sku`, `style`, `amount`, `currency`, `qty`
- Shipping: `ship_service_level`, `ship_city`, `ship_state`, `ship_country`
- Customer segment: `b2b_flag`, `fulfilled_by`, `promotion_ids`

Several issues were identified in the raw data:
- Inconsistent and non-standard date formats
- Hidden or non-printable characters (e.g., `\xA0`)
- Missing or blank values in key fields
- Inconsistent formatting of text fields (e.g., mixed cases, special characters)

---

## Data Cleaning (MySQL)

All cleaning was done using raw SQL in MySQL Workbench.

### 🔹 1. Fixing inconsistent date formats

```sql
UPDATE amazon_sales
SET order_date = STR_TO_DATE(order_date, '%m-%d-%y')
WHERE order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$';


🔹 2. Removing invisible characters and non-alphabetic symbols


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
END;


Applied similarly to:
	•	ship_state
	•	product_category

🔹 3. Handling blanks or missing values

UPDATE amazon_sales
SET currency = 'INR'
WHERE TRIM(currency) = '' OR currency IS NULL;

UPDATE amazon_sales
SET ship_country = 'IN'
WHERE TRIM(ship_country) = '' OR ship_country IS NULL;

🔹 4. Grouping messy order statuses into standardized labels

ALTER TABLE amazon_sales_raw ADD COLUMN grouped_status VARCHAR(50);

UPDATE amazon_sales
SET grouped_status = 
  CASE
    WHEN LOWER(order_status) LIKE 'cancelled%' THEN 'Cancelled'
    WHEN LOWER(order_status) LIKE 'pending%' THEN 'Pending'
    WHEN LOWER(order_status) LIKE 'shipped%returned%' THEN 'Returned'
    WHEN LOWER(order_status) LIKE 'shipped%rejected%' THEN 'Returned'
    WHEN LOWER(order_status) LIKE 'shipped%lost%' THEN 'Lost'
    WHEN LOWER(order_status) LIKE 'shipped%delivered%' THEN 'Delivered'
    WHEN LOWER(order_status) LIKE 'shipped%' THEN 'Shipped'
    ELSE 'Other'
  END;


🔍 Insight Questions, Queries & Answers

1️⃣  What are the total sales generated per month across all products?

SELECT 
   DATE_FORMAT(order_date, '%M') AS full_month,
   CONCAT('₹', FORMAT(SUM(amount),0)) AS total_sales
FROM amazon_sales
GROUP BY full_month
ORDER BY STR_TO_DATE(full_month, '%M');

2️⃣ Which product line or product name has generated the highest total revenue?

SELECT 
     product_category,
	 CONCAT('₹', FORMAT(SUM(amount),0)) AS total_revenue
FROM amazon_sales
GROUP BY product_category
ORDER BY SUM(amount)DESC
LIMIT 1;

Result: Set generated the highest total revenue (₹39,204,124)

3️⃣ What day of the week records the highest sales?

SELECT DAYNAME(order_date) AS weekday, SUM(amount) AS total_sales
FROM amazon_sales
GROUP BY weekday
ORDER BY total_sales DESC;

Result: Sunday generated the highest sales (₹12M), followed by Tuesday and Saturday. Thursday was consistently the lowest.

4️⃣ Which states generate the most revenues?

SELECT ship_state, SUM(amount) AS total_revenue
FROM amazon_sales
GROUP BY ship_state
ORDER BY total_revenue DESC;

Result: Maharashtra, Karnataka, Telangana, Uttar Pradesh and Tamil Nadu are the top-performing states.

5️⃣ B2B vs B2C performance?

SELECT b2b_type, COUNT(*) AS orders, SUM(amount) AS total_sales, AVG(amount) AS avg_order_value
FROM amazon_sales
GROUP BY b2b_type;

Result:
	•	B2B made up ~1% of orders but had higher average order values
	•	B2C drove 99%+ of total revenue (₹78M+)

6️⃣ Delivery issues and courier status

SELECT courier_status, COUNT(*) AS count
FROM amazon_sales
GROUP BY courier_status
ORDER BY count DESC;

Result: Many orders marked as Returned, Rejected, or Lost — delivery issues present.

7️⃣ Daily sales trend across weekdays

SELECT DAYNAME(order_date) AS weekday, SUM(amount) AS total_sales
FROM amazon_sales
GROUP BY weekday
ORDER BY FIELD(weekday, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');


Result: Sunday, Tuesday, and Saturday were peak sales days. Thursday was the lowest. 
```

---

## 📊 Power BI Dashboard Features

After cleaning and exporting the dataset, Power BI was used to design an interactive dashboard with:

*	KPI cards for total sales, total orders, return and cancellations counts as (failed orders)
*	Donut charts for order status and B2B vs B2C split
*	Stacked bar charts showing shipping method vs delivery outcome
*	Line chart for weekday sales trend
*	Filled map highlighting top-performing states
*	Slicers for user interaction: product category, state, shipping method, customer type

---

## 📊 Dashboard
<img width="680" alt="Image" src="https://github.com/user-attachments/assets/3e0d3d08-0eaa-4786-b5c3-34d49370cd53" />

<img width="680" alt="Image" src="https://github.com/user-attachments/assets/f9c2ecd0-dafc-42f7-b2d6-6cd955545ec5" />

---

## 🔍 Insights

1. **Total Sales and Orders:**  
   ₹79M total revenue, 129K orders and 120K customers.

2. **Order Fulfillment:**  
   68% of all orders were successfully shipped. 16% failed (cancelled, returned, rejected).

3. **Top Failed Categories:**  
   Sets, Kurta and Western Dress had the highest return and cancellation rates.

4. **Shipping Method Analysis:**  
   Expedited shipping had a higher share of failed deliveries compared to Standard.

5. **Daily Sales Pattern:**  
   Sunday recorded the highest sales (₹12M), followed by Tuesday and Saturday.  
   Thursday had the lowest (₹10.3M).

6. **Geographic Performance:**  
   Maharashtra, Karnataka, Telangana, Uttar Pradesh and Tamil Nadu contributed the highest order volume.

7. **B2B vs B2C Split:**  
    - 99% of orders were B2C  
    - B2B made up only 1% but had higher average order value

8. **Courier Status Review:**  
   Significant orders were marked as "Returned", "Lost", or "Rejected", indicating courier inefficiencies.

9. **Top Customers:**  
   A few customers contributed large revenue volumes, valuable for potential targeting.

---

## 📌 Recommendations 

1.	**Improve product presentation for high-return categories:**
Set, Western Dress and Kurta showed high return volumes. These should be reviewed for possible improvements in size guides, product images, and descriptions to reduce post-purchase dissatisfaction and return rates.

2. **Audit and improve Expedited shipping performance:**
Expedited shipping was expected to deliver faster, but recorded more cancellations and in-transit delays than Standard. This suggests a need to audit performance and adjust customer communication or switch default shipping preferences.

3.	**Address courier-related delivery failures:**
Orders frequently marked as Returned, Rejected, or Lost indicate problems with courier performance. These statuses should be monitored, and logistics partners with repeated failures should be reviewed or replaced.

4.	**Align marketing campaigns with peak weekday performance:**
Sunday, Tuesday, and Saturday drive the most revenue. Promotions and product launches should align with these peak days, while Thursday can be targeted with flash deals to boost engagement.

5.	**Develop B2B customer growth strategies:**
B2B orders were minimal but showed higher average order value. Consider incentives like bulk pricing, invoice billing, or custom fulfillment to encourage more B2B transactions.

6.	**Prioritize high-performing states for logistics and marketing:**
Maharashtra, Delhi, Karnataka, and Tamil Nadu consistently showed high sales volumes. These regions should be prioritized in inventory planning, marketing efforts, and faster delivery options.

---

## ✅ Conclusion

This project covered the end-to-end process of data cleaning, transformation, and analysis using SQL, followed by dynamic reporting with Power BI. Through careful querying, data modeling and dashboard design, I uncovered key patterns across shipping methods, product returns, customer types and regional behavior.

Every insight was supported with real SQL logic and translated into business-friendly recommendations. The result is a clean dataset, a SQL script for transparency and a Power BI dashboard that tells the full story.
