CREATE TABLE maestro_compras (
    created_date DATE NOT NULL, -- Fecha en la que se realizó la compra
    product_id VARCHAR(255) NOT NULL, -- Identificador único del producto
    product_description VARCHAR(255) NOT NULL, -- Descripción del producto
    company_name VARCHAR(255) NOT NULL, -- Nombre de la empresa que provee el producto
    amount_unit DECIMAL(10, 2) NOT NULL, -- Costo unitario por producto en USD
    quantity_units INT NOT NULL -- Cantidad de unidades compradas
);