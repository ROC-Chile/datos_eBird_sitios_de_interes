#SCRIPT PARA EXTRAER DATOS DE eBIRD PARA SITIOS DE INTERÉS

#activar paquetes (instalar en su computador previamente)
library(auk)
library(dplyr)
library(ggplot2)
library(lubridate)
library(sf)
library(tibble)
library(tidyr)
library(readr)

#importar los datos de observaciones
f_ebd <- "ebd_CL_smp_relJul-2023.txt" #especificar el pathway para llegar al lugar donde está almacenado en su computador 
obs <- read_ebd(f_ebd)

#convertir los "X" a NA y transformar conteos a números enteros
obs$observation_count <- if_else(obs$observation_count == "X", NA_character_, obs$observation_count) %>% 
  as.integer()
  
#leer el shape file o .kml para el polígono del IBA
#evitar archivos .kmz
poly <- read_sf("Aconcagua.kml") #insertar nombre de archivo propio

#leer planilla con categoría de conservacion de las especies
cat <- read.csv("Lista aves de chile.csv")
cat <- cat %>% select(nombre_cientifico,nombre_comun,categoria_IUCN,categoria_MMA,status)

#filtrar la base de datos para retener solo las observaciones que cumplan los criterios que uno establezca
#en este caso solo queremos retener listas con distancias recorridas menores a 10km y de una duracion menor a 6 horas
obs_fil <- obs %>%
  # 2. definir filtros
  filter(protocol_type %in% c("Traveling", "Stationary"),
         duration_minutes < 6 * 60,
         effort_distance_km < 10 | protocol_type == "Stationary",
         exotic_code == "N") 

#seleccionar solo las columnas necesarias para reducir tamaño del dataframe
obs_lim <- obs_fil %>%
  select(sampling_event_identifier,
         taxonomic_order,
         common_name,
         scientific_name,
         observation_count,
         breeding_category,
         latitude,
         longitude,
         observation_date)

# cambiar jerarquía de categorias de códigos reproductivos a una jerarquía numérica
obs_lim <- obs_lim %>%
  mutate(breeding_category = recode(breeding_category,'C1'=1,'C2'=2,'C3'=3,'C4'=4),
         breeding_category = as.integer(as.character(breeding_category)))

# Transformaciones del polígono
# transformar objeto a formato shape file
ebd_sf <- obs_lim %>% 
  select(longitude, latitude) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# transformar poligono para tener el mismo crs
poly_ll <- st_transform(poly, crs = st_crs(ebd_sf))

# opcionalmente se puede incluir un buffer alrededor del polígono para incluir datos de listas que pudieran haber empezado fuera del polígono
poly_ll_buffer <- st_buffer(poly_ll, dist = 1000) # en este caso agregamos un buffer the 1km

# identificar puntos dentro del poligono
in_poly <- st_within(ebd_sf, poly_ll_buffer, sparse = FALSE)

# Filtrado final de los datos para obtener solo los datos que caen dentro del polígono
ebd_in_poly <- obs_lim[in_poly[, 1], ]


## CREAR TABLA RESUMEN DE DATOS
#lista de especies registradas, nombre común, científico y orden taxono
especie <-   ebd_in_poly %>% 
  distinct(common_name,scientific_name,taxonomic_order) %>% 
  arrange(common_name) %>%
  distinct(common_name, .keep_all = TRUE)

#lista de especies registradas durante el último año y máximos para ese año
registro_último_año <-  ebd_in_poly %>% 
  filter(year(observation_date) == year(max(observation_date))) %>% 
  group_by(common_name) %>% 
  arrange(desc(observation_count)) %>%  # Ordenar en orden descendente de conteo
  summarise(conteo_max_último_año = max(observation_count, na.rm=TRUE),checklist.x = first(sampling_event_identifier),
            conteo_max_último_año = replace(conteo_max_último_año, conteo_max_último_año == -Inf, 0)) %>%
  mutate(registro_último_año = TRUE)

#conteo máximo histórico para cada especie registrada en el polígono
conteo_max_h <- ebd_in_poly %>% 
  group_by(common_name) %>%
  arrange(desc(observation_count)) %>%
  slice(1) %>%  # Tomar solo la primera fila (máximo conteo)
  summarise(conteo_max_h = max(observation_count, na.rm=TRUE),
            año_max_h = max(year(observation_date)), 
            checklist.y = first(sampling_event_identifier))

#promedio de conteo en los registros de los últimos 5 años
prom_conteo_5_años <- ebd_in_poly %>% 
  filter(year(observation_date) >= (year(max(observation_date)) - 4)) %>% 
  group_by(common_name) %>% 
  summarise(prom_conteos_5_años = round(mean(observation_count, na.rm=TRUE)))

#código reproductivo más alto registrado para cada especie en el polígono
cod_rep <- ebd_in_poly %>% 
  group_by(common_name) %>% 
  summarise(cod_rep = max(breeding_category, na.rm = TRUE),
            cod_rep = replace(cod_rep, cod_rep == -Inf, 0))

#crear tabla resumen                                                  
tabla_datos <- left_join(especie,registro_último_año, by = "common_name") %>%
  left_join(.,conteo_max_h, by = "common_name") %>%
  left_join(.,prom_conteo_5_años, by = "common_name") %>%
  left_join(.,cod_rep, by = "common_name") %>%
  left_join(., cat, by = c("scientific_name" = "nombre_cientifico")) %>% 
  group_by(common_name) %>%
  select("nombre_comun","common_name","scientific_name","registro_último_año","conteo_max_último_año","checklist.x","conteo_max_h","año_max_h","checklist.y","prom_conteos_5_años","cod_rep","categoria_MMA","categoria_IUCN","taxonomic_order","status")
  slice(1) #remueve las filas de especie repetidas por tener subespecie

#ordenar la tabla según orden taxonómico, reemplazar NAs y números infinitos por 0
tabla_datos <- tabla_datos %>%
  arrange(taxonomic_order) %>% #ordenar la tabla de acuerdo a orden taxonómico
  mutate_all(function(x) ifelse(is.infinite(x), 0, x)) %>% #reemplaza numeros infinitos por 0, cuando todos los registros de la especie fueron ingresados como 'X' 
  select(-taxonomic_order)%>% #quita la columna de numero taxonomico
  rename(nombre_inglés = common_name, nombre_cientifico = scientific_name) #cambia el nombre de la columna para que todos estén en castellano

#remplaza NA con 0 en columnas numéricas
tabla_datos <- tabla_datos %>%
  mutate(conteo_max_último_año = ifelse(is.na(conteo_max_último_año), 0, conteo_max_último_año),
         prom_conteos_5_años = ifelse(is.na(prom_conteos_5_años), 0, prom_conteos_5_años))

#remplaza NA con 0 en columna de characteres
tabla_datos$registro_último_año <- replace(tabla_datos$registro_último_año, is.na(tabla_datos$registro_último_año),FALSE)

# EXPORTAR LA TABLA COMO .CSV
write_csv(tabla_datos, "datos eBird Aconcagua.csv")


############ HERRAMIENTAS ADICIONALES ################

##GRAFICAR LA UBICACIÓN DE LOS DATOS DENTRO DEL POLÍGONO
#seleccionar filas 159 - 167 y ejecutar para crear mapa
par(mar = c(0, 0, 0, 0))
plot(poly %>% st_geometry(), col = "white", border = NA)
plot(ebd_sf[in_poly[, 1], ], 
     col = "grey30", pch = 19, cex = 0.5, 
     add = TRUE)
legend("top", 
       legend = "Ubicación datos eBird dentro del poligono",
       pch = 19,
       bty = "n")
