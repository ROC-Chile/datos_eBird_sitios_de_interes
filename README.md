# Código para extraer de datos eBird para sitios prioritarios
Este código permite filtrar la base de datos de eBird y resumir la información registrada en un área geográfica de interés.

Para correr este código se requieren de tres archivos.
1) El [eBird Basic Dasaset](https://ebird.org/science/use-ebird-data/download-ebird-data-products) (EBD) que se puede solicitar en el siguiente [link](https://ebird.org/data/download?_gl=1*efb2q5*_ga*MTQxMzEzODEzMi4xNjc5NTA3MTA3*_ga_QR4NVXZ8BM*MTY5MjYyNTc0MC4xNTMuMS4xNjkyNjI1NzU4LjQyLjAuMA..&_ga=2.200421294.1401622184.1692625740-1413138132.1679507107). La base de datos es gratuita, solo es necesario hacer la solicitud a través de la página. 
2) El [polígono](https://github.com/ROC-Chile/extraccion_datos_eBird_sitios_prioritarios/blob/main/Bahia%20Coquimbo.kml) del área de interés, que en este caso es IBA. Este código acepta archivos en formato .shp o .kml
3) Un [archivo](https://github.com/ROC-Chile/extraccion_datos_eBird_sitios_prioritarios/blob/main/Lista%20aves%20de%20chile.csv) adicional con las categorias de conservacion de las especies posibles en el área (opcional).

Este ejemplo se desarrolla por la [(ROC)](http://www.redobservadores.cl) como una herrmienta para hacer uso de la base de datos abierta de eBird para obtener información importante para sitios prioritarios para la conservación de aves. Sin embargo, también es útil para obener datos de cualquier área de interés.


**Funcionalidades aún por desarrollar:**
- Columna que indica en cuantos de los ultimos 5 años hubo por lo menos un registro de la especie
- Columna de tasa relativa de encuentro
- Función para especificar un buffer que agranda el perimetro del polígono, para incluir listas adjacentes al área de interés
