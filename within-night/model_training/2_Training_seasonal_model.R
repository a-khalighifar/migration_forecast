library(data.table)
library(lightgbm)
library(caTools)
library(caret)

#Define the r.square function to calculate R2
r.square = function(y_actual,y_predict){
  cor(y_actual,y_predict)^2
}

#===============================================================================
#Define directories for loading datasets (train.dir) and saving
#models (model.dir)
#===============================================================================
# Need to change for each time step
train.dir <- '/Volumes/Mikko2/withinnight_test/data/04_trainingData/test/'
model.dir <- '/Volumes/Mikko2/withinnight_test/data/05_savedModels/test/'
results.dir <- '/Volumes/Mikko2/withinnight_test/data/06_Model_performance/test/'

#Number of rounds of trainings = total number of datasets in train.dir
num.trainings <- list.files(train.dir, pattern = '.rds', full.names = T)
#Create an empty df to save R2 from each model on test set
results.spring <- data.frame()
results.fall <- data.frame()
#===============================================================================
#Each round of training takes ~45 minutes
#===============================================================================
start = Sys.time()
for (turn in 1:length(num.trainings)) {
  
  cat('========= Started training model', turn, '=========\n')
  all.data <- readRDS(num.trainings[turn])
  setkey(all.data, Unique.ID)
  
  #Create two seasonal datasets for spring and fall
  spring.season <- all.data[Radar.Month>=3 & Radar.Month <= 6 & 
                              ifelse(Radar.Month==6, Radar.Day<=15, Radar.Day>=1), ]
  fall.season <- all.data[Radar.Month>=8 & 
                            ifelse(Radar.Month==11, Radar.Day<=15, Radar.Day>=1), ]
  
  # create train/validation split (70%/30%)
  split = createDataPartition(spring.season$Radar.value, p = 0.7, list = FALSE)
  
  #Create a train set with 70% of data
  trainset.spring = spring.season[split, ]
  setkey(trainset.spring, Unique.ID)
  
  #Create another set for test/validation with 30%
  noTrain = spring.season[-split, ]
  setkey(noTrain, Unique.ID)
  
  #Split the noTrain data to test and validation sets (15% each)
  split.test = createDataPartition(noTrain$Radar.value, p = 0.5, list = FALSE)
  validset.spring <- noTrain[split.test, ]
  testset.spring <- noTrain[-split.test, ]
  
  #Clean the extra items from the environment to avoid crashing the memory
  remove(noTrain, all.data, split, split.test)
  gc()
  
  #Do the same process for fall season
  split = createDataPartition(fall.season$Radar.value, p = 0.7, list = FALSE)
  trainset.fall = fall.season[split, ]
  setkey(trainset.fall, Unique.ID)
  noTrain = fall.season[-split, ]
  setkey(noTrain, Unique.ID)
  split.test = createDataPartition(noTrain$Radar.value, p = 0.5, list = FALSE)
  validset.fall <- noTrain[split.test, ]
  testset.fall <- noTrain[-split.test, ]
  remove(noTrain, split, split.test, spring.season, fall.season)
  gc()
  
  cat('***Finished splitting data into train, validation, and test sets***\n')
  
  cols.to.remove <- c("Radar.Stations", "X.Lon", "Y.Lat", "Date", "Radar.Time",
                      "UTC_interval", "Radar.Year", "Radar.Month", "Radar.Day",
                      "Radar.Hour", "Radar.Minute", "Radar.Second", "Sunset",
                      "Radar.X", "Radar.Y")
  
  trainset.spring <- as.data.table(trainset.spring[, (cols.to.remove) := NULL])
  trainset.fall <- as.data.table(trainset.fall[, (cols.to.remove) := NULL])
  validset.spring <- as.data.table(validset.spring[, (cols.to.remove) := NULL])
  validset.fall <- as.data.table(validset.fall[, (cols.to.remove) := NULL])
  testset.spring <- as.data.table(testset.spring[, (cols.to.remove) := NULL])
  testset.fall <- as.data.table(testset.fall[, (cols.to.remove) := NULL])
  gc()
  
  setkey(trainset.spring, Ordinal.Date)
  setkey(trainset.fall, Ordinal.Date)
  setkey(validset.spring, Ordinal.Date)
  setkey(validset.fall, Ordinal.Date)
  setkey(testset.spring, Ordinal.Date)
  setkey(testset.fall, Ordinal.Date)
  
  #For atmospheric + spatial atmospheric + terrestrial variables (excluding EVIs)
  training.cols <- colnames(trainset.spring)[-c(1:3, 125, 127, 134:156, 161:168)]
  #It's a overkill, but wanted to make sure to have important columns first
  setcolorder(trainset.spring, training.cols)
  setcolorder(trainset.fall, training.cols)
  setcolorder(validset.spring, training.cols)
  setcolorder(validset.fall, training.cols)
  setcolorder(testset.spring, training.cols)
  setcolorder(testset.fall, training.cols)
  
  #Generate lgb compatible train and validation sets
  dtrain <- lgb.Dataset(as.matrix(subset(trainset.spring, select = training.cols)), 
                        label = trainset.spring$Radar.value^(1/3))
  dvalid <- lgb.Dataset(as.matrix(subset(validset.spring, select = training.cols)), 
                        label = validset.spring$Radar.value^(1/3))
  
  parameters <- list(objective = "regression", #Replaced 'tweedie' with 'regression' for half of models
                     metric = "rmse",
                     learning_rate = 0.1, #Initially 0.1
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
                     force_col_wise=TRUE)
  
  valids <- list(test = dvalid)
  cat('***Finished preparing the dataset and parameters for training***\n')
  
  model <- lgb.train(params = parameters,
                     data = dtrain,
                     nrounds = 1000,
                     valids = valids)
  
  lgb.save(model, filename = paste0(model.dir, sprintf("%02d",turn), '_model-spring.txt'))
  cat('***Model training is complete and saved***\n',
      paste0(model.dir, sprintf("%02d",turn), '_model-spring.txt'), '\n')
  
  preds <- predict(model, as.matrix(subset(testset.spring, select = training.cols))) #0.6661169
  response <- testset.spring$Radar.value^(1/3)
  
  results.spring[turn,1:2] <- c(paste0('model_', sprintf("%02d",turn)), r.square(response, preds))
  names(results.spring)[1:2] <- c('Model_name', 'R2_rate')
  cat('***Prediction is complete and R2 is stored***\n',
      'R2 =', r.square(response, preds), '\n')
  
  #FOR FALL
  #Generate lgb compatible train and validation sets
  dtrain <- lgb.Dataset(as.matrix(subset(trainset.fall, select = training.cols)), 
                        label = trainset.fall$Radar.value^(1/3))
  dvalid <- lgb.Dataset(as.matrix(subset(validset.fall, select = training.cols)), 
                        label = validset.fall$Radar.value^(1/3))
  
  parameters <- list(objective = "regression", #Replaced 'tweedie' with 'regression' for half of models
                     metric = "rmse",
                     learning_rate = 0.1, #Initially 0.1
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
                     force_col_wise=TRUE)
  
  valids <- list(test = dvalid)
  cat('***Finished preparing the dataset and parameters for training***\n')
  
  model <- lgb.train(params = parameters,
                     data = dtrain,
                     nrounds = 1000,
                     valids = valids)
  
  lgb.save(model, filename = paste0(model.dir, sprintf("%02d",turn), '_model-fall.txt'))
  cat('***Model training is complete and saved***\n',
      paste0(model.dir, sprintf("%02d",turn), '_model-fall.txt'), '\n')
  
  preds <- predict(model, as.matrix(subset(testset.fall, select = training.cols))) #0.6661169
  response <- testset.fall$Radar.value^(1/3)
  
  results.fall[turn,1:2] <- c(paste0('model_', sprintf("%02d",turn)), r.square(response, preds))
  names(results.fall)[1:2] <- c('Model_name', 'R2_rate')
  cat('***Prediction is complete and R2 is stored***\n',
      'R2 =', r.square(response, preds), '\n')
  
  
}
fwrite(results.spring, paste0(results.dir,'Spring_model_training_results.csv'),
       quote = F)
fwrite(results.fall, paste0(results.dir,'Fall_model_training_results.csv'),
       quote = F)
end = Sys.time()
end-start #Time difference of 2.339715 days

#Seasonal model: Time difference of 22.82385 hours




