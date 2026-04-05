
SELECT * FROM customer_churn;

ALTER TABLE customer_churn ADD COLUMN churn_status VARCHAR(10);

UPDATE customer_churn
SET churn_status = CASE
    WHEN Churn = '1' THEN 'Yes'
    WHEN Churn = '0' THEN 'No'
END;


SELECT *FROM customer_churn;

-- total churned customers
SELECT churn_status, COUNT(*)
FROM customer_churn
GROUP BY churn_status;

-- What is the average number of months customers stayed with our service before churning compared to retained customers?
SELECT churn_status,
       ROUND(AVG(tenure)) AS avg_tenure,
       COUNT(customerid) AS total_customers
FROM customer_churn
GROUP BY churn_status;

-- Which city tier shows the highest churn rate, and how does it compare to others?
SELECT CityTier, INITCAP(churn_status) AS churn_status,
       COUNT(*) AS total_customers
FROM customer_churn
GROUP BY citytier, churn_status
ORDER BY citytier, churn_status;

-- What is the distribution of preferred login devices among churned customers?
SELECT preferredlogindevice,
       COUNT(customerid) AS customer_count,
       ROUND( (COUNT(customerid) * 100.0 / SUM(COUNT(customerid)) OVER ()), 2 ) AS percentage_distribution
FROM customer_churn
WHERE churn_status = 'Yes'
GROUP BY preferredlogindevice
ORDER BY customer_count DESC;


-- What is the most common payment mode among churned customers, and how does it compare with non-churned?
SELECT churn_status, preferredpaymentmode,
       COUNT(*) AS total
FROM customer_churn
GROUP BY churn_status, preferredpaymentmode
ORDER BY preferredpaymentmode,total DESC;     

-- Does longer delivery time (WarehouseToHome in days) increase churn probability?
SELECT CASE 
          WHEN warehousetohome <= 3 THEN 'On-time (<=3 days)'
          ELSE 'Delayed (>3 days)'
       END AS delivery_status,
       churn_status,
       COUNT(*) AS total
FROM customer_churn
GROUP BY delivery_status, churn_status
ORDER BY delivery_status, churn_status;

-- What is the churn rate segmented by both gender and marital status combinations?
SELECT gender, maritalstatus,
       ROUND(100.0 * SUM(CASE WHEN churn_status='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM customer_churn
GROUP BY gender, maritalstatus
ORDER BY churn_rate DESC;

-- What is the average number of hours spent on the platform by churned vs. non-churned customers?
SELECT churn_status,
       ROUND(AVG(hourspendonapp)) AS avg_hours
FROM customer_churn
GROUP BY churn_status;

-- What is the satisfaction score distribution of churned vs. non-churned customers?
SELECT churn_status, satisfactionscore,
       COUNT(*) AS total
FROM customer_churn
GROUP BY churn_status, satisfactionscore
ORDER BY satisfactionscore;

-- Which product category is most ordered by churned customers?
SELECT PreferedOrderCat, COUNT(*) AS total_orders
FROM customer_churn
WHERE churn_status = 'Yes'
GROUP BY PreferedOrderCat
ORDER BY total_orders DESC
FETCH FIRST 3 ROW ONLY;

-- What percentage of customers who raised complaints eventually churned compared to those who didn’t?
SELECT churn_status,
       ROUND(AVG(Complain) * 100, 2) AS complain_percentage
FROM customer_churn
GROUP BY churn_status;

-- How does coupon usage differ between churned and retained customers? (average coupons used per customer)
SELECT churn_status,
       ROUND(AVG(couponused)) AS avg_coupons
FROM customer_churn
GROUP BY churn_status;

-- What is the average number of orders made by churned customers compared to retained ones?
SELECT churn_status,
       ROUND(AVG(ordercount)) AS avg_orders
FROM customer_churn
GROUP BY churn_status;

-- Among churned customers, what percentage had both complaints and late deliveries (WarehouseToHome > 3 days)?
SELECT COUNT(*) AS total_customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer_churn WHERE churn_status='Yes'), 2) AS percentage_of_churned
FROM customer_churn
WHERE churn_status='Yes'
  AND complain=1
  AND warehousetohome > 3;

-- Can we identify churn risk using combined factors: low satisfaction (<3), low coupon usage (<2), and low engagement (<10 hours)?
SELECT COUNT(*) AS risky_customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer_churn), 2) AS percent_of_total
FROM customer_churn
WHERE satisfactionscore < 3
  AND couponused < 2
  AND hourspendonapp < 10
  AND churn_status='Yes';

-- Who are our “Top 10% best customers” (based on highest total spend), and what is their churn rate compared to the bottom 10%?
WITH ranked AS (
    SELECT customerid,
           SUM(orderamounthikefromlastyear) AS total_spend,
           NTILE(10) OVER (ORDER BY SUM(orderamounthikefromlastyear) DESC) AS decile,
           churn_status
    FROM customer_churn
    GROUP BY customerid, churn_status
)
SELECT decile,
       ROUND(100.0 * SUM(CASE WHEN churn_status='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM ranked
WHERE decile IN (1, 10)
GROUP BY decile;

-- Segment customers into High, Medium, and Low engagement (based on hours spent on platform). Which segment churns the most?
SELECT MAX(hourspendonapp),
       MIN(hourspendonapp)
FROM customer_churn;

SELECT CASE 
          WHEN hourspendonapp = 4 THEN 'High Engagement'
          WHEN hourspendonapp = 3 THEN'Medium Engagement'
          ELSE 'Low Engagement'
       END AS engagement_level,
       ROUND(100.0 * SUM(CASE WHEN churn_status='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate,
       COUNT(*) AS customers
FROM customer_churn
GROUP BY engagement_level
ORDER BY churn_rate DESC;

-- Which customer group has higher churn — “Coupon Hunters” (high coupon usage) vs. “Non-Coupon Users”?
SELECT MAX(couponused),
       MIN(couponused)
FROM customer_churn;

SELECT CASE 
          WHEN couponused >= 5 THEN 'Coupon Hunter'
		  WHEN couponused <5 AND couponused>0 THEN 'less coupon user'
          ELSE 'Non-Coupon User'
       END AS customer_type,
       ROUND(100.0 * SUM(CASE WHEN churn_status='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM customer_churn
GROUP BY customer_type
ORDER BY churn_rate DESC;

-- What is the churn rate among customers who had both late deliveries and complaints compared to those who never complained?
SELECT CASE 
          WHEN complain=1 AND warehousetohome > 3 THEN 'Late+Complaint'
          ELSE 'No Complaint/On-time'
       END AS category,
       ROUND(100.0 * SUM(CASE WHEN churn_status='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM customer_churn
GROUP BY category;

-- Are Tier-1 city churners higher-value (more orders, higher spend) compared to Tier-2 and Tier-3 churners?
SELECT citytier,
       ROUND(AVG(ordercount)) AS avg_orders,
       ROUND(AVG(orderamounthikefromlastyear)) AS avg_spend,
       ROUND(100.0 * SUM(CASE WHEN churn_status='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM customer_churn
GROUP BY citytier
ORDER BY churn_rate DESC;


