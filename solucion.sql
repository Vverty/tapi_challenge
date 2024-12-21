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
),
cost_revenue AS    
(
	SELECT 
		A.product_id, 
		A.product_description, 
		ROUND(SUM(amount_unit * quantity_units) / SUM(quantity_units),2) AS avg_unit_cost, -- Precio Promedio Ponderado
        unit_sale_price
	FROM maestro_compras AS A
    LEFT JOIN 
    (
		SELECT DISTINCT amount AS unit_sale_price, product_id FROM maestro_ventas
    ) AS B
    ON A.product_id = B.product_id
	GROUP BY 1,2,4
),
pre_analisis AS    
(
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
		END AS projected_days_without_stock,
		B.estimated_aggregated_sales + @stock_seguridad AS optimal_stock,
		CASE 
			WHEN B.estimated_aggregated_sales = 0 -- Si las ventas estimadas de los proximos 3 dias son 0
				AND S.stock < @stock_seguridad -- El stock actual es menor al stock de seguridad
			THEN @stock_seguridad - S.stock -- Compro la diferencia entre el stock y el stock de seguridad
			WHEN B.estimated_aggregated_sales = 0 -- Si las ventas estimadas de los proximos 3 dias son 0
				AND S.stock >= @stock_seguridad -- El stock actual es mayor al stock de seguridad
			THEN 0 -- No compro nada
			WHEN S.stock >= (B.estimated_aggregated_sales + @stock_seguridad) -- Si el stock me alcanza para cubrir las ventas de 3 días + el stock de seguridad
			THEN 0 -- No compro nada
		ELSE B.estimated_aggregated_sales + @stock_seguridad - S.stock -- Si el stock se me va a agotar, compro las ventas de 3 dias menos el actual asi renuevo el ciclo
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
),
analisis AS    
(
	SELECT 
		*,
		stock * avg_unit_cost AS current_stock_value ,
		ROUND(((unit_sale_price - avg_unit_cost) * 0.2) * (stock - today_refund),2) AS net_income 
	FROM 
		(
			SELECT
				A.*,
				CASE 
					WHEN today_purchase > 0
					THEN 0
				ELSE stock - estimated_aggregated_sales - @stock_seguridad
				END AS today_refund,
				B.avg_unit_cost,
				B.unit_sale_price
			FROM pre_analisis AS A   
			LEFT JOIN cost_revenue AS B   
				ON A.product_id = B.product_id
		) AS A
)
SELECT 
	product_id, 
	product_description,
	stock AS current_stock, -- 3. Cantidad de unidades del stock actual.
	current_stock_value, -- 3. Valor total del stock actual.
	avg_daily_sales, -- Ventas diarias promedio.
	estimated_aggregated_sales, -- avg_daily_sales + @stock_seguridad
	days_until_stocks_out, -- Días hasta quebrar stock.
	projected_days_without_stock, -- Tiempo de demora en salir del quiebre de stock.
	optimal_stock, -- Stock óptimo.
	today_purchase, -- 1. Cantidad de pines a comprar.
	today_refund, -- 2. Cantidad de pines a devolver.
	avg_unit_cost, -- Costo unitario promedio (PPP).
	unit_sale_price, -- Precio de venta unitario.
	net_income -- 4. Ingreso neto post devolución de sobrestock.
FROM analisis