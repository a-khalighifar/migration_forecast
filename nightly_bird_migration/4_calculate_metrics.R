library(data.table)

# Function to calculate R-squared
calculate_r_squared <- function(actual, predicted) {
  cor(actual, predicted)^2
}

# Directory paths
training_dir <- '/path/to/Training data folder [trainingData]/'
forecast_dir <- '/path/to/tabular forecast [NAM_nightly_RawForecast]/'

# Get years available in the forecast directory
years <- list.files(forecast_dir)

# Initialize the results data frame
num_models <- 25
results_df <- data.frame(matrix(ncol = num_models + 1, nrow = 0))
colnames(results_df) <- c('Dates', paste0('Model_', sprintf("%02d", 1:num_models)))

# Loop through models
for (model_id in 1:num_models) {
  cat('Processing Model:', model_id, '\n')
  cell_no <- 1
  
  # Loop through years
  for (year in years) {
    cat('Processing Year:', year, '\n')
    year_path <- file.path(forecast_dir, year)
    dates_list <- list.files(year_path)
    
    # Loop through dates
    for (date_idx in seq_along(dates_list)) {
      date <- dates_list[date_idx]
      cat(cell_no, '- Processing Date:', date, '\n')
      
      # Read forecast data
      forecast_files <- list.files(file.path(year_path, date), pattern = '\\.rds$', full.names = TRUE)
      forecast_data <- readRDS(forecast_files)
      forecast_data[, c("X", "Y")] <- round(forecast_data[, c("X", "Y")], 1)
      forecast_data <- subset(forecast_data, select = c("X", "Y", paste0("Model_", sprintf("%02d", model_id))))
      
      # Read training data
      training_file <- list.files(training_dir, pattern = paste0(sprintf("%02d", model_id), '_allData'), full.names = TRUE)
      training_data <- readRDS(training_file)
      training_data <- training_data[training_data$Radar.value > 0]
      training_data$Date <- as.Date(training_data$Date, tz = 'UTC')
      training_data[, c("X", "Y")] <- round(training_data[, c("X", "Y")], 1)
      
      # Filter training data for the specific night and time
      night_values <- training_data[Date == date & TimeAfterSunset.Hour == 3]
      
      # Perform nearest match with forecast data
      matched_data <- forecast_data[night_values, on = c("X", "Y"), roll = "nearest", nomatch = 0]
      matched_data$Radar.value <- matched_data$Radar.value^(1/3)
      
      # Calculate R-squared
      r_squared <- calculate_r_squared(matched_data[, 6], matched_data[, 3])[1]
      cat('R2 =', r_squared, '\n')
      
      # Store results
      results_df[cell_no, model_id + 1] <- r_squared
      results_df[cell_no, 1] <- date
      cell_no <- cell_no + 1
    }
  }
}

# Write results to a CSV file
fwrite(results_df, '/path/to/R2_for_nights.csv', quote = FALSE)