#Read landcover hdf files and write them out as tif files
#This process is not paralleled 
#######################################################################
library(terra)
library(tools)

main_dir <- "/Volumes/forecast_predictors/NASA_Land_Cover/"
setwd(main_dir)

# Return the list of sub-folders
folder_list <- list.dirs(path = '.', full.names = FALSE, recursive = FALSE)

for (folder in 1:length(folder_list)){
  # Add the name of sub-folder to the main directory
  work_dir <- paste(sep="",main_dir,folder_list[folder])
  setwd(work_dir)
  print(folder_list[folder])
  
  # Return the list of hdf files in the current sub-directory
  hdf_files <- list.files(path = '.', pattern = "\\.hdf$")
  for (myfile in 1:length(hdf_files)) {
    # Read the hdf file
    open_hdf <- sds(hdf_files[myfile])
    # Select the second class -- U of Maryland
    open_hdf <- open_hdf[2]
    # Split the filename and select the name without exe
    filename <- file_path_sans_ext(hdf_files[myfile])
    # Add ".tif" as a exe for a new filename
    filename <- paste(sep="",filename,".tif")
    print(filename)
    # Write out the TIFF file
    writeRaster(open_hdf, filename = filename, overwrite = TRUE)
  }
}

#######################################################################
#Creating an arbitrary polygon to crop landcover tif files.
#The original files cover the whole world, but we just want the US
#######################################################################

#https://mhallwor.github.io/_pages/basics_SpatialPolygons
#https://www.earthdatascience.org/courses/earth-analytics/spatial-data-r/reproject-vector-data/
#https://gis.stackexchange.com/questions/259472/polygon-and-raster-in-the-same-plot-do-not-align
#https://bookdown.org/mcwimberly/gdswr-book/raster-data-discrete-variables.html

library(raster)
#library(sp)
library(rgdal)
#library(rgeoboundaries)

#Create a polygon

# x_coord <- c(-8860972, -2670253, -7067236, -12748011)
# y_coord <- c(6373358, 5827451, 1687225, 3003111)
# xyPolygon <- sp::Polygon(cbind(x_coord, y_coord))
# 
# first_poly <- sp::Polygons(list(xyPolygon), ID = "A")
# str(first_poly,1)
# 
# spatialPoly <- sp::SpatialPolygons(list(first_poly), proj4string = CRS())
# 
# #write out as a shapefile (polygon)
# shapefile(spatialPoly, file="/Volumes/forecast_predictors/shapefiles/landCover_polygon.shp")

#Reproject the shapefile
shpFile <- readOGR("/Volumes/forecast_predictors/shapefiles/landCover_polygon.shp")
testRaster <- raster("/Volumes/forecast_predictors/NASA_Land_Cover/world/2008/2008_NASA_Land_Cover.tif")
crs(shpFile) <- crs(testRaster)

# plot(testRaster)
# plot(shpFile, add=T, col="purple", border = "black")

main_dir <- '/Volumes/forecast_predictors/NASA_Land_Cover/world/'
setwd(main_dir)
dest_dir <- '/Volumes/forecast_predictors/NASA_Land_Cover/US_buffered/'

year_folders <- list.files(main_dir)

for (year in 1:length(year_folders)) {
  year_path <- paste(sep = "", main_dir, year_folders[year], '/')
  print(year_path)
  setwd(year_path)
  world_LC_map <- list.files(year_path)
  LC_raster <- raster(world_LC_map)
  destFolder <- paste(sep = "", dest_dir, year_folders[year], '/')
  filename <- paste(sep = "", destFolder, "cropped_", year_folders[year],
                    "_LandCover.tif")
  cat("Cropping process started for:\n", filename)
  cropped_map <- raster::crop(LC_raster, extent(shpFile),
                              filename, format="GTiff", overwrite=T)
  cat("Cropping completed!")
}



#######################################################################
#In this section, we reclassified and aggregated them 6 by 6 cells (3km resoultion)
#Then, reprojected and resampled each landcover map with the eBird map
#######################################################################
library(raster)
#library(rgdal)

main_dir <- "/Volumes/forecast_predictors/NASA_Land_Cover/US_buffered/"
setwd(main_dir)
LC_2008 <- raster("/Volumes/forecast_predictors/NASA_Land_Cover/US_buffered/2008/cropped_2008_LandCover.tif")
og_class <- unique(LC_2008)
defltClass <- c(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
eBird <- raster("/Volumes/forecast_predictors/ebird_raster/ebird_raster_template.tif")

yearfolders <- list.files(main_dir)

for (year in 1:length(yearfolders)) {
  tiff_file <- paste(sep = "", main_dir,
                     yearfolders[year], "/", "cropped_",
                     yearfolders[year], "_LandCover.tif")
  LC <- raster(tiff_file)
  for (i in 1:length(defltClass)) {
    newClass <- replace(defltClass, i, 1)
    print(newClass)
    df <- data.frame(og_class, newClass)
    print(df)
    cat("Reclassifying class ", i-1, " for ", yearfolders[year], " Land Cover\n")
    LC_classified <- subs(LC, df)
    cat("Reclassifying completed!\n")
    cat("Aggregating class ", i-1, " for ", yearfolders[year], " Land Cover\n")
    LC_aggregated <- raster::aggregate(LC_classified, fact = c(6,6),
                                       fun = mean)
    cat("Aggregating completed!\n")
    cat("Reprojecting class ", i-1, " for ", yearfolders[year], " Land Cover\n")
    LC_projected <- projectRaster(LC_aggregated, eBird, res = c(2962.807,2962.807),
                                  method = "ngb")
    cat("Reprojecting completed!\n")
    filename <- paste(sep = "", main_dir,
                      yearfolders[year], "/", "resampled_", yearfolders[year],
                      "_LandCoverType", i-1, ".tif")
    cat("Resampling and storing class ", i-1, " for ", yearfolders[year], " Land Cover\n")
    LC_resampled <- resample(LC_projected, eBird,
                             method = "ngb", filename = filename,
                             format = "GTiff", overwrite=TRUE)
    
  }
  cat("The ", yearfolders[year], " folder is done!!\n")
}

#######################################################################
#We removed NAs from the US mainland by using a 3x3 window to replace NAs
#with neighboring values. This section uses parallel processing
#######################################################################
gc()
library(raster)
library(foreach)
library(doParallel)

main.dir <- "/Volumes/forecast_predictors/NASA_Land_Cover/3_US_LC_classified/"
dest.dir <- "/Volumes/forecast_predictors/NASA_Land_Cover/4_US_LC_noNA_classified/"

fill.na <- function(rasterObject, i=5) {
  if(is.na(rasterObject)[i]) {
    return(mean(rasterObject, na.rm=TRUE))
  } else {
    return(rasterObject[i])
  }
}

year.folders <- list.files(main.dir)

for (year in 1:length(year.folders)) {
  year.path <- paste(sep = "", main.dir, year.folders[year], '/')
  
  lc.files <- list.files(year.path)
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  foreach (lc.tif = 1:length(lc.files), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    lc.path <- paste(sep = "", year.path, lc.files[lc.tif])
    lc.raster <- raster::raster(lc.path)
    
    noNA.lc.raster1 <- focal(lc.raster, w = matrix(1,3,3), fun = fill.na, 
                                    pad = TRUE, na.rm = FALSE )
    noNA.lc.raster2 <- focal(noNA.lc.raster1, w = matrix(1,3,3), fun = fill.na, 
                             pad = TRUE, na.rm = FALSE )
    
    dest.path <- paste(sep = "", dest.dir, year.folders[year], '/')
    ifelse(!dir.exists(file.path(dest.path)), 
           dir.create(file.path(dest.path), recursive = TRUE), FALSE)
    
    filename <- paste(sep = "", dest.path, lc.files[lc.tif])
    raster::writeRaster(noNA.lc.raster2, filename = filename, format = 'GTiff',
                        overwrite=TRUE)
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
  gc()
}




