CREATE TABLE maestro_ventas (
    created_date DATETIME NOT NULL, -- Fecha en la que se realizó la venta
    operation_id VARCHAR(255) NOT NULL, -- Identificador único de la operación/venta
    product_id VARCHAR(255) NOT NULL, -- Identificador único del producto
    amount DECIMAL(10, 2) NOT NULL -- Precio de venta del producto en USD
);
