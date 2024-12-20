-- 1. Cantidad de pines a comprar

SET @current_day = '2023-09-23'; -- Suponemos que hoy es esa fecha para tener un analisis mas acertado
SET @stock_seguridad = 20; -- Cantidad de pines
SET @demora_reposicion = 3; -- Dias

WITH products AS    
(
	SELECT DISTINCT   
		product_id,
        product_description
	FROM maestro_compras
),
purchases AS   
(
	SELECT 
		product_id, 
		product_description, 
		SUM(quantity_units) AS q_units_purchased
	FROM maestro_compras
	GROUP BY 1,2
	ORDER BY 3 DESC
),
sales AS 
(
	SELECT 
		MV.product_id, 
        P.product_description, 
		COUNT(*) AS q_sales
	FROM maestro_ventas AS MV
    INNER JOIN products AS P
		ON MV.product_id = P.product_id
	GROUP BY 1,2
	ORDER BY 3 DESC
),
stock AS    
(
	SELECT 
		P.product_description, 
        P.product_id,
		IFNULL(P.q_units_purchased,0) - IFNULL(S.q_sales,0) AS stock 
	FROM purchases AS P  
	LEFT JOIN sales AS S   
	    ON P.product_id = S.product_id
),
daily_sales AS    
(
	SELECT 
		A.product_id,
        CEIL(AVG(A.q_sales)) AS avg_daily_sales
	FROM    
    (
		SELECT
			DATE(created_date) AS created_date,
			product_id,
			COUNT(*) AS q_sales	
		FROM maestro_ventas
		GROUP BY 1,2
    ) AS A
    GROUP BY 1
) 
SELECT 
	S.product_id,
    S.product_description,
    S.stock,
    B.avg_daily_sales,
    estimated_aggregated_sales,
    ROUND(CASE WHEN B.avg_daily_sales = 0 THEN NULL ELSE S.stock / B.avg_daily_sales END, 2) AS days_until_stocks_out,
    CASE 
        WHEN B.avg_daily_sales = 0 
        THEN 0
        WHEN ROUND(S.stock / B.avg_daily_sales, 2) > 3
        THEN 0
    ELSE @demora_reposicion - ROUND(S.stock / B.avg_daily_sales, 2) 
    END AS days_without_stock,
    CASE 
		WHEN B.estimated_aggregated_sales = 0 
		THEN 0
		WHEN (S.stock - B.estimated_aggregated_sales) >= (B.avg_daily_sales + @stock_seguridad) 
        THEN 0
		WHEN (S.stock - B.estimated_aggregated_sales) > 0
        THEN B.estimated_aggregated_sales + @stock_seguridad - S.stock
		WHEN (S.stock - B.estimated_aggregated_sales) <= 0
        THEN B.estimated_aggregated_sales + @stock_seguridad
	END AS today_purchase
FROM stock AS S
LEFT JOIN    
(
	SELECT	
		product_id,
        IFNULL(avg_daily_sales,0) AS avg_daily_sales,
		IFNULL(avg_daily_sales * @demora_reposicion,0) AS estimated_aggregated_sales
	FROM daily_sales
) AS B
	ON S.product_id = B.product_id


-- Siempre y cuando las compras sean diarias