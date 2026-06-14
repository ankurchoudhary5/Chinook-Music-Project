use chinook;

-- OBJECTIVE QUESTIONS --

-- 1.	Does any table have missing values or duplicates? If yes, how would you handle it. --

SELECT * FROM employee;

SELECT
	COUNT(*) AS total_rows,
    SUM(reports_to IS NULL) AS reports_to_null_count
FROM employee;

SELECT * FROM customer;

SELECT 
	COUNT(*) AS total_rows,
	SUM(company IS NULL) AS company_null_count,
    SUM(state IS NULL) AS state_null_count,
    SUM(postal_code IS NULL) AS postal_code_null_count,
    SUM(phone IS NULL) AS phone_null_count,
    SUM(fax IS NULL) AS fax_null_count
FROM customer;

SELECT * FROM track;

SELECT
	COUNT(*) AS total_rows,
    SUM(composer IS NULL) AS composer_null_count
FROM track;

-- 2.	Find the top-selling tracks and top-artist in the USA and identify their most famous genres. --
SELECT
	Top_selling_tracks,
    Top_artists,
    Top_genre 
FROM
(
SELECT
	t.name AS Top_selling_tracks,
    SUM(il.quantity * t.unit_price) AS total,
    a.name AS Top_artists, g.name AS Top_genre
FROM track AS t
LEFT JOIN invoice_line AS il ON il.track_id = t.track_id
LEFT JOIN invoice AS i ON il.invoice_id = i.invoice_id
LEFT JOIN album AS al ON al.album_id = t.album_id
LEFT JOIN artist AS a ON a.artist_id = al.artist_id
LEFT JOIN genre AS g ON t.genre_id = g.genre_id
WHERE billing_country = "USA"
GROUP BY t.name, a.name, g.name
ORDER BY total DESC
LIMIT 10
) Agg_table;

-- 3.	What is the customer demographic breakdown (age, gender, location) of Chinook’s customer base? --
SELECT
	country,
    COUNT(customer_id) AS no_of_customers
FROM customer
GROUP BY country
ORDER BY COUNT(customer_id) DESC;

SELECT
	city,
    country,
    COUNT(customer_id) AS no_of_customers
FROM customer
GROUP BY country, city
ORDER BY COUNT(customer_id) DESC;

SELECT
	COUNT(distinct country)
FROM customer;

SELECT
	COUNT(distinct city)
FROM customer;

-- 4.	Calculate the total revenue and number of invoices for each country, state, and city: --
SELECT
	SUM(total)
FROM invoice;

SELECT
	billing_city,
    billing_state,
    billing_country,
    COUNT(invoice_id) num_of_invoices, 
    SUM(total) total_revenue
FROM invoice
GROUP BY billing_city, billing_country, billing_state;

-- 5.	Find the top 5 customers by total revenue in each country --
WITH
cte AS (
SELECT 
country,
first_name,
last_name,
COALESCE(SUM(t.unit_price * il.quantity), 0) AS total_revenue
FROM
customer c
LEFT JOIN
invoice i ON i.customer_id = c.customer_id
LEFT JOIN
invoice_line il ON il.invoice_id = i.invoice_id
LEFT JOIN
track t ON t.track_id = il.track_id
GROUP BY 
country,
first_name,
last_name
),
cte2 AS (
SELECT
country,
first_name,
last_name,
total_revenue,
RANK()
OVER (PARTITION BY country ORDER BY total_revenue DESC) AS rk
FROM cte
)
SELECT
country,
first_name,
last_name,
total_revenue,
rk AS rank_in_country
FROM cte2
WHERE rk <= 5
ORDER BY country, rank_in_country;

-- 6.	Identify the top-selling track for each customer --
SELECT
	first_name,
    last_name,
    t.name Track_name,
    SUM(quantity) Total_quantity
FROM customer c
LEFT JOIN invoice i on i.customer_id = c.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
LEFT JOIN track t on t.track_id = il.track_id
GROUP BY 1,2,3
ORDER BY SUM(quantity) DESC;

-- 7.	Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?
SELECT
	customer_id,
	COUNT(invoice_id) num_invoices,
	AVG(total) avg_sales
FROM invoice
GROUP BY 1
ORDER BY COUNT(invoice_id) DESC, AVG(total) DESC;

-- Q8. What is the customer churn rate?
WITH start_customers AS (
    SELECT DISTINCT customer_id
    FROM invoice
    WHERE invoice_date BETWEEN '2017-01-01' AND '2017-06-30'
),
end_customers AS (
    SELECT DISTINCT customer_id
    FROM invoice
    WHERE invoice_date BETWEEN '2020-06-01' AND '2020-12-31'
)
SELECT
    (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM start_customers)) AS churn_rate
FROM start_customers s
LEFT JOIN end_customers e
    ON s.customer_id = e.customer_id
WHERE e.customer_id IS NULL;

-- Q9. Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists. --
WITH genre_sales AS (
    SELECT 
        g.genre_id,
        g.name AS genre_name,
        SUM(inl.quantity * inl.unit_price) AS total_sales
    FROM genre g
    LEFT JOIN track t
        ON g.genre_id = t.genre_id
    LEFT JOIN invoice_line inl
        ON t.track_id = inl.track_id
    LEFT JOIN invoice iv
        ON inl.invoice_id = iv.invoice_id
    WHERE iv.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
),
pct_of_sales AS (
    SELECT 
        genre_id,
        genre_name,
        total_sales,
        ROUND((100.0 * total_sales / (SELECT SUM(total_sales) FROM genre_sales)), 2) AS pct_of_sales
    FROM genre_sales
),
artist_sales AS (
    SELECT 
        p.genre_id,
        p.genre_name,
        ar.name AS artist_name,
        SUM(inl.quantity * inl.unit_price) AS artist_sales
    FROM pct_of_sales p
    JOIN track t
        ON p.genre_id = t.genre_id
    JOIN invoice_line inl
        ON inl.track_id = t.track_id
    JOIN invoice iv
        ON iv.invoice_id = inl.invoice_id
    JOIN album a
        ON a.album_id = t.album_id
    JOIN artist ar
        ON ar.artist_id = a.artist_id
    WHERE iv.billing_country = 'USA'
    GROUP BY p.genre_id, ar.artist_id
),
final_data AS (
    SELECT 
        p.genre_name,
        a.artist_name,
        p.total_sales,
        p.pct_of_sales,
        a.artist_sales,
        ROW_NUMBER() OVER (PARTITION BY p.genre_id ORDER BY a.artist_sales DESC) AS rn
    FROM pct_of_sales p
    JOIN artist_sales a
        ON p.genre_id = a.genre_id
)
SELECT 
    genre_name,
    artist_name,
    total_sales,
    pct_of_sales,
    artist_sales
FROM final_data
WHERE rn = 1;

-- Q10. Find customers who have purchased tracks from at least 3 different+ genres --
SELECT
  CONCAT(c.first_name, ' ', c.last_name) AS name_of_customer,
  COUNT(DISTINCT g.name) AS num_of_genres
FROM customer c
LEFT JOIN invoice i       ON i.customer_id = c.customer_id
LEFT JOIN invoice_line il ON il.invoice_id = i.invoice_id
LEFT JOIN track t         ON t.track_id = il.track_id
LEFT JOIN genre g         ON g.genre_id = t.genre_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(DISTINCT g.name) >= 3
ORDER BY num_of_genres DESC, name_of_customer;

-- Q11. Rank genres based on their sales performance in the USA --
WITH cte as
(
SELECT t.genre_id, g.name,  SUM(t.unit_price * il.quantity) sale_performance FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country = 'USA'
GROUP BY 1, 2
)
SELECT name, sale_performance,
DENSE_RANK() OVER(ORDER BY sale_performance DESC) `rank` FROM cte;

-- Q12. Identify customers who have not made a purchase in the last 3 months --
SELECT
    ldc.customer_id,
    CONCAT(ldc.first_name, ' ', ldc.last_name) AS customer_name,
    ldc.latest_date
FROM
(
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        MAX(DATE(iv.invoice_date)) AS latest_date
    FROM customer c
    LEFT JOIN invoice iv
        ON c.customer_id = iv.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
) AS ldc
WHERE
    ldc.latest_date IS NULL
    OR ldc.latest_date < DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
ORDER BY
    ldc.latest_date ASC,
    customer_name;

-- SUBJECTIVE QUESTIONS --
-- Q1. Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis. --
WITH genre_sales as
(
SELECT  g.genre_id, g.name, sum(t.unit_price * il.quantity) total_revenue_for_genre FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country = 'USA'
GROUP BY 1,2
ORDER BY total_revenue_for_genre DESC
),
ranking as
(
SELECT genre_id, name, total_revenue_for_genre,
DENSE_RANK() OVER(ORDER BY total_revenue_for_genre DESC) rk FROM genre_sales
),
genre_album as
(
SELECT ranking.genre_id, ranking.name genre_name, al.title album_name FROM ranking
LEFT JOIN track t on t.genre_id = ranking.genre_id
LEFT JOIN album al on al.album_id = t.album_id
LEFT JOIN artist a on a.artist_id = al.artist_id
WHERE rk = 1
GROUP BY 1,2,3
),
best_album as
(
SELECT al.album_id, title, SUM(t.unit_price * il.quantity) FROM album al
LEFT JOIN track t on t.album_id = al.album_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
GROUP BY 1,2
ORDER BY SUM(t.unit_price * il.quantity) desc
)
SELECT genre_id, genre_name, album_name FROM genre_album 
inner join best_album on best_album.title = genre_album.album_name
LIMIT 3;

-- 2.	Determine the top-selling genres in countries other than the USA and identify any commonalities or differences. --
SELECT  g.genre_id, g.name, sum(t.unit_price * il.quantity) total_revenue_for_genre
FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country != 'USA'
GROUP BY 1,2
ORDER BY total_revenue_for_genre DESC;

-- 3.	Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies? --
WITH cte AS (
    SELECT c.customer_id, c.first_name, c.last_name,
    MIN(iv.invoice_date) AS first_purchase,
    MAX(iv.invoice_date) AS latest_purchase,
    COUNT(iv.invoice_date) AS total_purchases,
    SUM(iv.total) AS total_sales,
    SUM(inl.quantity) AS total_items
    FROM customer c
    LEFT JOIN invoice iv
    ON c.customer_id = iv.customer_id
    LEFT JOIN invoice_line inl
    ON iv.invoice_id = inl.invoice_id
    GROUP BY customer_id
),
cte2 AS (
    SELECT customer_id, CONCAT(first_name,' ',last_name) AS customer_name,
    ABS(TIMESTAMPDIFF(MONTH, first_purchase, latest_purchase)) AS customer_tenure,
    total_purchases, total_sales, total_items
    FROM cte
),
cte3 AS (
    SELECT ROUND(AVG(customer_tenure),2) AS avg_customer_tenure
    FROM cte2
),
cte4 AS (
    SELECT *, CASE
        WHEN customer_tenure > (SELECT avg_customer_tenure FROM cte3) THEN "Long_Term_Customer"
        ELSE "Short_Term_Customer"
        END AS category_customers
    FROM cte2
)
SELECT category_customers,
COUNT(category_customers) AS type_customers_count,
SUM(total_purchases) AS overall_purchases,
SUM(total_sales) AS overall_sales,
SUM(total_items) AS overall_items
FROM cte4
GROUP BY category_customers;

-- 4.	Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives? --
SELECT
  LEAST(g1.name, g2.name) AS genre1,
  GREATEST(g1.name, g2.name) AS genre2,
  COUNT(*) AS times_bought_together
FROM invoice_line il1
JOIN invoice_line il2
  ON il1.invoice_id = il2.invoice_id
  AND il1.track_id < il2.track_id 
JOIN track t1 ON t1.track_id = il1.track_id
JOIN track t2 ON t2.track_id = il2.track_id
JOIN genre g1  ON g1.genre_id = t1.genre_id
JOIN genre g2  ON g2.genre_id = t2.genre_id
WHERE g1.name IS NOT NULL
  AND g2.name IS NOT NULL
GROUP BY genre1, genre2
ORDER BY times_bought_together DESC;

SELECT
  LEAST(a1.title, a2.title) AS album1,
  GREATEST(a1.title, a2.title) AS album2,
  COUNT(*) AS times_bought_together
FROM invoice_line il1
JOIN invoice_line il2
  ON il1.invoice_id = il2.invoice_id
  AND il1.track_id < il2.track_id
JOIN track t1 ON t1.track_id = il1.track_id
JOIN track t2 ON t2.track_id = il2.track_id
JOIN album a1  ON a1.album_id = t1.album_id
JOIN album a2  ON a2.album_id = t2.album_id
WHERE a1.title IS NOT NULL
  AND a2.title IS NOT NULL
GROUP BY album1, album2
ORDER BY times_bought_together DESC;

SELECT
  LEAST(ar1.name, ar2.name) AS artist1,
  GREATEST(ar1.name, ar2.name) AS artist2,
  COUNT(*) AS times_bought_together
FROM invoice_line il1
JOIN invoice_line il2
  ON il1.invoice_id = il2.invoice_id
  AND il1.track_id < il2.track_id
JOIN track t1 ON t1.track_id = il1.track_id
JOIN track t2 ON t2.track_id = il2.track_id
JOIN album a1 ON a1.album_id = t1.album_id
JOIN album a2 ON a2.album_id = t2.album_id
JOIN artist ar1 ON ar1.artist_id = a1.artist_id
JOIN artist ar2 ON ar2.artist_id = a2.artist_id
WHERE ar1.name IS NOT NULL
  AND ar2.name IS NOT NULL
GROUP BY artist1, artist2
ORDER BY times_bought_together DESC;

-- 5.	Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors? --
WITH mycte AS (
    SELECT 
        billing_country,
        billing_city,
        billing_state,
        invoice_id,
        total,
        customer_id,
        EXTRACT(YEAR FROM invoice_date) AS year
    FROM invoice
),

city_level_churn_analysis_over_cohort_years AS (
    SELECT 
        ct1.billing_country AS country,
        ct1.billing_city AS city,
        ct1.year AS start_year,
        COUNT(DISTINCT ct1.invoice_id) AS num_invoices,
        SUM(ct1.total) AS total_sales,
        ROUND(
            (
                COUNT(DISTINCT ct1.customer_id) 
                - COUNT(DISTINCT ct2.customer_id)
            ) * 100.0 / COUNT(DISTINCT ct1.customer_id), 
        2) AS churn_rate
    FROM mycte ct1
    LEFT JOIN mycte ct2 
        ON ct1.customer_id = ct2.customer_id
        AND ct1.billing_city = ct2.billing_city
        AND ct2.year = ct1.year + 1
    GROUP BY ct1.billing_country, ct1.billing_city, ct1.year
)

SELECT 
    country,
    city,
    COUNT(start_year) AS no_of_years_present,
    ROUND(AVG(churn_rate), 2) AS avg_churn_rate,
    SUM(num_invoices) AS total_purchases,
    ROUND(AVG(total_sales), 2) AS avg_sales
FROM city_level_churn_analysis_over_cohort_years
GROUP BY country, city
ORDER BY country, city;

-- 6.	Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk? --
SELECT i.customer_id, CONCAT(first_name, " ", last_name) name, billing_country, invoice_date, SUM(total) total_spending, COUNT(invoice_id) num_of_orders FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
GROUP BY 1,2,3,4
ORDER BY name;

-- 7.	Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing? --
WITH customer_activity AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(i.invoice_id) AS total_purchases,
        SUM(i.total) AS total_spent,
        DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS tenure_days,
        ROUND(SUM(i.total) / NULLIF(COUNT(i.invoice_id), 0), 2) AS avg_spend_per_purchase
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT
    customer_name,
    CASE
        WHEN tenure_days >= 1200
             AND total_purchases >= 12
             AND total_spent > 100
        THEN 'High CLV'
        
        WHEN tenure_days BETWEEN 1000 AND 1199
             AND total_purchases BETWEEN 9 AND 11
             AND total_spent BETWEEN 70 AND 100
        THEN 'Medium CLV'
        
        ELSE 'Low CLV'
    END AS clv_segment
FROM customer_activity
ORDER BY total_spent DESC;


-- 10.	How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album? --
ALTER TABLE album
ADD ReleaseYear INT;

SELECT * FROM album
LIMIT 5;

-- 11.	Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information. --
SELECT billing_country, 
COUNT(DISTINCT customer_id) num_of_customers, 
AVG(total) Average_total_amount, 
COUNT(track_id) num_of_tracks 
FROM invoice i
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1;

SELECT customer_id, COUNT(DISTINCT track_id) num_of_tracks_per_customer FROM invoice i
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1;