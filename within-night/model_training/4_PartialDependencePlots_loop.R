library(data.table)
library(lightgbm)

# write a function for computing pdp data
compute_all_pdp <- function(train_dt, season_filter, model_path, max_rows = 1000) {
  
  # subset by season
  train_season <- train_dt[eval(parse(text = season_filter))]
  
  # drop columns we don't need
  cols.to.remove <- c("Radar.Stations", "X.Lon", "Y.Lat", "Date", "Radar.Time",
                      "UTC_interval", "Radar.Year", "Radar.Month", "Radar.Day",
                      "Radar.Hour", "Radar.Minute", "Radar.Second", "Sunset",
                      "Radar.X", "Radar.Y")
  train_season[, (cols.to.remove) := NULL]
  
  # pick training columns
  training.cols <- colnames(train_season)[-c(1:3, 125, 127, 134:140, 143, 145, 156)]
  train_used <- train_season[, ..training.cols]
  
  # subsample if too big
  set.seed(123)
  if (nrow(train_used) > max_rows) train_used <- train_used[sample(.N, max_rows)]
  
  # load model
  model <- lgb.load(model_path)
  
  # compute pdp summary for one variable
  compute_pdp_summary <- function(var) {
    grid_vals <- quantile(train_used[[var]], probs = seq(0, 1, length.out = 20), na.rm = TRUE)
    pdp_results <- lapply(grid_vals, function(g) {
      newdata <- copy(train_used)
      newdata[[var]] <- g
      preds <- predict(model, as.matrix(newdata))
      data.table(xval = g, yhat = preds)
    })
    pdp_dt <- rbindlist(pdp_results)
    pdp_summary <- pdp_dt[, .(
      yhat_mean = mean(yhat),
      yhat_sd   = sd(yhat),
      yhat_lo   = mean(yhat) - sd(yhat),
      yhat_hi   = mean(yhat) + sd(yhat)
    ), by = xval]
    pdp_summary[, variable := var]
    return(pdp_summary)
  }
  
  # run for all predictors
  all_pdp_summary <- lapply(training.cols, compute_pdp_summary)
  all_pdp_dt <- rbindlist(all_pdp_summary)
  
  return(all_pdp_dt)
}

# season filters
spring_filter <- "Radar.Month >= 3 & Radar.Month <= 6 & ifelse(Radar.Month == 6, Radar.Day <= 15, TRUE)"
fall_filter   <- "Radar.Month >= 8 & ifelse(Radar.Month == 11, Radar.Day <= 15, TRUE)"

# loop through 10 models
for (i in 1:10) {
  
  # paths - CHANGE THESE LINES FOR EACH TIMESTEP MIKKO
  train_path  <- sprintf("/Users/aeroecolab/Downloads/forecast_models/data/04_trainingData/0-2/%d_allData.rds", i)
  spring_model_path <- sprintf("/Users/aeroecolab/Downloads/forecast_models/data/05_savedModels/0-2/%02d_model-spring.txt", i)
  fall_model_path   <- sprintf("/Users/aeroecolab/Downloads/forecast_models/data/05_savedModels/0-2/%02d_model-fall.txt", i)
  
  spring_save <- sprintf("/Users/aeroecolab/Downloads/forecast_models/data/08_pdp/0-2/spring_model%d_pdp_summary.rds", i)
  fall_save   <- sprintf("/Users/aeroecolab/Downloads/forecast_models/data/08_pdp/0-2/fall_model%d_pdp_summary.rds", i)
  
  # load training data
  train_dt <- readRDS(train_path)
  
  # spring
  message(sprintf("Processing SPRING model %d ...", i))
  spring_pdp <- compute_all_pdp(train_dt, spring_filter, spring_model_path)
  saveRDS(spring_pdp, spring_save)
  
  # fall
  message(sprintf("Processing FALL model %d ...", i))
  fall_pdp <- compute_all_pdp(train_dt, fall_filter, fall_model_path)
  saveRDS(fall_pdp, fall_save)
}
