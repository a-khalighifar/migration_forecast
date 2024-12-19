library(data.table)
library(lightgbm)
library(caTools)
library(caret)

# Function to calculate R-squared
r.square <- function(y_actual, y_predict) {
  cor(y_actual, y_predict)^2
}

# Directories for loading datasets and saving models
train_dir <- '/path/to/Training data folder [trainingData]/'
model_dir <- '/path/to/savedModels/' # Make sure this directory exists. You need to create it if it does not exist.

# List all training dataset files
training_files <- list.files(train_dir, pattern = '.rds', full.names = TRUE)

# Initialize results DataFrame
results <- data.frame()

# Column names to exclude
cols_to_remove <- c("Radar.Stations", "X.Lon", "Y.Lat", "Date", "Radar.Time",
                    "UTC_interval", "Radar.Year", "Radar.Month", "Radar.Day",
                    "Radar.Hour", "Radar.Minute", "Radar.Second", "Sunset",
                    "Radar.X", "Radar.Y")

# LightGBM parameters
parameters <- list(
  objective = "regression",
  metric = "rmse",
  learning_rate = 0.1,
  max_depth = 30,
  num_leaves = 500,
  min_data_in_leaf = 3000,
  min_gain_to_split = 3,
  min_sum_hessian_in_leaf = 2,
  tree_learner = "serial",
  num_threads = 10,
  seed = 123,
  bagging_fraction = 0.8,
  bagging_freq = 5,
  feature_fraction = 0.95,
  early_stopping_round = 7,
  saved_feature_importance_type = 1,
  force_col_wise = TRUE
)

# Loop through each training file
for (turn in seq_along(training_files)) {
  cat(sprintf('========= Started training model %d =========\n', turn))
  
  # Load data
  all_data <- readRDS(training_files[turn])
  setkey(all_data, Unique.ID)
  
  # Split into train (70%) and validation/test (30%)
  split <- createDataPartition(all_data$Radar.value, p = 0.7, list = FALSE)
  trainset <- all_data[split]
  noTrain <- all_data[-split]
  setkey(trainset, Unique.ID)
  setkey(noTrain, Unique.ID)
  
  # Further split validation/test into 15% each
  split_test <- createDataPartition(noTrain$Radar.value, p = 0.5, list = FALSE)
  validset <- noTrain[split_test]
  testset <- noTrain[-split_test]
  
  # Cleanup to free memory
  remove(noTrain, all_data, split, split_test)
  gc()
  cat('***Finished splitting data into train, validation, and test sets***\n')
  
  # Remove unnecessary columns
  trainset <- as.data.table(trainset[, (cols_to_remove) := NULL])
  validset <- as.data.table(validset[, (cols_to_remove) := NULL])
  testset <- as.data.table(testset[, (cols_to_remove) := NULL])
  gc()
  
  # Set column order for consistency
  training_cols <- colnames(trainset)[-c(1:3, 125, 127, 134:156, 161:168)]
  setcolorder(trainset, training_cols)
  setcolorder(validset, training_cols)
  setcolorder(testset, training_cols)
  
  # Prepare LightGBM datasets
  dtrain <- lgb.Dataset(as.matrix(trainset[, ..training_cols]), 
                        label = trainset$Radar.value^(1/3))
  dvalid <- lgb.Dataset(as.matrix(validset[, ..training_cols]), 
                        label = validset$Radar.value^(1/3))
  valids <- list(test = dvalid)
  
  cat('***Finished preparing the dataset and parameters for training***\n')
  
  # Train the model
  model <- lgb.train(params = parameters,
                     data = dtrain,
                     nrounds = 1000,
                     valids = valids)
  
  # Save the model
  model_path <- file.path(model_dir, sprintf("%02d_model-reg.txt", turn))
  lgb.save(model, filename = model_path)
  cat('***Model training is complete and saved***\n', model_path, '\n')
  
  # Make predictions and calculate R-squared
  preds <- predict(model, as.matrix(testset[, ..training_cols]))
  response <- testset$Radar.value^(1/3)
  r2_value <- r.square(response, preds)
  
  # Store results
  results <- rbind(results, data.frame(Model_name = sprintf("model_%02d", turn), 
                                       R2_rate = r2_value))
  
  cat('***Prediction is complete and R2 is stored***\n', 'R2 =', r2_value, '\n')
}

# Save results to file
fwrite(results, '/path/to/results/model_training_results.csv', quote = FALSE)