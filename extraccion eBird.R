#SCRIPT PARA EXTRAER DATOS EBIRD PARA SITIOS DE INTERÉS

#instalar paquetes requeridos 
install.packages('auk') #para lectura y manipulacion de base de datos de eBird
install.packages('dplyr') #para
install.packages('ggplot2') #para todas funciones de manipulacion de datos
install.packages('lubridate') #para todas funciones de manipulacion de datos
install.packages('sf') #para leer y manipular shape files

#activar paquetes
library(auk)
library(dplyr)
library(ggplot2)
library(lubridate)
library(sf)

#Este 
#importar los datos de observaciones
f_ebd <- "data/ebd_CL_relDec-2022.txt"
obs <- read_ebd(f_ebd)

#crear un objeto con el nombre del archivo que direcciona a auk para encontrarlo dentro de la carpeta principal
ebd <- auk_ebd("ebd_CL_relJune-2022.txt")

#establecer un nombre para el archivo de datos filtrados que crea auk
output_file <- "ebd_filtered_ibaschile.txt"

#leer el shape file o .kml para el polígono del IBA
#evitar archivos .kmz
poly <- read_sf("IBA.kml")

#leer planilla con categoría de conservacion de las especies
cat <- read.csv("Lista aves de chile.csv")
cat <- cat %>% select(nombre_cientifico,nombre_comun,categoria_IUCN,categoria_RCE)

#filtrar la base de datos para retener solo las observaciones que cumplan los criterios que uno establezca
#en este caso solo queremos retener listas con distancias recorridas menores a 15km y de una duracion menor a 8 horas
filtered_data <- ebd %>%
  # 2. definir filtros
  auk_bbox(poly) %>% #filtra las observaciones dentro del mínimo rectangulo que engloba al poligono
  auk_distance(distance = c(0,5)) %>% #observaciones en listas de menos de 15km
  auk_duration(duration = c(0,5*60)) %>% #observaciones en listas de menos de 8 horas
  # 3. correr filtros
  auk_filter(file = output_file,overwrite=T) %>%
  read_ebd() %>%
  glimpse()

#seleccionar solo las columnas necesarias para reducir tamano de los datos
ebird_data <- filtered_data %>%
  select(sampling_event_identifier,
         taxonomic_order,
         common_name,
         scientific_name,
         observation_count,
         breeding_category,
         latitude,
         longitude,
         observation_date)

#cambiar especies con conteo X a NA
ebird_data <- ebird_data %>%
  mutate(observation_count = if_else(observation_count == "X", NA_character_, observation_count),
         observation_count = as.integer(as.character(observation_count)))

# cambiar jerarquía de categorias de códigos reproductivos a una jerarquía numérica
ebird_data <- ebird_data %>%
  mutate(breeding_category=recode(breeding_category,'C1'=1,'C2'=2,'C3'=3,'C4'=4),
         breeding_category = if_else(is.na(breeding_category), 0, breeding_category))

#transformar los valores a una categoria numérica
ebird_data <- ebird_data %>% 
  mutate(breeding_category = as.integer(as.character(breeding_category)))

#Transformaciones del polígono
# transformar objeto a formato shape file
ebd_sf <- ebird_data %>% 
  select(longitude, latitude) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# transformar poligono para tener el mismo crs
poly_ll <- st_transform(poly, crs = st_crs(ebd_sf))

# identificar puntos dentro del poligono
in_poly <- st_within(ebd_sf, poly_ll, sparse = FALSE)

# Filtrado final de los datos para obtener solo los datos que caen dentro del polígono del IBA
ebd_in_poly <- ebird_data[in_poly[, 1], ]


# CREAR LA TABLA RESUMIENDO LOS DATOS

#lista de especies registradas
especie <-   ebd_in_poly %>% 
  distinct(common_name) %>% 
  arrange(common_name)

#lista de nombres cientificos
nombre_cientifico <-   ebd_in_poly %>% 
  group_by(common_name) %>% 
  distinct(scientific_name)

#orden taxonomico para la lista de especies
tax <- ebd_in_poly %>% 
  group_by(common_name) %>% 
  distinct(taxonomic_order)

#lista de especies registradas durante el año
registro_2020 <-  ebd_in_poly %>% 
  filter(observation_date > "2020-01-01" & observation_date < "2021-01-01") %>% 
  distinct(common_name) %>% 
  add_column(registro_2020 = 1)

#conteo máximo historico para cada especie registrada en el polígono
conteo_max_h <- ebd_in_poly %>% 
  group_by(common_name) %>%
  summarise(conteo_max_h = max(observation_count, na.rm=TRUE), año_max_h = max(year(observation_date)), checklist = first(sampling_event_identifier)) %>%
  separate(checklist, c("checklist_max_h","rest"), sep = ",") %>% #cuando hay multiples identificadores de lista por checklist los separa y mantiene solo el primer checklist ID
  select(-rest)

#conteo máximo para especies registradas el 2020
conteo_max_2020 <- ebd_in_poly %>% 
  filter(observation_date > "2020-01-01" & observation_date < "2021-01-01") %>% 
  group_by(common_name) %>%
  summarise(conteo_max_2020  = max(observation_count, na.rm=TRUE),checklist = first(sampling_event_identifier)) %>%
  separate(checklist, c("checklist_max_2020","rest"), sep = ",") %>% 
  select(-rest)

#promedio de los registros máximos de cada año entre 2016 y 2020
prom_conteo_max_2016_2020 <- ebd_in_poly %>% 
  filter(observation_date > "2016-01-01" & observation_date < "2021-01-01") %>% 
  group_by(common_name, year(observation_date)) %>% 
  summarise(conteo_max_2016_2020  = max(observation_count, na.rm=TRUE)) %>%
  summarise(prom_max_2016_2020 = round(mean(conteo_max_2016_2020)))

#código reproductivo mas alto registrado para cada especie en el polígono
cod_rep <- ebd_in_poly %>% 
  group_by(common_name) %>% 
  summarise(cod_rep = max(breeding_category))

#juntar todas las variables en una tabla                                                   
datosiba <- left_join(especie,tax, by = "common_name") %>%
  left_join(.,nombre_cientifico, by = "common_name") %>%
  add_column(registro_h = 1) %>%
  left_join(.,registro_2020, by = "common_name") %>%
  left_join(.,conteo_max_h, by = "common_name") %>%
  left_join(.,conteo_max_2020, by = "common_name") %>%
  left_join(.,prom_conteo_max_2016_2020, by = "common_name") %>%
  left_join(.,cod_rep, by = "common_name") %>%
  group_by(common_name) %>%
  slice(1) #remueve las filas de especie repetidas por tener subespecie

#agregar categoria de conservación de cada especies a nivel global y nacional
datosiba <- left_join(datosiba, cat, by='nombre_cientifico')

#ordenar la tabla segun orden taxonómico, reemplazar NAs y números infinitos por 0
datosiba <- datosiba %>%
  arrange(taxonomic_order) %>% #ordena la base de datos de acuerdo a orden taxonomico
  mutate_all(function(x) ifelse(is.infinite(x), 0, x)) %>% #reemplaza numeros infinitos por 0, cuando todos los registros de la especie fueron ingresados como 'X' 
  select(-taxonomic_order)%>% #quita la columna de numero taxonomico
  rename(especie = common_name, nombre_cientifico = scientific_name) #cambia el nombre de la columna para que todos estén en castellano

#remplaza NA con 0 en columnas numericas
datosiba <- datosiba %>%
  mutate(registro_2020 = ifelse(is.na(registro_2020), 0, registro_2020), 
         conteo_max_2020 = ifelse(is.na(conteo_max_2020), 0, conteo_max_2020),
         prom_max_2016_2020 = ifelse(is.na(prom_max_2016_2020), 0, prom_max_2016_2020))

#remplaza NA con 0 en columna de characteres
datosiba$checklist_max_2020 <- datosiba$checklist_max_2020 %>%
  replace_na(0) 

# EXPORTAR LA TABLA COMO CSV
#crea un archivo csv de la tabla en la carpeta con el nombre del IBA ingresado
write_csv(datosiba, "datos ebird IBA Bahia Coquimbo.csv")



############ HERRAMIENTAS ADICIONALES ################

#HERRAMIENTA PARA GRAFICAR LA UBICACION DE LOS DATOS DENTRO DEL POLIGONO DEL IBA
#seleccionar filas 159 - 167 y ejecutar para crear mapa
par(mar = c(0, 0, 0, 0))
plot(poly %>% st_geometry(), col = "grey30", border = NA)
plot(ebd_sf[in_poly[, 1], ], 
     col = "white", pch = 19, cex = 0.5, 
     add = TRUE)
legend("top", 
       legend = "Ubicación datos eBird dentro del poligono",
       pch = 19,
       bty = "n")

#HERRAMIENTA PARA BUSCAR TOTAL DE LISTAS CON MAXIMOS PARA UN PERIODO
ebd_in_poly %>% 
  filter(observation_date > "2000-01-01" & observation_date < "2021-01-01", common_name == "Ashy-headed Goose") %>% #ingresar rango de fechas y especie que quiere buscar
  summarise(conteo_max = max(observation_count, na.rm=TRUE),año_max_h = max(year(observation_date)),checklist = sampling_event_identifier)
