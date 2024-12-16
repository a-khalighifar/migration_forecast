library(data.table)
library(terra)

# Define directories and template
raw_forecast_dir <- '/path/to/tabular forecast [NAM_nightly_RawForecast]/'
rast_forecast_dir <- '/path/to/rasterized forecast [Rasterized_forecast]/'
ebird <- rast('/path/to/ebird_raster_template.tif')
years <- list.files(raw_forecast_dir)

# Function to create directories if they do not exist
create_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
  }
}

# Process forecasts by year and night
for (year in years) {
  
  forecast_path <- file.path(raw_forecast_dir, year)
  nights_list <- list.files(forecast_path)
  
  for (night in nights_list) {
    
    night_path <- file.path(forecast_path, night)
    forecast_rds <- list.files(night_path, pattern = '\\.rds$', full.names = TRUE)
    forecast_dt <- readRDS(forecast_rds)
    
    # Calculate Mean and SD of the 25 model predictions
    forecast_dt[, Mean := rowMeans(.SD), .SDcols = 4:28]
    forecast_dt[, SD := apply(.SD, 1, sd), .SDcols = 4:28]
    
    cat(sprintf("Processing forecast data for the night of %s\n", night))
    
    # Generate Mean and SD shapefiles
    shp_mean <- vect(forecast_dt[, .(X, Y, Mean)],
                     geom = c('X', 'Y'),
                     crs = '+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs')
    
    shp_sd <- vect(forecast_dt[, .(X, Y, SD)],
                   geom = c('X', 'Y'),
                   crs = '+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs')
    
    # Define paths and filenames for rasters
    mean_path <- file.path(rast_forecast_dir, 'Mean', year, night)
    sd_path <- file.path(rast_forecast_dir, 'Sd', year, night)
    create_dir(mean_path)
    create_dir(sd_path)
    
    mean_filename <- file.path(mean_path, paste0(night, '_mean.tif'))
    sd_filename <- file.path(sd_path, paste0(night, '_sd.tif'))
    
    # Rasterize Mean and SD shapefiles
    cat(sprintf("Creating mean raster for %s\n", night))
    rasterize(shp_mean, ebird, field = 'Mean', filename = mean_filename, overwrite = TRUE)
    
    cat(sprintf("Creating sd raster for %s\n", night))
    rasterize(shp_sd, ebird, field = 'SD', filename = sd_filename, overwrite = TRUE)
  }
}