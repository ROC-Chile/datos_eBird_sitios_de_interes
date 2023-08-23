## Código para extraer datos del eBird Basic Dataset (EBD) para sitios prioritarios
Este código permite extraer datos del EBD y resumir la información registrada para un área geográfica de interés utilizando un polígono.

Para correr este código se requieren de tres archivos.
1) El [eBird Basic Dasaset](https://ebird.org/science/use-ebird-data/download-ebird-data-products) (EBD) que se puede solicitar en el siguiente [link](https://ebird.org/data/download?_gl=1*efb2q5*_ga*MTQxMzEzODEzMi4xNjc5NTA3MTA3*_ga_QR4NVXZ8BM*MTY5MjYyNTc0MC4xNTMuMS4xNjkyNjI1NzU4LjQyLjAuMA..&_ga=2.200421294.1401622184.1692625740-1413138132.1679507107). La base de datos es gratuita, solo es necesario hacer la solicitud a través de la página. 
2) El [polígono](https://github.com/ROC-Chile/extraccion_datos_eBird_sitios_prioritarios/blob/main/Bahia%20Coquimbo.kml) del área de interés, que en este caso es un Important Bird Area (IBA) de la Bahía de Coquimbo, Chile. El paquete "sf" utilizado acepta archivos en formato .shp o .kml
3) **Opcional** Un [archivo](https://github.com/ROC-Chile/extraccion_datos_eBird_sitios_prioritarios/blob/main/Lista%20aves%20de%20chile.csv) con nombres locales y categorías de conservación de las especies. En este caso, un archivo con el listado de aves de Chile y su categoría de conservación.

Este ejemplo fue desarrollado por la [(ROC)](http://www.redobservadores.cl) como una herrmienta para hacer uso de la base de datos abierta de eBird para obtener información importante de sitios prioritarios para la conservación de aves de Chile. Sin embargo, también se puede utilizar de forma general para obtener datos de aves de cualquier área geógráfica de interés.


**Funcionalidades aún por desarrollar:**
- Columna que indica en cuantos de los ultimos 5 años hubo por lo menos un registro de la especie
- Columna de tasa relativa de encuentro
- Función para especificar un buffer que agranda el perimetro del polígono, para incluir listas adjacentes al área de interés
