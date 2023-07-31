# 1.Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region
SELECT DISTINCT market
FROM dim_customer
WHERE
    customer = "Atliq Exclusive"
    AND region = "APAC";

# 2. What is the percentage of unique product increase in 2021 vs. 2020?
WITH products_2020 AS (
        SELECT
            COUNT(DISTINCT product_code) AS "unique_products_2020"
        FROM
            fact_sales_monthly
        WHERE
            fiscal_year = 2020
    ),
    products_2021 AS (
        SELECT
            COUNT(DISTINCT product_code) AS "unique_products_2021"
        FROM
            fact_sales_monthly
        WHERE
            fiscal_year = 2021
    )
SELECT
    t1.unique_products_2020,
    t2.unique_products_2021,
    ROUND( (
            t2.unique_products_2021 - t1.unique_products_2020
        ) / t1.unique_products_2020 * 100,
        2
    ) AS "percentage_chg"
FROM products_2020 t1
    CROSS JOIN products_2021 t2;

# 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
SELECT
    segment,
    COUNT(DISTINCT product_code) AS "product_count"
FROM dim_product
GROUP BY segment
ORDER BY 2 DESC;

# 4. Which segment had the most increase in unique products in 2021 vs 2020? 
WITH tb AS (
        SELECT
            segment,
            COUNT(
                DISTINCT CASE
                    WHEN fiscal_year = 2020 THEN t1.product_code
                END
            ) AS "unique_products_2020",
            COUNT(
                DISTINCT CASE
                    WHEN fiscal_year = 2021 THEN t1.product_code
                END
            ) AS "unique_products_2021"
        FROM
            fact_sales_monthly t1
            JOIN dim_product t2 ON t1.product_code = t2.product_code
        GROUP BY 1
    )
SELECT
    segment,
    unique_products_2020,
    unique_products_2021, (
        unique_products_2021 - unique_products_2020
    ) AS "difference"
FROM tb
ORDER BY 4 DESC;

# 5. Get the products that have the highest and lowest manufacturing costs.
SELECT
    t1.product_code,
    product,
    manufacturing_cost
FROM (
        SELECT
            product_code,
            manufacturing_cost
        FROM
            fact_manufacturing_cost
        WHERE
            manufacturing_cost = (
                SELECT
                    MAX(manufacturing_cost)
                FROM
                    fact_manufacturing_cost
            )
            OR manufacturing_cost = (
                SELECT
                    MIN(manufacturing_cost)
                FROM
                    fact_manufacturing_cost
            )
    ) t1
    JOIN dim_product t2 ON t1.product_code = t2.product_code;

# 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
SELECT
    t1.customer_code,
    customer,
    ROUND(
        AVG(pre_invoice_discount_pct),
        4
    ) AS "average_discount_percentage"
FROM
    fact_pre_invoice_deductions t1
    LEFT JOIN dim_customer t2 ON t1.customer_code = t2.customer_code
WHERE
    market = "India"
    AND fiscal_year = 2021
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 5;

# 7.Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
# This analysis helps to get an idea of low and high-performing months and take strategic decisions.
SELECT
    MONTHNAME(date) "Month",
    YEAR(date) "Year",
    ROUND(
        SUM(sold_quantity * gross_price),
        2
    ) AS "Gross sales Amount"
FROM (
        SELECT
            t1.date,
            t1.customer_code,
            t1.sold_quantity,
            t2.gross_price
        FROM
            fact_sales_monthly t1
            JOIN fact_gross_price t2 ON t1.product_code = t2.product_code
            AND t1.fiscal_year = t2.fiscal_year
    ) tb
WHERE customer_code IN (
        SELECT customer_code
        FROM dim_customer
        WHERE
            customer = "Atliq Exclusive"
    )
GROUP BY 1, 2 ;


# 8. In which quarter of 2020, got the maximum total_sold_quantity?
WITH tb AS (
        SELECT (
                CASE
                    WHEN MONTH(date) IN (9, 10, 11) THEN "Q1"
                    WHEN MONTH(date) IN (12, 1, 2) THEN "Q2"
                    WHEN MONTH(date) IN (3, 4, 5) THEN "Q3"
                    ELSE "Q4"
                END
            ) AS "Quarter",
            sold_quantity
        FROM
            fact_sales_monthly
    )
SELECT
    Quarter,
    ROUND(SUM(sold_quantity)/1000000,2) AS "total_sold_quantity_in_millions"
FROM tb
GROUP BY 1;

# 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
WITH tb AS (
        SELECT
            channel,
            ROUND(
                SUM(sold_quantity * gross_price)/1000000,
                2
            ) AS "gross_sales_in_millions"
        FROM
            fact_sales_monthly t1
            JOIN dim_customer t2 ON t1.customer_code = t2.customer_code
            JOIN fact_gross_price t3 ON t1.product_code = t3.product_code
            AND t1.fiscal_year = t3.fiscal_year
        WHERE
            t1.fiscal_year = 2021
        GROUP BY 1
    )
SELECT
    channel,
    gross_sales_in_millions,
    ROUND(
        gross_sales_in_millions / SUM(gross_sales_in_millions) OVER () * 100,
        2
    ) AS "percentage"
FROM tb
ORDER BY 3 DESC;

# 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
WITH tb AS (
        SELECT
            product_code,
            SUM(sold_quantity) AS "total_sold_quantity"
        FROM
            fact_sales_monthly
        WHERE
            fiscal_year = 2021
        GROUP BY 1
    ), tb2 AS (
        SELECT
            division,
            tb.product_code,
            CONCAT(product, " [",variant,"]") AS "Product",
            total_sold_quantity,
            RANK() OVER (
                PARTITION BY division
                ORDER BY
                    total_sold_quantity DESC
            ) AS "rank_order"
        FROM tb
            JOIN dim_product t2 ON tb.product_code = t2.product_code
    )
SELECT *
FROM tb2
WHERE rank_order <= 3;