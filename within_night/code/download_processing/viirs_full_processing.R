# This section will use parallel processing to unzip each tgz file from the
#light pollution folder (VIIRS), and only extract the tif file that has the
#actual light pollution data -- *rade9h.tif
###########################################################################
library(raster)
library(foreach)
library(doParallel)

main.dir <- "/Volumes/forecast_predictors/VIIRS/"
setwd(main.dir)

year.folders <- list.files(main.dir)

start.time <- Sys.time()
for (year in 1:length(year.folders)) {
  year.path <- paste(sep = "", main.dir, year.folders[year], '/')
  setwd(year.path)
  print(year.path)
  month.folders <- list.files(year.path)
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  foreach (month = 1:length(month.folders), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    month.path <- paste(sep = "", year.path, month.folders[month], '/')
    setwd(month.path)
    
    tgz.file <- list.files(month.path)
    tgz.path <- paste(sep = "", month.path, tgz.file)
    
    untar(tgz.path, files = "*rade9h.tif")
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
}

end.time <- Sys.time()
end.time - start.time
###########################################################################
#This set of codes reads each light pollution tif files, aggregte using both 
#sd and mean functions to have the same resolution as other data, and lastely, 
#reproject and resample the tif files using the eBird map.
###########################################################################
library(raster)
library(foreach)
library(doParallel)

main.dir <- "/Volumes/forecast_predictors/VIIRS/Raw_data/"
setwd(main.dir)
dest.folder.mean <- "/Volumes/forecast_predictors/VIIRS/Resampled/mean/"
dest.folder.sd <- "/Volumes/forecast_predictors/VIIRS/Resampled/sd/"
eBird <- raster("/Volumes/forecast_predictors/ebird_raster/ebird_raster_template.tif")

year.folders <- list.files(main.dir)

start.time <- Sys.time()

for (year in 1:length(year.folders)) {
  year.path <- paste(sep = "", main.dir, year.folders[year], '/')
  setwd(year.path)
  print(year.path)
  month.folders <- list.files(year.path)
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  foreach (month = 1:length(month.folders), .errorhandling = c("pass"), .packages=c("raster")) %dopar% {
    month.path <- paste(sep = "", year.path, month.folders[month], '/')
    setwd(month.path)
    
    tif.file <- list.files(month.path, pattern = "\\.tif$")
    tif.path <- paste(sep = "", month.path, tif.file)
    
    viir.raster <- raster(tif.path)
    
    agg.viir.mean <- raster::aggregate(viir.raster, fact=c(6,6), fun = 'mean',
                                       na.rm = TRUE)
    agg.viir.sd <- raster::aggregate(viir.raster, fact=c(6,6), fun = 'sd',
                                     na.rm = TRUE)
    
    proj.viir.mean <- projectRaster(agg.viir.mean, eBird, res = c(2962.807,2962.807),
                                    method = "bilinear")
    proj.viir.sd <- projectRaster(agg.viir.sd, eBird, res = c(2962.807,2962.807),
                                  method = "bilinear")
    
    dest.path.mean <- paste(sep = "", dest.folder.mean, year.folders[year], '/',
                            month.folders[month], '/')
    ifelse(!dir.exists(file.path(dest.path.mean)), 
           dir.create(file.path(dest.path.mean), recursive=T), FALSE)
    dest.path.sd <- paste(sep = "", dest.folder.sd, year.folders[year], '/',
                          month.folders[month], '/')
    ifelse(!dir.exists(file.path(dest.path.sd)), 
           dir.create(file.path(dest.path.sd), recursive=T), FALSE)
    
    filename.mean <- paste(sep = "", dest.path.mean, "mean_", tif.file)
    filename.sd <- paste(sep = "", dest.path.sd, "sd_", tif.file)
    
    resmpld.viir.mean <- resample(proj.viir.mean, eBird,
                                  method = "bilinear", filename = filename.mean,
                                  format = "GTiff", overwrite=TRUE)
    resmpld.viir.sd <- resample(proj.viir.sd, eBird,
                                method = "bilinear", filename = filename.sd,
                                format = "GTiff", overwrite=TRUE)
  }
  cat("Stop parallel process!\n")
  parallel::stopCluster(cl = my_cluster)
}
end.time <- Sys.time()
end.time - start.time
cat("Light Pollution data is ready!")


###########################################################################
#We now create sub-folders for each month in both "mean" and "sd" directories,
#and move VIIRS tif files to each month folder using Reg Expression
#########################################################################
library(tools)
library(filesstrings)
library(stringr)

viir.mean <- "/Volumes/forecast_predictors/VIIRS/2_Resampled/mean/"
viir.sd <- "/Volumes/forecast_predictors/VIIRS/2_Resampled/sd/"

years <- list.files(viir.sd)

for (year in 1:length(years)){
  print(years[year])
  year.dir <- paste(sep = "", viir.sd, years[year], '/')
  print(year.dir)
  
  viir.tifs <- list.files(year.dir)
  setwd(year.dir)
  for(tif in 1:length(viir.tifs)){
    #Extract the filename without extension
    viir.filename <- file_path_sans_ext(viir.tifs[tif])
    #Extract all digits within the filename
    viir.digits <- str_extract_all(viir.filename, pattern ="\\d")
    viir.digits <- unlist(viir.digits) #Unlist to be able to index or extract
    period <- paste(viir.digits, collapse = "")
    print(period)
    #Extract the month value and compress it together
    viir.month <- paste(viir.digits[5:length(viir.digits)], collapse = "")
    viir.month <- as.numeric(viir.month)
    print(viir.month)
    
    month.dir <- paste(sep = "", year.dir, viir.month, '/')
    ifelse(!dir.exists(file.path(month.dir)), 
           dir.create(file.path(month.dir), recursive=T), FALSE)
    move_files(viir.tifs[tif], month.dir)
  }
}

