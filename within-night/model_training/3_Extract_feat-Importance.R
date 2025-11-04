library(lightgbm)
library(data.table)

##These paths need to be updated per time step
model.dir = '/Volumes/Mikko2/csu/phd/projects/forecast/Forecast_chapter/Data/05_savedModels/2-4/'
dest.dir = '/Volumes/Mikko2/csu/phd/projects/forecast/Forecast_chapter/Data/07_FeatureImportance/2-4/'

user.input = readline("Mikko, have you updated all the directory paths? (y/n) ")
if(user.input == 'y' || user.input == 'yes' || user.input == 'Yes'){
  fall.models.list <- list.files(model.dir, pattern = 'fall.txt', full.names = T)
  spring.models.list <- list.files(model.dir, pattern = 'spring.txt', full.names = T)
  
  fall.feat.results <- data.table()
  spring.feat.results <- data.table()
  
  start = Sys.time()
  for (turn in 1:length(fall.models.list)) {
    #Load the trained models for both Spring and Fall
    cat('*** Load the models for round', turn, '***\n')
    fall.model <- lgb.load(filename = fall.models.list[turn])
    spring.model <- lgb.load(filename = spring.models.list[turn])
    
    cat('Calculate feature importance\n')
    #Calculate feature importance for the models
    fall.feat.imp <- lgb.importance(fall.model, percentage = TRUE)
    #Keep the 'Gain' value only
    fall.feat.imp <- fall.feat.imp[,1:2]
    #Change the 'Gain' column name to 'Model_??.Gain'
    setnames(fall.feat.imp, 2, paste0("Model_",sprintf("%02d",turn),".Gain"))
    
    spring.feat.imp <- lgb.importance(spring.model, percentage = TRUE)
    spring.feat.imp <- spring.feat.imp[,1:2]
    setnames(spring.feat.imp, 2, paste0("Model_",sprintf("%02d",turn),".Gain"))
    gc()
    
    #Check to see if 'fall.feat.results' is empty
    if(nrow(fall.feat.results)==0){
      #If so, use cbind for the first round of merging
      fall.feat.results <- cbind(fall.feat.results, fall.feat.imp)
    }else{
      #If not, use the 'merge' function based on the 'Feature' column
      fall.feat.results <- merge.data.table(fall.feat.results, fall.feat.imp, by="Feature")
    }
    
    #Similar process for 'spring.feat.results'
    if(nrow(spring.feat.results)==0){
      #If so, use cbind for the first round of merging
      spring.feat.results <- cbind(spring.feat.results, spring.feat.imp)
    }else{
      #If not, use the 'merge' function based on the 'Feature' column
      spring.feat.results <- merge.data.table(spring.feat.results, spring.feat.imp, by="Feature")
    }
    cat('*** End of round', turn, '***\n')
  }
  #Calculate the mean for all 10 models' gain values
  fall.feat.results$Mean.Gain <- rowMeans(fall.feat.results[,2:ncol(fall.feat.results)])
  spring.feat.results$Mean.Gain <- rowMeans(spring.feat.results[,2:ncol(spring.feat.results)])
  
  #Sort the data table based on Mean Values
  fall.feat.results <- fall.feat.results[order(-Mean.Gain)]
  spring.feat.results <- spring.feat.results[order(-Mean.Gain)]
  
  #Write out the results as a 'csv'
  fwrite(fall.feat.results,
         paste0(dest.dir, 'fall.csv'),
         quote = F)
  fwrite(spring.feat.results,
         paste0(dest.dir, 'spring.csv'),
         quote = F)
  end = Sys.time()
  end-start #Time difference of 45.5424 mins
}else{
  print('The directory path has not been updated')
  stop('Please update ALL directory paths for the new hours range, Mikko!')
}
