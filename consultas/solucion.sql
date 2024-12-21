/*
--------------------------------------------------------------------------------
-- Script Name:    solucion.sql
-- Description:    El siguiente script tiene como finalidad hacer un análisis del stock de pines digitales de Tapi.   
--                 Analiza cuestiones como las compras y devoluciones diarias, valor del stock inmovilizado, ingreso neto, entre otras.
--                 
-- Author:         [Felipe Lorenzo]
-- Created Date:   [2024-12-21]
-- Last Modified:  [2024-12-21]
-- Version:        1.0
--
-- Parameters:
--   - @stock_seguridad: Define la cantidad mínima de pines que deben mantenerse como stock de seguridad.
--   - @demora_reposicion: Define el número de días estimados para el reabastecimiento de stock.
--
-- Output:
--   - current_stock: Cantidad de unidades del stock actual.
--   - current_stock_value: Valor total del stock actual.
--   - avg_daily_sales: Ventas diarias promedio.
--   - estimated_aggregated_sales: Ventas estimadas para los próximos @demora_reposicion días.
--   - days_until_stocks_out: Días hasta que se agote el stock.
--   - projected_days_without_stock: Proyección de días sin stock.
--   - optimal_stock: Stock óptimo que debe mantenerse.
--   - today_purchase: Cantidad de pines a comprar hoy.
--   - today_refund: Cantidad de pines a devolver hoy si hay sobrestock.
--   - avg_unit_cost: Costo unitario promedio.
--   - unit_sale_price: Precio de venta unitario.
--   - net_income: Ingreso neto post devolución de sobrestock.
--
-- Change Log:
--   - 2024-12-21: Creacion inicial del script.
--------------------------------------------------------------------------------
*/

SET @stock_seguridad = 20; -- Cantidad de pines como stock de seguridad
SET @demora_reposicion = 3; -- Dias de demora en reposicion

WITH products AS
(	
	SELECT DISTINCT  -- Tabla de soporte para tener id y description de productos
		product_id,
        product_description
	FROM maestro_compras
),
purchases AS   
(
	SELECT -- Tabla para calcular cantidad de unidades compradas por producto
		product_id, 
		product_description, 
		SUM(quantity_units) AS q_units_purchased -- Suma de cantidad de unidades de cada lote de compra
	FROM maestro_compras
	GROUP BY 1,2
	ORDER BY 3 DESC
),
sales AS 
(
	SELECT --  Tabla para calcular cantidad de unidades vendidas por producto
		MV.product_id, 
        P.product_description, 
		COUNT(*) AS q_sales -- Contador de ventas (transaccional)
	FROM maestro_ventas AS MV
    INNER JOIN products AS P
		ON MV.product_id = P.product_id
	GROUP BY 1,2
	ORDER BY 3 DESC
),
stock AS    
(
	SELECT -- Tabla para calcular el stock actual por producto
		P.product_description, 
        P.product_id,
		IFNULL(P.q_units_purchased,0) - IFNULL(S.q_sales,0) AS stock -- Q unidades compradas menos las ventas
	FROM purchases AS P  
	LEFT JOIN sales AS S   
	    ON P.product_id = S.product_id
),
daily_sales AS    
(
	SELECT -- Tabla para calcular la cantidad diaria promedio de ventas por producto
		A.product_id,
        CEIL(AVG(A.q_sales)) AS avg_daily_sales -- Se calcula promedio diario y se redondea al entero superior
	FROM    
    (
		SELECT
			DATE(created_date) AS created_date,
			product_id,
			COUNT(*) AS q_sales	-- Cantidad de ventas agrupadas por dia
		FROM maestro_ventas
		GROUP BY 1,2
    ) AS A
    GROUP BY 1
),
cost_revenue AS    
(
	SELECT -- Tabla para calcular la cantidad diaria promedio de ventas por producto
		A.product_id, 
		A.product_description, 
		ROUND(SUM(amount_unit * quantity_units) / SUM(quantity_units),2) AS avg_unit_cost, -- Costo unitario calculado bajo Precio Promedio Ponderado
        unit_sale_price
	FROM maestro_compras AS A
    LEFT JOIN 
    (
		SELECT DISTINCT 
			amount AS unit_sale_price, -- Precio de venta por cada producto
			product_id 
		FROM maestro_ventas
    ) AS B
    ON A.product_id = B.product_id
	GROUP BY 1,2,4
),
pre_analisis AS    
(
	SELECT  -- Tabla para hacer calculos de stock optimo, compras a realizar hoy y dias hasta quebranto
		S.product_id,
		S.product_description,
		S.stock,
		B.avg_daily_sales,
		estimated_aggregated_sales,
		ROUND(CASE WHEN B.avg_daily_sales = 0 THEN NULL ELSE S.stock / B.avg_daily_sales END, 2) AS days_until_stocks_out, -- Cuantos días me dura el stock actual con el nivel de ventas promedio
		CASE 
			WHEN B.avg_daily_sales = 0 
			THEN 0
			WHEN ROUND(S.stock / B.avg_daily_sales, 2) > 3
			THEN 0
		ELSE @demora_reposicion - ROUND(S.stock / B.avg_daily_sales, 2) 
		END AS projected_days_without_stock, -- Cuantos dias voy a estar sin stock 
		B.estimated_aggregated_sales + @stock_seguridad AS optimal_stock, -- Stock optimo
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
		END AS today_purchase -- Compra de hoy
	FROM stock AS S
	LEFT JOIN    
	(
		SELECT	
			product_id,
			IFNULL(avg_daily_sales,0) AS avg_daily_sales,
			IFNULL(avg_daily_sales * @demora_reposicion,0) AS estimated_aggregated_sales -- Ventas proyectadas para 3 días
		FROM daily_sales
	) AS B
		ON S.product_id = B.product_id
),
analisis AS    
(
	SELECT -- Tabla para realizar calculos de Q a devolver, valor de stock actual e ingreso neto post devolucion
		*,
		stock * avg_unit_cost AS current_stock_value ,
		ROUND(((unit_sale_price - avg_unit_cost) * 0.2) * (stock - today_refund),2) AS net_income 
	FROM 
		(
			SELECT
				A.*,
				CASE 
					WHEN today_purchase > 0 -- Si tuve que comprar hoy, no devuelvo nada
					THEN 0
				ELSE stock - estimated_aggregated_sales - @stock_seguridad -- Si no compre hoy, devuelvo el stock que supere mi stock optimo
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