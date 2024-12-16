library(data.table)
library(lightgbm)
library(weathermetrics)

model_dir <- "/path/to/savedModels/"
nam_dir <- '/path/to/Nam & Terrestrial data combined [NAM-Land_Combined]/'
raw_forecast_dir <- '/path/to/tabular forecast [NAM_nightly_RawForecast]/'

years <- as.integer(list.files(nam.dir))

# Define columns to be used in forecasting
forecasting_cols <- c("SurfaceHgt", "air.sfc", "pressure.sfc", "relative.humidity", 
                   "total.cloud.cover", "visibility", "msl.pressure", "uwnd.sfc", 
                   "vwnd.sfc", "uwind.900_hPa", "uwind.1000_hPa", "uwind.950_hPa", 
                   "uwind.850_hPa", "uwind.800_hPa", "vwind.900_hPa", 
                   "vwind.1000_hPa", "vwind.950_hPa", "vwind.850_hPa", 
                   "vwind.800_hPa", "air.900_hPa", "air.1000_hPa", "air.950_hPa", 
                   "air.850_hPa", "air.800_hPa", "SurfaceHgt_150N", "air.sfc_150N", 
                   "pressure.sfc_150N", "relative.humidity_150N", 
                   "total.cloud.cover_150N", "visibility_150N", 
                   "msl.pressure_150N", "uwnd.sfc_150N", "vwnd.sfc_150N", 
                   "uwind.900_hPa_150N", "uwind.950_hPa_150N", 
                   "uwind.1000_hPa_150N", "uwind.850_hPa_150N", 
                   "uwind.800_hPa_150N", "vwind.900_hPa_150N", 
                   "vwind.950_hPa_150N", "vwind.1000_hPa_150N", 
                   "vwind.850_hPa_150N", "vwind.800_hPa_150N", 
                   "air.900_hPa_150N", "air.950_hPa_150N", "air.1000_hPa_150N", 
                   "air.850_hPa_150N", "air.800_hPa_150N", "SurfaceHgt_150S", 
                   "air.sfc_150S", "pressure.sfc_150S", "relative.humidity_150S", 
                   "total.cloud.cover_150S", "visibility_150S", "msl.pressure_150S", 
                   "uwnd.sfc_150S", "vwnd.sfc_150S", "uwind.1000_hPa_150S", 
                   "uwind.800_hPa_150S", "uwind.850_hPa_150S", "uwind.900_hPa_150S", 
                   "uwind.950_hPa_150S", "vwind.1000_hPa_150S", 
                   "vwind.800_hPa_150S", "vwind.850_hPa_150S", 
                   "vwind.900_hPa_150S", "vwind.950_hPa_150S", 
                   "air.1000_hPa_150S", "air.800_hPa_150S", "air.850_hPa_150S", 
                   "air.900_hPa_150S", "air.950_hPa_150S", "SurfaceHgt_150E", 
                   "air.sfc_150E", "pressure.sfc_150E", "relative.humidity_150E", 
                   "total.cloud.cover_150E", "visibility_150E", "msl.pressure_150E", 
                   "uwnd.sfc_150E", "vwnd.sfc_150E", "uwind.1000_hPa_150E", 
                   "uwind.800_hPa_150E", "uwind.900_hPa_150E", "uwind.950_hPa_150E", 
                   "uwind.850_hPa_150E", "vwind.1000_hPa_150E", "vwind.800_hPa_150E", 
                   "vwind.900_hPa_150E", "vwind.950_hPa_150E", "vwind.850_hPa_150E", 
                   "air.1000_hPa_150E", "air.800_hPa_150E", "air.900_hPa_150E", 
                   "air.950_hPa_150E", "air.850_hPa_150E", "SurfaceHgt_150W", 
                   "air.sfc_150W", "pressure.sfc_150W", "relative.humidity_150W", 
                   "total.cloud.cover_150W", "visibility_150W", "msl.pressure_150W", 
                   "uwnd.sfc_150W", "vwnd.sfc_150W", "uwind.950_hPa_150W", 
                   "uwind.1000_hPa_150W", "uwind.850_hPa_150W", "uwind.900_hPa_150W", 
                   "uwind.800_hPa_150W", "vwind.950_hPa_150W", "vwind.1000_hPa_150W", 
                   "vwind.850_hPa_150W", "vwind.900_hPa_150W", "vwind.800_hPa_150W", 
                   "air.950_hPa_150W", "air.1000_hPa_150W", "air.850_hPa_150W", 
                   "air.900_hPa_150W", "air.800_hPa_150W", "Elevation",  
                   "mean.VIIRS", "sd.VIIRS",   
                   "LC.Type0",  "LC.Type10",  "LC.Type11",  "LC.Type13", 
                   "LC.Type15",  "Type.Forest", "Type.Shrubland", "Type.Savanna", 
                   "Type.Cropland", "TimeAfterSunset.Hour", "Ordinal.Date", 
                   "Distance.Radar.km")

# Helper functions
convert_air_temperature_to_kelvin <- function(data, air_columns) {
  for (column in air_columns) {
    data[[column]] <- celsius.to.kelvin(data[[column]], round = 1)
  }
  return(data)
}

process_land_cover <- function(data) {
  data[, Type.Forest := round(rowSums(.SD), 2), .SDcols = patterns("^LC.Type[1-5]")]
  data[, Type.Shrubland := round(rowSums(.SD), 2), .SDcols = patterns("^LC.Type[6-7]")]
  data[, Type.Savanna := round(rowSums(.SD), 2), .SDcols = patterns("^LC.Type[8-9]")]
  data[, Type.Cropland := round(rowSums(.SD), 2), .SDcols = patterns("^LC.Type(12|14)$")]
  data[, (grep("^LC.Type", names(data), value = TRUE)) := NULL]
  return(data)
}

# Main processing
years <- as.integer(list.files(nam_dir))

for (year in years) {
  year_path <- file.path(nam_dir, year)
  nights <- list.files(year_path)
  
  for (night in nights) {
    night_path <- file.path(year_path, night)
    nam_files <- list.files(night_path, pattern = "\\.rds$", full.names = TRUE)
    nam_data <- fread(nam_files)
    
    # Set unique fields
    nam_data[, `:=`(Distance.Radar.km = 35, Unique.ID = ID)]
    setnames(nam_data, "ID", "Unique.ID")
    
    # Process land cover
    nam_data <- process_land_cover(nam_data)
    
    # Set column order and filter
    setcolorder(nam_data, forecasting_cols)
    nam_data <- nam_data[, ..forecasting_cols]
    
    # Convert air temperatures to Kelvin
    air_columns <- grep("^air", names(nam_data), value = TRUE)
    nam_data <- convert_air_temperature_to_kelvin(nam_data, air_columns)
    
    # Load models and predict
    forecast_results <- list()
    model_files <- list.files(model_dir, full.names = TRUE)
    
    for (model_file in model_files) {
      model <- lgb.load(model_file)
      forecast <- predict(model, as.matrix(nam_data))
      forecast_results[[model_file]] <- forecast
    }
    
    # Combine forecasts
    forecast_dt <- as.data.table(forecast_results)
    forecast_dt[, Unique.ID := nam_data$Unique.ID]
    
    # Save results
    output_path <- file.path(raw_forecast_dir, year, night)
    dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
    saveRDS(forecast_dt, file.path(output_path, paste0(night, ".rds")))
  }
}
    

    


    

    