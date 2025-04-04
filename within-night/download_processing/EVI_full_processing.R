#Read NASA NDVI hdf files and write them out as tiff files
#We only extracted the second layer (EVI), and Quality check layer (QA)
#########################################################################
library(terra)
library(tools)

main_dir <- "/Volumes/forecast_predictors/NASA_NDVI/"
setwd(main_dir)

# Return the list of sub-folders (the one-year range of NDVI)
year_folders <- list.dirs(path = '.', full.names = FALSE, recursive = FALSE)

for (year in 1:length(year_folders)) {
  year_directory <- paste(sep = "", main_dir, year_folders[year], "/")
  setwd(year_directory)
  # Return the list of sub-folders (the 16-day periods of NDVI)
  period_folders <- list.dirs(path = '.', full.names = FALSE, recursive = FALSE)
  
  for (folder in 1:length(period_folders)){
    # Add the name of sub-folder to the main directory
    work_dir <- paste(sep="",year_directory,period_folders[folder])
    setwd(work_dir)
    print(period_folders[folder])
    
    # Return the list of hdf files in the current sub-directory
    hdf_files <- list.files(path = '.', pattern = "\\.hdf$")
    for (myfile in 1:length(hdf_files)) {
      # Read the hdf file
      open_hdf <- sds(hdf_files[myfile])
      # Select the second class -- 500m 16 days EVI
      # We also select the 12th class too, which is the Quality Check
      open_hdf <- open_hdf[2]
      # Split the filename and select the name without exe
      filename <- file_path_sans_ext(hdf_files[myfile])
      # Add ".tif" as an exe for a new filename
      filename <- paste(sep="",filename,".tif")
      print(filename)
      # Write out the TIFF file
      writeRaster(open_hdf, filename = filename, overwrite = TRUE)
    }
  }
}


#########################################################################
#Mosaic tiff files of EVI to create a map for the whole world.
#Note: this section is not using parallel processing
#########################################################################
library(raster)

main_dir <- "/Volumes/forecast_predictors/NASA_EVI_tif_tiles/"
setwd(main_dir)

#Return a list that includes all sub-folders 
year_folders <- list.dirs(path = ".", full.names = F, recursive = F)

for (year in 1:length(year_folders)){
  #Make a full path name for working directory
  year_path <- paste(sep = "", main_dir, year_folders[year], "/")
  setwd(year_path)
  
  period_list <- list.dirs(path = ".", full.names = F, recursive = F)
  
  for (period in 1:length(period_list)) {
    period_path <- paste(sep = "", year_path, period_list[period], "/")
    setwd(period_path)
    
    #Return the list of all TIFF files in the sub-folder
    tif_files <- list.files(path = ".", pattern = "\\.tif$")
    
    #Create an empty list and set the size of the list equal to the number of
    #TIFF files in the sub-folder
    empty_list <- vector(mode = "list", length = length(tif_files))
    
    #Load each TIFF file, and append to the empty list
    for (my_tif in 1:length(tif_files)){
      read_tif <- raster(tif_files[my_tif])
      empty_list[[my_tif]] <- read_tif
    }
    
    names(empty_list) <- NULL
    empty_list$fun <- mean
    empty_list$tolerance <- 0.5
    empty_list$quick <- F
    
    #Mosaic all rasters
    message1 <- paste(sep = "", "Mosaic process started for ", period_list[period])
    print(message1)
    raster_mosaic <- do.call(raster::mosaic, empty_list)
    print("Mosaic is complete!")
    
    #Make a file name for each TIFF file
    filename <- paste(sep = "", period_list[period], "_NASA_EVI.tif")
    
    #Write out the big TIFF file
    message2 <- paste(sep = "", "Writing out ", filename)
    print(message2)
    dest_dir <- paste(sep = "", "/Volumes/forecast_predictors/NASA_EVI/world/",
                      year_folders[year], "/", filename)
    raster::writeRaster(raster_mosaic, filename = dest_dir, overwrite =T,
                        format="GTiff")
    message3 <- paste(sep = "", "Saving ", filename, " is complete!")
    print(message3)
  }
}


#########################################################################
#Doing the same Mosaic process for QA layers to create a map for the whole world
#This section is using parallel processing
#########################################################################
#https://www.blasbenito.com/post/02_parallelizing_loops_with_r/
library(raster)
library(foreach)
library(doParallel)
parallel::stopCluster(cl = my_cluster)

main_dir <- "/Volumes/forecast_predictors/Raw_data_with_tiles/NASA_EVI_tif_tiles/QA/"
setwd(main_dir)

#Return a list that includes all sub-folders 
year_folders <- list.files(main_dir)

for (year in 1:length(year_folders)){
  #Make a full path name for working directory
  year_path <- paste(sep = "", main_dir, year_folders[year], "/")
  setwd(year_path)
  
  period_list <- list.files(year_path)
  cat(period_list, "\n")
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 5
  
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  # foreach::getDoParRegistered()
  # foreach::getDoParWorkers()
  
  foreach (period = 1:length(period_list), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    period_path <- paste(sep = "", year_path, period_list[period], "/")
    setwd(period_path)
    
    #Return the list of all TIFF files in the sub-folder
    tif_files <- list.files(path = ".", pattern = "\\.tif$")
    
    #Create an empty list and set the size of the list equal to the number of
    #TIFF files in the sub-folder
    empty_list <- vector(mode = "list", length = length(tif_files))
    
    #Load each TIFF file, and append to the empty list
    for (my_tif in 1:length(tif_files)){
      tif.path <- paste(sep = "", period_path, tif_files[my_tif])
      read_tif <- raster(tif.path)
      empty_list[[my_tif]] <- read_tif
    }
    
    names(empty_list) <- NULL
    empty_list$fun <- mean
    empty_list$tolerance <- 0.5
    empty_list$quick <- F
    
    #Mosaic all rasters
    # cat("Mosaic process started for ", period_list[period], "\n")
    
    raster_mosaic <- do.call(raster::mosaic, empty_list)
    
    # cat("Mosaic is complete!\n")
    
    #Make a file name for each TIFF file
    filename <- paste(sep = "", period_list[period], "_NASA_QA.tif")
    
    #Write out the big TIFF file
    # cat("Writing out ", filename, "\n")
    
    dest_dir <- paste(sep = "", "/Volumes/forecast_predictors/NASA_EVI/world_QA/",
                      year_folders[year], "/", filename)
    raster::writeRaster(raster_mosaic, filename = dest_dir, overwrite =T,
                        format="GTiff")
    # cat("Saving ", filename, " is complete!\n")
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
}

#########################################################################
#We cropped both EVI and QA with an arbitrary polygon to only include US
#This section is using parallel processing
#########################################################################

#https://mhallwor.github.io/_pages/basics_SpatialPolygons
#https://www.earthdatascience.org/courses/earth-analytics/spatial-data-r/reproject-vector-data/
#https://gis.stackexchange.com/questions/259472/polygon-and-raster-in-the-same-plot-do-not-align
#https://bookdown.org/mcwimberly/gdswr-book/raster-data-discrete-variables.html
#https://www.blasbenito.com/post/02_parallelizing_loops_with_r/

library(raster)
library(rgdal)
library(foreach)
library(doParallel)

#Reproject the shapefile
shpFile <- readOGR("/Volumes/forecast_predictors/shapefiles/landCover_polygon.shp")
testRaster <- raster("/Volumes/forecast_predictors/NASA_EVI/world/2008/2008_01_01_NASA_EVI.tif")
crs(shpFile) <- crs(testRaster)

# plot(testRaster)
# plot(shpFile, add=T, col="purple", border = "black")

main_dir <- '/Volumes/forecast_predictors/NASA_EVI/world/'
setwd(main_dir)
dest_dir <- '/Volumes/forecast_predictors/NASA_EVI/US_buffered_EVI/'

year_folders <- list.files(main_dir)

for (year in 1:length(year_folders)) {
  year_path <- paste(sep = "", main_dir, year_folders[year], '/')
  print(year_path)
  setwd(year_path)
  
  tif_files <- list.files(year_path, pattern = "\\.tif$")
  cat(tif_files, "\n")
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 5
  
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  # foreach::getDoParRegistered()
  # foreach::getDoParWorkers()
  
  #Parallel processing for all tif files in every year directory
  foreach (my_tif = 1:length(tif_files), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    tif.path <- paste(sep = "", year_path, tif_files[my_tif])
    print(tif.path)
    
    EVI_raster <- raster(tif.path)
    destFolder <- paste(sep = "", dest_dir, year_folders[year], '/')
    
    #If the directory doesn't exist, create it
    ifelse(!dir.exists(file.path(destFolder)), 
           dir.create(file.path(destFolder)), FALSE)
    
    filename <- paste(sep = "", destFolder, "cropped_", tif_files[my_tif])
    print(filename)
    
    cropped_map <- raster::crop(EVI_raster, extent(shpFile),
                                filename, format="GTiff", overwrite=T)
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
}

#########################################################################
#In this section we used the QA layer to correct the EVI values.
#Then aggregated the final corrected raster using 6 by 6 cells. Lastly,
#we reprojected and resampled to eBird map. This section is using parallel
#processing too.
#########################################################################
library(raster)
library(foreach)
library(doParallel)

QA.main.dir <- "/Volumes/forecast_predictors/NASA_EVI/US_buffered_QA/"
EVI.main.dir <- "/Volumes/forecast_predictors/NASA_EVI/US_buffered_EVI/"
eBird <- raster("/Volumes/forecast_predictors/ebird_raster/ebird_raster_template.tif")
dest.folder.mean <- "/Volumes/forecast_predictors/NASA_EVI/US_resampled/mean/"
dest.folder.sd <- "/Volumes/forecast_predictors/NASA_EVI/US_resampled/sd/"

year.folders <- list.files(EVI.main.dir)

for (year in 1:length(year.folders)){
  QA.year.path <- paste(sep = "", QA.main.dir, year.folders[year], "/")
  EVI.year.path <- paste(sep = "", EVI.main.dir, year.folders[year], "/")
  
  cat("QA folder: ", QA.year.path, '\n')
  cat("EVI folder: ", EVI.year.path, '\n')
  
  QA.tif.files <- list.files(QA.year.path, pattern = "\\.tif$")
  EVI.tif.files <- list.files(EVI.year.path, pattern = "\\.tif$")
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  start_time <- Sys.time()
  foreach (my_tif = 1:length(EVI.tif.files), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    QA.tif.path <- paste(sep = "", QA.year.path, QA.tif.files[my_tif])
    EVI.tif.path <- paste(sep = "", EVI.year.path, EVI.tif.files[my_tif])
    
    QA.raster <- raster(QA.tif.path)
    QA.raster[QA.raster==0] <- 1
    QA.raster[QA.raster==2] <- 1
    QA.raster[QA.raster==3] <- NA
    
    EVI.raster <- raster(EVI.tif.path)
    
    final.EVI <- EVI.raster*QA.raster
    
    agg.final.mean <- raster::aggregate(final.EVI, fact=c(6,6), fun = 'mean',
                                        na.rm = TRUE)
    agg.final.sd <- raster::aggregate(final.EVI, fact=c(6,6), fun = 'sd',
                                      na.rm = TRUE)
    
    proj.final.mean <- projectRaster(agg.final.mean, eBird, res = c(2962.807,2962.807),
                                     method = "bilinear")
    proj.final.sd <- projectRaster(agg.final.sd, eBird, res = c(2962.807,2962.807),
                                   method = "bilinear")
    dest.path.mean <- paste(sep = "", dest.folder.mean, year.folders[year], '/')
    ifelse(!dir.exists(file.path(dest.path.mean)), 
           dir.create(file.path(dest.path.mean)), FALSE)
    
    dest.path.sd <- paste(sep = "", dest.folder.sd, year.folders[year], '/')
    ifelse(!dir.exists(file.path(dest.path.sd)), 
           dir.create(file.path(dest.path.sd)), FALSE)
    
    filename.mean <- paste(sep = "", dest.path.mean, "mean_", EVI.tif.files[my_tif])
    filename.sd <- paste(sep = "", dest.path.sd, "sd_", EVI.tif.files[my_tif])
    
    resmpld.final.mean <- resample(proj.final.mean, eBird,
                                   method = "bilinear", filename = filename.mean,
                                   format = "GTiff", overwrite=TRUE)
    resmpld.final.sd <- resample(proj.final.sd, eBird,
                                 method = "bilinear", filename = filename.sd,
                                 format = "GTiff", overwrite=TRUE)
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
  end_time <- Sys.time()
  end_time - start_time
}
#########################################################################
#In this part, we changed all NA values to -50,000,000 in order to avoid
#adding NAs to our training dataset.
#########################################################################

library(raster)
library(foreach)
library(doParallel)

mean.dir <- "/Volumes/forecast_predictors/NASA_EVI/3_US_resampled/mean/"
sd.dir <- "/Volumes/forecast_predictors/NASA_EVI/3_US_resampled/sd/"
noNAs.mean.dir <- "/Volumes/forecast_predictors/NASA_EVI/4_noNAs_EVI/mean/"
noNAs.sd.dir <- "/Volumes/forecast_predictors/NASA_EVI/4_noNAs_EVI/sd/"

year.folders <- list.files(mean.dir)

for (year in 1:length(year.folders)) {
  mean.year.path <- paste(sep = "", mean.dir, year.folders[year], "/")
  
  mean.evi.files <- list.files(mean.year.path)
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  foreach (mean.evi.tif = 1:length(mean.evi.files), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    mean.evi.path <- paste(sep = "", mean.year.path, mean.evi.files[mean.evi.tif])
    mean.evi.raster <- raster::raster(mean.evi.path)
    
    mean.evi.raster[is.na(mean.evi.raster[])] <- -50000000
    dest.path.mean <- paste(sep = "", noNAs.mean.dir, year.folders[year], "/")
    
    ifelse(!dir.exists(file.path(dest.path.mean)), 
           dir.create(file.path(dest.path.mean), recursive = TRUE), FALSE)
    
    mean.filename <- paste(sep = "", dest.path.mean, mean.evi.files[mean.evi.tif])
    raster::writeRaster(mean.evi.raster, filename = mean.filename, format = 'GTiff',
                        overwrite=TRUE)
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
  
  gc()
  
  sd.year.path <- paste(sep = "", sd.dir, year.folders[year], "/")
  
  sd.evi.files <- list.files(sd.year.path)
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  foreach (sd.evi.tif = 1:length(sd.evi.files), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    sd.evi.path <- paste(sep = "", sd.year.path, sd.evi.files[sd.evi.tif])
    sd.evi.raster <- raster::raster(sd.evi.path)
    
    sd.evi.raster[is.na(sd.evi.raster[])] <- -50000000
    dest.path.sd <- paste(sep = "", noNAs.sd.dir, year.folders[year], "/")
    
    ifelse(!dir.exists(file.path(dest.path.sd)), 
           dir.create(file.path(dest.path.sd), recursive = TRUE), FALSE)
    
    sd.filename <- paste(sep = "", dest.path.sd, sd.evi.files[sd.evi.tif])
    raster::writeRaster(sd.evi.raster, filename = sd.filename, format = 'GTiff',
                        overwrite=TRUE)
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
  gc()
}






#########################################################################
#We now create sub-folders for each month in both "mean" and "sd" directories,
#and move EVI tif files to each month folder using Reg Expression
#########################################################################
library(tools)
library(filesstrings)
library(stringr)

evi.mean <- "/Volumes/forecast_predictors/NASA_EVI/4_noNAs_EVI/mean/"
evi.sd <- "/Volumes/forecast_predictors/NASA_EVI/4_noNAs_EVI/sd/"

years <- list.files(evi.sd)

for (year in 1:length(years)){
  print(years[year])
  year.dir <- paste(sep = "", evi.sd, years[year], '/')
  print(year.dir)
  
  evi.tifs <- list.files(year.dir)
  setwd(year.dir)
  for(tif in 1:length(evi.tifs)){
    evi.filename <- file_path_sans_ext(evi.tifs[tif])
    evi.digits <- str_extract_all(evi.filename, pattern ="\\d")
    evi.digits <- unlist(evi.digits)
    period <- paste(evi.digits, collapse = "")
    print(period)
    evi.month <- paste(evi.digits[5:6], collapse = "")
    evi.month <- as.numeric(evi.month)
    print(evi.month)
    
    month.dir <- paste(sep = "", year.dir, evi.month, '/')
    ifelse(!dir.exists(file.path(month.dir)), 
           dir.create(file.path(month.dir), recursive=T), FALSE)
    move_files(evi.tifs[tif], month.dir)
  }
}
