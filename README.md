# Tapi Challenge

Este repositorio contiene la resolución del desafío planteado por **Tapi**. A continuación, se detallan las secciones principales con las respuestas y las consultas SQL que sustentan el análisis.

## Consideraciones

1. **Stock óptimo:**  
   Se considera como stock óptimo el resultado de las ventas diarias multiplicadas por la demora en reposición más el stock de seguridad. Esto asume que una vez que el stock disminuya al nivel de seguridad, se realiza una orden para que llegue justo cuando se alcance ese punto. Si el stock ya está próximo a agotarse, no tiene sentido comprar en exceso, ya que los productos llegarán después del quiebre de stock.

2. **Devoluciones:**  
   Para determinar qué productos devolver, se considera que el stock de esos productos está por encima del nivel óptimo calculado.

3. **Valuación del stock inmovilizado:**  
   El cálculo de la valuación del stock se realiza tomando el stock **previo a las devoluciones** mencionadas en el punto anterior.

4. **Ingreso neto esperado:**  
   Para este cálculo, se utiliza el stock **posterior a las devoluciones** para determinar el ingreso neto esperado de la venta de los productos restantes.

## Tabla de contenidos
- [Respuestas al desafío](#respuestas-al-desafío)
- [Consultas SQL](#consultas-sql)
- [Herramientas utilizadas](#herramientas-utilizadas)

## Respuestas al desafío
Las respuestas detalladas al desafío se encuentran disponibles en el siguiente documento de Google Sheets:  
[Respuestas al desafío - Google Sheets](https://docs.google.com/spreadsheets/d/10SQOwOGhdg-k30dsLVdzXhAceN0gsvO1kW9Kldu_1yw/edit?usp=sharing)  

## Consultas SQL
Las consultas SQL que sustentan los cálculos realizados para responder el desafío se encuentran en este repositorio de GitHub:  
[Repositorio de consultas SQL - GitHub](https://github.com/Vverty/tapi_challenge)

A su vez, se explican ahi mismo la lógica de cálculo.

Las consultas están organizadas para cubrir las diferentes partes del desafío, incluyendo:  
- Cálculo del stock óptimo y compras necesarias.  
- Identificación de pines a devolver.  
- Valor del stock inmovilizado.  
- Cálculo del ingreso neto esperado.  

## Herramientas utilizadas
Durante la resolución del desafío, se utilizaron las siguientes herramientas:  
- **GIT y GitHub**: Para el control de versiones y alojamiento del código en el repositorio.  
- **MySQL y MySQL Workbench**: Para la creación y ejecución de las consultas SQL.  
- **ChatGPT**: Como apoyo para la redacción de documentación y optimización del código.  
- **Google Sheets**: Para la presentación de los resultados y cálculos en un formato visual y accesible.  






