# aim: demo r-spatial capabilities with slr data
# See https://github.com/geocompr/geostats_18/blob/master/code/geocompr/slr.R

if(!require(elevatr)) {
  install.packages("elevatr")
}
library(elevatr)
library(raster)
library(sf)

# load data
if(!dir.exists("data")) {
  file.rename("/tmp/data.zip", "data.zip")
  # download.file("https://github.com/geocompr/geostats_18/releases/download/0.1/data.zip", "data.zip")
  unzip("data.zip")
  file.rename("pres/geocompr/data/", "data")
}

# vector data
plot(spData::world)
poland = dplyr::filter(spData::world, grepl(pattern = "Pola", name_long))
plot(st_geometry(poland))
# testing elevatr (from readme / vignette)
# data(lake)
# elevation_high = get_elev_raster(lake, z = 14, src = "aws")
# 120 MB"
# elevation = get_elev_raster(lake, z = 9, src = "aws")
# elevation_low = get_elev_raster(lake, z = 4, src = "aws")
# pryr::object_size(elevation)
# pryr::object_size(elevation_low)
# plot(elevation_low)
# mapview::mapview(elevation_low)
# cols = rainbow(5)
# plot(elevation, add = T, col = cols)

# getting a map of the szczecin coastline
# option 1 - via osmdata:
# library(osmdata)
# scz = getbb(place_name = "szczecin", format_out = "sf_polygon")
# sf::st_write(scz, "data/scz-osm.geojson")
scz = sf::read_sf("data/scz-osm.geojson")
(m = mapview::mapview(scz)) # not quite what I was after, but a good start

# option 2 - via (new+improved) mapedit
# scz_mapedit = mapedit::drawFeatures(map = m)
# sf::write_sf(scz_mapedit, "data/scz-mapedit.geojson")
scz_mapedit = sf::read_sf("data/scz-mapedit.geojson")
plot(scz_mapedit)
scz_sp = as(scz_mapedit, "Spatial")
# e = elevatr::get_elev_raster(locations = scz_sp, z = 5, src = "aws")
# raster::writeRaster(x = e, filename = "data/scz-elev-z5.tif")
e = raster("data/scz-elev-z5.tif")

# get points less than 10m above slr
e_mask = e_low = e < 10
plot(e_low)
plot(spData::world, add = T, col = NA)
e_mask[e > 10] = NA
e_low = mask(e, e_mask)
mapview::mapview(e_low)
# out-takes
# e = raster::getData(name = "SRTM", lon = c(-180, 180), lat = c(-60, 60))
writeRaster(e_low, "scz-elev-low.tif")

system.time({
  r_orig = raster::raster("data/20180816184319_429977190-14-degrees-polish-coast.tif")
  plot(r_orig)
  })
summary(r_orig)
r_agg = aggregate(r_orig, 100)
res(r_agg)
res(e)
plot(r_agg)
plot(e_low, add = T)
e_resampled = raster::resample(e, r_agg)
plot(values(r_agg), values(e_resampled))
cor(values(r_agg), values(e_resampled))^2

# r = extend(r_agg, e)
# r_low = mask(r, e_mask)

# proportion of sczezcin that is at risk from slr
e_low_crop = crop(e_low, scz)
plot(e_low_crop)
e_low_sf = spex::polygonize(e_low_crop)
e_low_intersect = st_intersection(e_low_sf, scz)
plot(scz)
plot(e_low_sf, add = T)
plot(e_low_intersect, add = TRUE, col = "blue")
sum(st_area(e_low_intersect)) / st_area(scz)


# publish
scz_buff = st_buffer(scz, dist = 0)
library(tmap)
scz$col = "red"
m = tm_shape(e_low) +
  tm_raster(alpha = 0.5) +
  tm_shape(scz_buff) + # not working...
  tm_fill(col = "red") +
  tm_shape(e_low_intersect) +
  tm_polygons() +
  tm_shape(poland) +
  tm_borders()
m
m2 = mapview::mapview(e_low) + scz
m2
tmap_save(m, "/home/robin/repos/geostats_18/data/scz-map.html")
browseURL("data/scz-map.html")

# elevation data around prague
prague = osmdata::getbb("prague", format_out = "sf_polygon")
plot(prague)
write_sf(prague, "data/prague.geojson")
prague_elev = get_elev_raster(as(prohonice, "Spatial"), z = 9, src = "aws")
writeRaster(prague_elev, "data/prague_elev.tif")
mapview::mapview(prague_elev)

# detour: finding the resolution:
p = stplanr::geo_select_aeq(shp = scz_mapedit)
e_projected = projectRaster(e, crs = p$proj4string)
summary(e)
res(e)
res(e_projected)
e1 = crop(e, extent(e, 1, 2, 1, 2)) 
values(e1) = 1:4
plot(e1)
e1xy = raster::xyFromCell(e1, cell = 1:ncell(e1))
e1df = as.data.frame(e1xy)
e1p = st_as_sf(e1df, coords = c("x", "y"), crs = 4326)
plot(e1p[1:2, ], cex = 5)
st_distance(e1p[1, ], e1p[2, ]) # 1.37 km res. (x), 1.49 km res (y) 
st_distance(e1p[1, ], e1p[3, ]) # 1.37 km res. (x), 1.49 km res (y) 

# detaour: raster -> vector conversion
e_low_crop = crop(e_low, scz)
plot(e_low_crop)
e_low_scz = spPolygons(e_low_crop)
plot(e_low_scz) # interesting
class(e_low_scz)
e_low_sf = st_as_sf(e_low_scz)
plot(e_low_sf, col = "red") # modern art!
