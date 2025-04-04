#The following section extracts 10,000 focal points, as well as their associated
#North, South, East, and West points, across 143 stations from all terrestrial 
#variables, and sorts them based on EVI periods
#############################################################################
library(foreach)
library(doParallel)
library(raster)
library(stringr)
library(gtools)
library(tools)
library(data.table)

years <- c(2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021)
focal.months <- c(3,4,5,6,7,8,9,10,11)
csv <- read.csv("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/5_Stations_rand_points_75.csv")
required.cols <- csv[c("Radar.Stations", "X", "Y")]

copy_file <- function(mylist, to.dir){
  no.files <- length(mylist)
  for (i in 1:no.files) {
    file.copy(mylist[i], to.dir)
  }
}

extract_date <- function(myfile){
  filename <- basename(myfile)
  filename <- file_path_sans_ext(filename)
  file.digits <- str_extract_all(filename, pattern ="\\d")
  file.digits <- unlist(file.digits)
  file.year <- paste(file.digits[1:4], collapse = "")
  file.year <- as.numeric(file.year)
  file.month <- paste(file.digits[5:6], collapse = "")
  file.month <- as.numeric(file.month)
  file.day <- paste(file.digits[7:length(file.digits)], collapse = "")
  file.day <- as.numeric(file.day)
  if(file.day <= 15){
    file.period <- "First"
  } else {
    file.period <- "Second"
  }
  output <- c(file.year, file.month, file.day, file.period)
  return(output)
}

evi.dir <- "/Volumes/forecast_predictors/NASA_EVI/4_noNAs_EVI/"
lc.dir <- "/Volumes/forecast_predictors/NASA_Land_Cover/4_US_LC_noNA_classified/"
viir.dir <- "/Volumes/forecast_predictors/VIIRS/2_Resampled/"
main.tmp <- "/Volumes/forecast_predictors/tmp_dir/"
csv.dir <- "/Volumes/forecast_predictors/extracted_points/"

for (year in years) {
  tmp.year <- paste(sep = "", main.tmp, year, '/')
  ifelse(!dir.exists(file.path(tmp.year)), 
         dir.create(file.path(tmp.year), recursive=T), FALSE)
  print(tmp.year)
  
  cat("Start parallel process!\n")
  n.cores <- parallel::detectCores() - 2
  my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
  print(my_cluster)
  doParallel::registerDoParallel(cl = my_cluster)
  
  foreach (month = focal.months, .errorhandling = c("pass"), .packages=c("data.table","raster","stringr","gtools","tools")) %dopar% {
    
    tmp.month.dir <- paste(sep = "", tmp.year, month, '/')

    mean.evi.dir <- paste(sep = "", evi.dir, "mean/", year, '/', month, '/')
    mean.evi.list <- list.files(mean.evi.dir, full.names = TRUE)
    
    if (length(mean.evi.list) > 1){
      #Create a dataframe for the first period
      df1 <- data.frame()
      tmp.period.dir <- paste(sep = "", tmp.month.dir, "first/")
      ifelse(!dir.exists(file.path(tmp.period.dir)), 
             dir.create(file.path(tmp.period.dir), recursive=T), FALSE)
      
      copy_file(mean.evi.list[1], tmp.period.dir)
      
      dates <- extract_date(mean.evi.list[1])
      evi.year <- as.numeric(dates[1])
      evi.month <- as.numeric(dates[2])
      evi.day <- as.numeric(dates[3])
      evi.period <- dates[4]
      
      if (year != evi.year || month != evi.month){
        unmatch = "Unmatch"
      } else {
        unmatch = ""
      }
      
      df1 <- cbind(required.cols, evi.year, evi.month, evi.day, evi.period)
      colnames(df1)[4:7] <- c("Year", "Month", "Day", "Period")

      sd.evi.dir <- paste(sep = "", evi.dir, "sd/", year, '/', month, '/')
      sd.evi.list <- list.files(sd.evi.dir, full.names = TRUE)
      copy_file(sd.evi.list[1], tmp.period.dir)
    
      lc.path <- paste(sep = "", lc.dir, year, '/')
      lc.list <- list.files(lc.path, full.names = TRUE)
      copy_file(lc.list, tmp.period.dir)
    
      mean.viir.path <- paste(sep = "", viir.dir, "mean/", year, '/', month, '/')
      mean.viir.list <- list.files(mean.viir.path, full.names = TRUE)
      copy_file(mean.viir.list, tmp.period.dir)
    
      sd.viir.path <- paste(sep = "", viir.dir, "sd/", year, '/', month, '/')
      sd.viir.list <- list.files(sd.viir.path, full.names = TRUE)
      copy_file(sd.viir.list, tmp.period.dir)
      
      tmp.folder.list <- list.files(tmp.period.dir, full.names = TRUE)
      rasterStack <- lapply(tmp.folder.list, stack)
      rasterStack <- stack(rasterStack)
      
      #Extract points from focal coordinates
      csv.focal <- csv
      coordinates(csv.focal) <- ~ X + Y
      rasterValue <- extract(rasterStack, csv.focal, method = "simple")
      rasterValue <- as.data.frame(rasterValue)
      columns <- colnames(rasterValue)
      columns <- mixedsort(columns)
      setcolorder(rasterValue, columns)
      colnames(rasterValue) <- c("mean.EVI", "mean.VIIRS", "sd.EVI","sd.VIIRS", 
                                 "LC.Type0", "LC.Type1", "LC.Type2",
                                 "LC.Type3", "LC.Type4", "LC.Type5",
                                 "LC.Type6", "LC.Type7", "LC.Type8",
                                 "LC.Type9", "LC.Type10", "LC.Type11",
                                 "LC.Type12", "LC.Type13", "LC.Type14",
                                 "LC.Type15")
      df1 <- cbind(df1, rasterValue)
      
      #Extract points from 75 km North
      csv.75.N <- csv
      coordinates(csv.75.N) <- ~ X.75.N + Y.75.N
      rasterValue.75.N <- extract(rasterStack, csv.75.N, method = "simple")
      rasterValue.75.N <- as.data.frame(rasterValue.75.N)
      columns <- colnames(rasterValue.75.N)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.N, columns)
      colnames(rasterValue.75.N) <- c("mean.EVI_75N", "mean.VIIRS_75N", "sd.EVI_75N",
                                      "sd.VIIRS_75N", "LC.Type0_75N", "LC.Type1_75N", "LC.Type2_75N",
                                      "LC.Type3_75N", "LC.Type4_75N", "LC.Type5_75N",
                                      "LC.Type6_75N", "LC.Type7_75N", "LC.Type8_75N",
                                      "LC.Type9_75N", "LC.Type10_75N", "LC.Type11_75N",
                                      "LC.Type12_75N", "LC.Type13_75N", "LC.Type14_75N",
                                      "LC.Type15_75N")
      df1 <- cbind(df1, rasterValue.75.N)
      
      #Extract points from 75 km South
      csv.75.S <- csv
      coordinates(csv.75.S) <- ~ X.75.S + Y.75.S
      rasterValue.75.S <- extract(rasterStack, csv.75.S, method = "simple")
      rasterValue.75.S <- as.data.frame(rasterValue.75.S)
      columns <- colnames(rasterValue.75.S)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.S, columns)
      colnames(rasterValue.75.S) <- c("mean.EVI_75S", "mean.VIIRS_75S", "sd.EVI_75S",
                                      "sd.VIIRS_75S", "LC.Type0_75S", "LC.Type1_75S", "LC.Type2_75S",
                                      "LC.Type3_75S", "LC.Type4_75S", "LC.Type5_75S",
                                      "LC.Type6_75S", "LC.Type7_75S", "LC.Type8_75S",
                                      "LC.Type9_75S", "LC.Type10_75S", "LC.Type11_75S",
                                      "LC.Type12_75S", "LC.Type13_75S", "LC.Type14_75S",
                                      "LC.Type15_75S")

      df1 <- cbind(df1, rasterValue.75.S)
      
      #Extract points from 75 km East
      csv.75.E <- csv
      coordinates(csv.75.E) <- ~ X.75.E + Y.75.E
      rasterValue.75.E <- extract(rasterStack, csv.75.E, method = "simple")
      rasterValue.75.E <- as.data.frame(rasterValue.75.E)
      columns <- colnames(rasterValue.75.E)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.E, columns)
      colnames(rasterValue.75.E) <- c("mean.EVI_75E", "mean.VIIRS_75E", "sd.EVI_75E",
                                      "sd.VIIRS_75E", "LC.Type0_75E", "LC.Type1_75E", "LC.Type2_75E",
                                      "LC.Type3_75E", "LC.Type4_75E", "LC.Type5_75E",
                                      "LC.Type6_75E", "LC.Type7_75E", "LC.Type8_75E",
                                      "LC.Type9_75E", "LC.Type10_75E", "LC.Type11_75E",
                                      "LC.Type12_75E", "LC.Type13_75E", "LC.Type14_75E",
                                      "LC.Type15_75E")

      df1 <- cbind(df1, rasterValue.75.E)
      
      #Extract points from 75 km West
      csv.75.W <- csv
      coordinates(csv.75.W) <- ~ X.75.W + Y.75.W
      rasterValue.75.W <- extract(rasterStack, csv.75.W, method = "simple")
      rasterValue.75.W <- as.data.frame(rasterValue.75.W)
      columns <- colnames(rasterValue.75.W)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.W, columns)
      colnames(rasterValue.75.W) <- c("mean.EVI_75W", "mean.VIIRS_75W", "sd.EVI_75W",
                                      "sd.VIIRS_75W", "LC.Type0_75W", "LC.Type1_75W", "LC.Type2_75W",
                                      "LC.Type3_75W", "LC.Type4_75W", "LC.Type5_75W",
                                      "LC.Type6_75W", "LC.Type7_75W", "LC.Type8_75W",
                                      "LC.Type9_75W", "LC.Type10_75W", "LC.Type11_75W",
                                      "LC.Type12_75W", "LC.Type13_75W", "LC.Type14_75W",
                                      "LC.Type15_75W")

      df1 <- cbind(df1, rasterValue.75.W)
      
      #Extract points from 150 km North
      csv.150.N <- csv
      coordinates(csv.150.N) <- ~ X.150.N + Y.150.N
      rasterValue.150.N <- extract(rasterStack, csv.150.N, method = "simple")
      rasterValue.150.N <- as.data.frame(rasterValue.150.N)
      columns <- colnames(rasterValue.150.N)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.N, columns)
      colnames(rasterValue.150.N) <- c("mean.EVI_150N", "mean.VIIRS_150N", "sd.EVI_150N",
                                      "sd.VIIRS_150N", "LC.Type0_150N", "LC.Type1_150N", "LC.Type2_150N",
                                      "LC.Type3_150N", "LC.Type4_150N", "LC.Type5_150N",
                                      "LC.Type6_150N", "LC.Type7_150N", "LC.Type8_150N",
                                      "LC.Type9_150N", "LC.Type10_150N", "LC.Type11_150N",
                                      "LC.Type12_150N", "LC.Type13_150N", "LC.Type14_150N",
                                      "LC.Type15_150N")

      df1 <- cbind(df1, rasterValue.150.N)
      
      #Extract points from 150 km South
      csv.150.S <- csv
      coordinates(csv.150.S) <- ~ X.150.S + Y.150.S
      rasterValue.150.S <- extract(rasterStack, csv.150.S, method = "simple")
      rasterValue.150.S <- as.data.frame(rasterValue.150.S)
      columns <- colnames(rasterValue.150.S)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.S, columns)
      colnames(rasterValue.150.S) <- c("mean.EVI_150S", "mean.VIIRS_150S", "sd.EVI_150S",
                                       "sd.VIIRS_150S", "LC.Type0_150S", "LC.Type1_150S", "LC.Type2_150S",
                                       "LC.Type3_150S", "LC.Type4_150S", "LC.Type5_150S",
                                       "LC.Type6_150S", "LC.Type7_150S", "LC.Type8_150S",
                                       "LC.Type9_150S", "LC.Type10_150S", "LC.Type11_150S",
                                       "LC.Type12_150S", "LC.Type13_150S", "LC.Type14_150S",
                                       "LC.Type15_150S")

      df1 <- cbind(df1, rasterValue.150.S)
      
      #Extract points from 150 km East
      csv.150.E <- csv
      coordinates(csv.150.E) <- ~ X.150.E + Y.150.E
      rasterValue.150.E <- extract(rasterStack, csv.150.E, method = "simple")
      rasterValue.150.E <- as.data.frame(rasterValue.150.E)
      columns <- colnames(rasterValue.150.E)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.E, columns)
      colnames(rasterValue.150.E) <- c("mean.EVI_150E", "mean.VIIRS_150E", "sd.EVI_150E",
                                       "sd.VIIRS_150E", "LC.Type0_150E", "LC.Type1_150E", "LC.Type2_150E",
                                       "LC.Type3_150E", "LC.Type4_150E", "LC.Type5_150E",
                                       "LC.Type6_150E", "LC.Type7_150E", "LC.Type8_150E",
                                       "LC.Type9_150E", "LC.Type10_150E", "LC.Type11_150E",
                                       "LC.Type12_150E", "LC.Type13_150E", "LC.Type14_150E",
                                       "LC.Type15_150E")

      df1 <- cbind(df1, rasterValue.150.E)
      
      #Extract points from 150 km West
      csv.150.W <- csv
      coordinates(csv.150.W) <- ~ X.150.W + Y.150.W
      rasterValue.150.W <- extract(rasterStack, csv.150.W, method = "simple")
      rasterValue.150.W <- as.data.frame(rasterValue.150.W)
      columns <- colnames(rasterValue.150.W)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.W, columns)
      colnames(rasterValue.150.W) <- c("mean.EVI_150W", "mean.VIIRS_150W", "sd.EVI_150W",
                                       "sd.VIIRS_150W", "LC.Type0_150W", "LC.Type1_150W", "LC.Type2_150W",
                                       "LC.Type3_150W", "LC.Type4_150W", "LC.Type5_150W",
                                       "LC.Type6_150W", "LC.Type7_150W", "LC.Type8_150W",
                                       "LC.Type9_150W", "LC.Type10_150W", "LC.Type11_150W",
                                       "LC.Type12_150W", "LC.Type13_150W", "LC.Type14_150W",
                                       "LC.Type15_150W")

      df1 <- cbind(df1, rasterValue.150.W)
      
      #Create a dataframe for the second period
      
      df2 <- data.frame()
      tmp.period.dir <- paste(sep = "", tmp.month.dir, "second/")
      ifelse(!dir.exists(file.path(tmp.period.dir)), 
             dir.create(file.path(tmp.period.dir), recursive=T), FALSE)
      
      copy_file(mean.evi.list[2], tmp.period.dir)
      
      dates <- extract_date(mean.evi.list[2])
      evi.year <- as.numeric(dates[1])
      evi.month <- as.numeric(dates[2])
      evi.day <- as.numeric(dates[3])
      evi.period <- dates[4]
      
      df2 <- cbind(required.cols, evi.year, evi.month, evi.day, evi.period)
      colnames(df2)[4:7] <- c("Year", "Month", "Day", "Period")
      
      sd.evi.dir <- paste(sep = "", evi.dir, "sd/", year, '/', month, '/')
      sd.evi.list <- list.files(sd.evi.dir, full.names = TRUE)
      copy_file(sd.evi.list[2], tmp.period.dir)
      
      lc.path <- paste(sep = "", lc.dir, year, '/')
      lc.list <- list.files(lc.path, full.names = TRUE)
      copy_file(lc.list, tmp.period.dir)
      
      mean.viir.path <- paste(sep = "", viir.dir, "mean/", year, '/', month, '/')
      mean.viir.list <- list.files(mean.viir.path, full.names = TRUE)
      copy_file(mean.viir.list, tmp.period.dir)
      
      sd.viir.path <- paste(sep = "", viir.dir, "sd/", year, '/', month, '/')
      sd.viir.list <- list.files(sd.viir.path, full.names = TRUE)
      copy_file(sd.viir.list, tmp.period.dir)
      
      tmp.folder.list <- list.files(tmp.period.dir, full.names = TRUE)
      rasterStack <- lapply(tmp.folder.list, stack)
      rasterStack <- stack(rasterStack)
      
      #Extract points from focal coordinates
      csv.focal <- csv
      coordinates(csv.focal) <- ~ X + Y
      rasterValue <- extract(rasterStack, csv.focal, method = "simple")
      rasterValue <- as.data.frame(rasterValue)
      columns <- colnames(rasterValue)
      columns <- mixedsort(columns)
      setcolorder(rasterValue, columns)
      colnames(rasterValue) <- c("mean.EVI", "mean.VIIRS", "sd.EVI","sd.VIIRS", 
                                 "LC.Type0", "LC.Type1", "LC.Type2",
                                 "LC.Type3", "LC.Type4", "LC.Type5",
                                 "LC.Type6", "LC.Type7", "LC.Type8",
                                 "LC.Type9", "LC.Type10", "LC.Type11",
                                 "LC.Type12", "LC.Type13", "LC.Type14",
                                 "LC.Type15")

      df2 <- cbind(df2, rasterValue)
      
      #Extract points from 75 km North
      csv.75.N <- csv
      coordinates(csv.75.N) <- ~ X.75.N + Y.75.N
      rasterValue.75.N <- extract(rasterStack, csv.75.N, method = "simple")
      rasterValue.75.N <- as.data.frame(rasterValue.75.N)
      columns <- colnames(rasterValue.75.N)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.N, columns)
      colnames(rasterValue.75.N) <- c("mean.EVI_75N", "mean.VIIRS_75N", "sd.EVI_75N",
                                      "sd.VIIRS_75N", "LC.Type0_75N", "LC.Type1_75N", "LC.Type2_75N",
                                      "LC.Type3_75N", "LC.Type4_75N", "LC.Type5_75N",
                                      "LC.Type6_75N", "LC.Type7_75N", "LC.Type8_75N",
                                      "LC.Type9_75N", "LC.Type10_75N", "LC.Type11_75N",
                                      "LC.Type12_75N", "LC.Type13_75N", "LC.Type14_75N",
                                      "LC.Type15_75N")

      df2 <- cbind(df2, rasterValue.75.N)
      
      #Extract points from 75 km South
      csv.75.S <- csv
      coordinates(csv.75.S) <- ~ X.75.S + Y.75.S
      rasterValue.75.S <- extract(rasterStack, csv.75.S, method = "simple")
      rasterValue.75.S <- as.data.frame(rasterValue.75.S)
      columns <- colnames(rasterValue.75.S)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.S, columns)
      colnames(rasterValue.75.S) <- c("mean.EVI_75S", "mean.VIIRS_75S", "sd.EVI_75S",
                                      "sd.VIIRS_75S", "LC.Type0_75S", "LC.Type1_75S", "LC.Type2_75S",
                                      "LC.Type3_75S", "LC.Type4_75S", "LC.Type5_75S",
                                      "LC.Type6_75S", "LC.Type7_75S", "LC.Type8_75S",
                                      "LC.Type9_75S", "LC.Type10_75S", "LC.Type11_75S",
                                      "LC.Type12_75S", "LC.Type13_75S", "LC.Type14_75S",
                                      "LC.Type15_75S")

      df2 <- cbind(df2, rasterValue.75.S)
      
      #Extract points from 75 km East
      csv.75.E <- csv
      coordinates(csv.75.E) <- ~ X.75.E + Y.75.E
      rasterValue.75.E <- extract(rasterStack, csv.75.E, method = "simple")
      rasterValue.75.E <- as.data.frame(rasterValue.75.E)
      columns <- colnames(rasterValue.75.E)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.E, columns)
      colnames(rasterValue.75.E) <- c("mean.EVI_75E", "mean.VIIRS_75E", "sd.EVI_75E",
                                      "sd.VIIRS_75E", "LC.Type0_75E", "LC.Type1_75E", "LC.Type2_75E",
                                      "LC.Type3_75E", "LC.Type4_75E", "LC.Type5_75E",
                                      "LC.Type6_75E", "LC.Type7_75E", "LC.Type8_75E",
                                      "LC.Type9_75E", "LC.Type10_75E", "LC.Type11_75E",
                                      "LC.Type12_75E", "LC.Type13_75E", "LC.Type14_75E",
                                      "LC.Type15_75E")

      df2 <- cbind(df2, rasterValue.75.E)
      
      #Extract points from 75 km West
      csv.75.W <- csv
      coordinates(csv.75.W) <- ~ X.75.W + Y.75.W
      rasterValue.75.W <- extract(rasterStack, csv.75.W, method = "simple")
      rasterValue.75.W <- as.data.frame(rasterValue.75.W)
      columns <- colnames(rasterValue.75.W)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.W, columns)
      colnames(rasterValue.75.W) <- c("mean.EVI_75W", "mean.VIIRS_75W", "sd.EVI_75W",
                                      "sd.VIIRS_75W", "LC.Type0_75W", "LC.Type1_75W", "LC.Type2_75W",
                                      "LC.Type3_75W", "LC.Type4_75W", "LC.Type5_75W",
                                      "LC.Type6_75W", "LC.Type7_75W", "LC.Type8_75W",
                                      "LC.Type9_75W", "LC.Type10_75W", "LC.Type11_75W",
                                      "LC.Type12_75W", "LC.Type13_75W", "LC.Type14_75W",
                                      "LC.Type15_75W")

      df2 <- cbind(df2, rasterValue.75.W)
      
      #Extract points from 150 km North
      csv.150.N <- csv
      coordinates(csv.150.N) <- ~ X.150.N + Y.150.N
      rasterValue.150.N <- extract(rasterStack, csv.150.N, method = "simple")
      rasterValue.150.N <- as.data.frame(rasterValue.150.N)
      columns <- colnames(rasterValue.150.N)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.N, columns)
      colnames(rasterValue.150.N) <- c("mean.EVI_150N", "mean.VIIRS_150N", "sd.EVI_150N",
                                       "sd.VIIRS_150N", "LC.Type0_150N", "LC.Type1_150N", "LC.Type2_150N",
                                       "LC.Type3_150N", "LC.Type4_150N", "LC.Type5_150N",
                                       "LC.Type6_150N", "LC.Type7_150N", "LC.Type8_150N",
                                       "LC.Type9_150N", "LC.Type10_150N", "LC.Type11_150N",
                                       "LC.Type12_150N", "LC.Type13_150N", "LC.Type14_150N",
                                       "LC.Type15_150N")

      df2 <- cbind(df2, rasterValue.150.N)
      
      #Extract points from 150 km South
      csv.150.S <- csv
      coordinates(csv.150.S) <- ~ X.150.S + Y.150.S
      rasterValue.150.S <- extract(rasterStack, csv.150.S, method = "simple")
      rasterValue.150.S <- as.data.frame(rasterValue.150.S)
      columns <- colnames(rasterValue.150.S)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.S, columns)
      colnames(rasterValue.150.S) <- c("mean.EVI_150S", "mean.VIIRS_150S", "sd.EVI_150S",
                                       "sd.VIIRS_150S", "LC.Type0_150S", "LC.Type1_150S", "LC.Type2_150S",
                                       "LC.Type3_150S", "LC.Type4_150S", "LC.Type5_150S",
                                       "LC.Type6_150S", "LC.Type7_150S", "LC.Type8_150S",
                                       "LC.Type9_150S", "LC.Type10_150S", "LC.Type11_150S",
                                       "LC.Type12_150S", "LC.Type13_150S", "LC.Type14_150S",
                                       "LC.Type15_150S")

      df2 <- cbind(df2, rasterValue.150.S)
      
      #Extract points from 150 km East
      csv.150.E <- csv
      coordinates(csv.150.E) <- ~ X.150.E + Y.150.E
      rasterValue.150.E <- extract(rasterStack, csv.150.E, method = "simple")
      rasterValue.150.E <- as.data.frame(rasterValue.150.E)
      columns <- colnames(rasterValue.150.E)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.E, columns)
      colnames(rasterValue.150.E) <- c("mean.EVI_150E", "mean.VIIRS_150E", "sd.EVI_150E",
                                       "sd.VIIRS_150E", "LC.Type0_150E", "LC.Type1_150E", "LC.Type2_150E",
                                       "LC.Type3_150E", "LC.Type4_150E", "LC.Type5_150E",
                                       "LC.Type6_150E", "LC.Type7_150E", "LC.Type8_150E",
                                       "LC.Type9_150E", "LC.Type10_150E", "LC.Type11_150E",
                                       "LC.Type12_150E", "LC.Type13_150E", "LC.Type14_150E",
                                       "LC.Type15_150E")

      df2 <- cbind(df2, rasterValue.150.E)
      
      #Extract points from 150 km West
      csv.150.W <- csv
      coordinates(csv.150.W) <- ~ X.150.W + Y.150.W
      rasterValue.150.W <- extract(rasterStack, csv.150.W, method = "simple")
      rasterValue.150.W <- as.data.frame(rasterValue.150.W)
      columns <- colnames(rasterValue.150.W)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.W, columns)
      colnames(rasterValue.150.W) <- c("mean.EVI_150W", "mean.VIIRS_150W", "sd.EVI_150W",
                                       "sd.VIIRS_150W", "LC.Type0_150W", "LC.Type1_150W", "LC.Type2_150W",
                                       "LC.Type3_150W", "LC.Type4_150W", "LC.Type5_150W",
                                       "LC.Type6_150W", "LC.Type7_150W", "LC.Type8_150W",
                                       "LC.Type9_150W", "LC.Type10_150W", "LC.Type11_150W",
                                       "LC.Type12_150W", "LC.Type13_150W", "LC.Type14_150W",
                                       "LC.Type15_150W")

      df2 <- cbind(df2, rasterValue.150.W)
      
      #Combine two dataframes and write it as .csv
      df1 <- rbind(df1, df2)
      csv.path <- paste(sep = "", csv.dir, year, '/', month, '/')
      ifelse(!dir.exists(file.path(csv.path)), 
             dir.create(file.path(csv.path), recursive=T), FALSE)
      csv.path <- paste(sep = "", csv.path, "points_", unmatch, evi.year, "_", evi.month, ".csv")
      write.csv(df1, csv.path, row.names = FALSE)
      gc()

    } else {
      #Create a dataframe for the only period
      df <- data.frame()
      tmp.period.dir <- paste(sep = "", tmp.month.dir, "only/")
      ifelse(!dir.exists(file.path(tmp.period.dir)), 
             dir.create(file.path(tmp.period.dir), recursive=T), FALSE)
      
      copy_file(mean.evi.list[1], tmp.period.dir)
      
      dates <- extract_date(mean.evi.list[1])
      evi.year <- as.numeric(dates[1])
      evi.month <- as.numeric(dates[2])
      evi.day <- as.numeric(dates[3])
      evi.period <- dates[4]
      
      if (year != evi.year || month != evi.month){
        unmatch = "Unmatch"
      } else {
        unmatch = ""
      }
      
      df <- cbind(required.cols, evi.year, evi.month, evi.day, evi.period)
      colnames(df)[4:7] <- c("Year", "Month", "Day", "Period")
      
      sd.evi.dir <- paste(sep = "", evi.dir, "sd/", year, '/', month, '/')
      sd.evi.list <- list.files(sd.evi.dir, full.names = TRUE)
      copy_file(sd.evi.list[1], tmp.period.dir)
      
      lc.path <- paste(sep = "", lc.dir, year, '/')
      lc.list <- list.files(lc.path, full.names = TRUE)
      copy_file(lc.list, tmp.period.dir)
      
      mean.viir.path <- paste(sep = "", viir.dir, "mean/", year, '/', month, '/')
      mean.viir.list <- list.files(mean.viir.path, full.names = TRUE)
      copy_file(mean.viir.list, tmp.period.dir)
      
      sd.viir.path <- paste(sep = "", viir.dir, "sd/", year, '/', month, '/')
      sd.viir.list <- list.files(sd.viir.path, full.names = TRUE)
      copy_file(sd.viir.list, tmp.period.dir)
      
      tmp.folder.list <- list.files(tmp.period.dir, full.names = TRUE)
      rasterStack <- lapply(tmp.folder.list, stack)
      rasterStack <- stack(rasterStack)
      
      #Extract points from focal coordinates
      csv.focal <- csv
      coordinates(csv.focal) <- ~ X + Y
      rasterValue <- extract(rasterStack, csv.focal, method = "simple")
      rasterValue <- as.data.frame(rasterValue)
      columns <- colnames(rasterValue)
      columns <- mixedsort(columns)
      setcolorder(rasterValue, columns)
      colnames(rasterValue) <- c("mean.EVI", "mean.VIIRS", "sd.EVI","sd.VIIRS", 
                                 "LC.Type0", "LC.Type1", "LC.Type2",
                                 "LC.Type3", "LC.Type4", "LC.Type5",
                                 "LC.Type6", "LC.Type7", "LC.Type8",
                                 "LC.Type9", "LC.Type10", "LC.Type11",
                                 "LC.Type12", "LC.Type13", "LC.Type14",
                                 "LC.Type15")

      df <- cbind(df, rasterValue)
      
      #Extract points from 75 km North
      csv.75.N <- csv
      coordinates(csv.75.N) <- ~ X.75.N + Y.75.N
      rasterValue.75.N <- extract(rasterStack, csv.75.N, method = "simple")
      rasterValue.75.N <- as.data.frame(rasterValue.75.N)
      columns <- colnames(rasterValue.75.N)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.N, columns)
      colnames(rasterValue.75.N) <- c("mean.EVI_75N", "mean.VIIRS_75N", "sd.EVI_75N",
                                      "sd.VIIRS_75N", "LC.Type0_75N", "LC.Type1_75N", "LC.Type2_75N",
                                      "LC.Type3_75N", "LC.Type4_75N", "LC.Type5_75N",
                                      "LC.Type6_75N", "LC.Type7_75N", "LC.Type8_75N",
                                      "LC.Type9_75N", "LC.Type10_75N", "LC.Type11_75N",
                                      "LC.Type12_75N", "LC.Type13_75N", "LC.Type14_75N",
                                      "LC.Type15_75N")

      df <- cbind(df, rasterValue.75.N)
      
      #Extract points from 75 km South
      csv.75.S <- csv
      coordinates(csv.75.S) <- ~ X.75.S + Y.75.S
      rasterValue.75.S <- extract(rasterStack, csv.75.S, method = "simple")
      rasterValue.75.S <- as.data.frame(rasterValue.75.S)
      columns <- colnames(rasterValue.75.S)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.S, columns)
      colnames(rasterValue.75.S) <- c("mean.EVI_75S", "mean.VIIRS_75S", "sd.EVI_75S",
                                      "sd.VIIRS_75S", "LC.Type0_75S", "LC.Type1_75S", "LC.Type2_75S",
                                      "LC.Type3_75S", "LC.Type4_75S", "LC.Type5_75S",
                                      "LC.Type6_75S", "LC.Type7_75S", "LC.Type8_75S",
                                      "LC.Type9_75S", "LC.Type10_75S", "LC.Type11_75S",
                                      "LC.Type12_75S", "LC.Type13_75S", "LC.Type14_75S",
                                      "LC.Type15_75S")

      df <- cbind(df, rasterValue.75.S)
      
      #Extract points from 75 km East
      csv.75.E <- csv
      coordinates(csv.75.E) <- ~ X.75.E + Y.75.E
      rasterValue.75.E <- extract(rasterStack, csv.75.E, method = "simple")
      rasterValue.75.E <- as.data.frame(rasterValue.75.E)
      columns <- colnames(rasterValue.75.E)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.E, columns)
      colnames(rasterValue.75.E) <- c("mean.EVI_75E", "mean.VIIRS_75E", "sd.EVI_75E",
                                      "sd.VIIRS_75E", "LC.Type0_75E", "LC.Type1_75E", "LC.Type2_75E",
                                      "LC.Type3_75E", "LC.Type4_75E", "LC.Type5_75E",
                                      "LC.Type6_75E", "LC.Type7_75E", "LC.Type8_75E",
                                      "LC.Type9_75E", "LC.Type10_75E", "LC.Type11_75E",
                                      "LC.Type12_75E", "LC.Type13_75E", "LC.Type14_75E",
                                      "LC.Type15_75E")

      df <- cbind(df, rasterValue.75.E)
      
      #Extract points from 75 km West
      csv.75.W <- csv
      coordinates(csv.75.W) <- ~ X.75.W + Y.75.W
      rasterValue.75.W <- extract(rasterStack, csv.75.W, method = "simple")
      rasterValue.75.W <- as.data.frame(rasterValue.75.W)
      columns <- colnames(rasterValue.75.W)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.75.W, columns)
      colnames(rasterValue.75.W) <- c("mean.EVI_75W", "mean.VIIRS_75W", "sd.EVI_75W",
                                      "sd.VIIRS_75W", "LC.Type0_75W", "LC.Type1_75W", "LC.Type2_75W",
                                      "LC.Type3_75W", "LC.Type4_75W", "LC.Type5_75W",
                                      "LC.Type6_75W", "LC.Type7_75W", "LC.Type8_75W",
                                      "LC.Type9_75W", "LC.Type10_75W", "LC.Type11_75W",
                                      "LC.Type12_75W", "LC.Type13_75W", "LC.Type14_75W",
                                      "LC.Type15_75W")

      df <- cbind(df, rasterValue.75.W)
      
      #Extract points from 150 km North
      csv.150.N <- csv
      coordinates(csv.150.N) <- ~ X.150.N + Y.150.N
      rasterValue.150.N <- extract(rasterStack, csv.150.N, method = "simple")
      rasterValue.150.N <- as.data.frame(rasterValue.150.N)
      columns <- colnames(rasterValue.150.N)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.N, columns)
      colnames(rasterValue.150.N) <- c("mean.EVI_150N", "mean.VIIRS_150N", "sd.EVI_150N",
                                       "sd.VIIRS_150N", "LC.Type0_150N", "LC.Type1_150N", "LC.Type2_150N",
                                       "LC.Type3_150N", "LC.Type4_150N", "LC.Type5_150N",
                                       "LC.Type6_150N", "LC.Type7_150N", "LC.Type8_150N",
                                       "LC.Type9_150N", "LC.Type10_150N", "LC.Type11_150N",
                                       "LC.Type12_150N", "LC.Type13_150N", "LC.Type14_150N",
                                       "LC.Type15_150N")

      df <- cbind(df, rasterValue.150.N)
      
      #Extract points from 150 km South
      csv.150.S <- csv
      coordinates(csv.150.S) <- ~ X.150.S + Y.150.S
      rasterValue.150.S <- extract(rasterStack, csv.150.S, method = "simple")
      rasterValue.150.S <- as.data.frame(rasterValue.150.S)
      columns <- colnames(rasterValue.150.S)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.S, columns)
      colnames(rasterValue.150.S) <- c("mean.EVI_150S", "mean.VIIRS_150S", "sd.EVI_150S",
                                       "sd.VIIRS_150S", "LC.Type0_150S", "LC.Type1_150S", "LC.Type2_150S",
                                       "LC.Type3_150S", "LC.Type4_150S", "LC.Type5_150S",
                                       "LC.Type6_150S", "LC.Type7_150S", "LC.Type8_150S",
                                       "LC.Type9_150S", "LC.Type10_150S", "LC.Type11_150S",
                                       "LC.Type12_150S", "LC.Type13_150S", "LC.Type14_150S",
                                       "LC.Type15_150S")

      df <- cbind(df, rasterValue.150.S)
      
      #Extract points from 150 km East
      csv.150.E <- csv
      coordinates(csv.150.E) <- ~ X.150.E + Y.150.E
      rasterValue.150.E <- extract(rasterStack, csv.150.E, method = "simple")
      rasterValue.150.E <- as.data.frame(rasterValue.150.E)
      columns <- colnames(rasterValue.150.E)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.E, columns)
      colnames(rasterValue.150.E) <- c("mean.EVI_150E", "mean.VIIRS_150E", "sd.EVI_150E",
                                       "sd.VIIRS_150E", "LC.Type0_150E", "LC.Type1_150E", "LC.Type2_150E",
                                       "LC.Type3_150E", "LC.Type4_150E", "LC.Type5_150E",
                                       "LC.Type6_150E", "LC.Type7_150E", "LC.Type8_150E",
                                       "LC.Type9_150E", "LC.Type10_150E", "LC.Type11_150E",
                                       "LC.Type12_150E", "LC.Type13_150E", "LC.Type14_150E",
                                       "LC.Type15_150E")

      df <- cbind(df, rasterValue.150.E)
      
      #Extract points from 150 km West
      csv.150.W <- csv
      coordinates(csv.150.W) <- ~ X.150.W + Y.150.W
      rasterValue.150.W <- extract(rasterStack, csv.150.W, method = "simple")
      rasterValue.150.W <- as.data.frame(rasterValue.150.W)
      columns <- colnames(rasterValue.150.W)
      columns <- mixedsort(columns)
      setcolorder(rasterValue.150.W, columns)
      colnames(rasterValue.150.W) <- c("mean.EVI_150W", "mean.VIIRS_150W", "sd.EVI_150W",
                                       "sd.VIIRS_150W", "LC.Type0_150W", "LC.Type1_150W", "LC.Type2_150W",
                                       "LC.Type3_150W", "LC.Type4_150W", "LC.Type5_150W",
                                       "LC.Type6_150W", "LC.Type7_150W", "LC.Type8_150W",
                                       "LC.Type9_150W", "LC.Type10_150W", "LC.Type11_150W",
                                       "LC.Type12_150W", "LC.Type13_150W", "LC.Type14_150W",
                                       "LC.Type15_150W")

      df <- cbind(df, rasterValue.150.W)
      
      csv.path <- paste(sep = "", csv.dir, year, '/', month, '/')
      ifelse(!dir.exists(file.path(csv.path)), 
             dir.create(file.path(csv.path), recursive=T), FALSE)
      csv.path <- paste(sep = "", csv.path, "points_", unmatch, evi.year, "_", evi.month, ".csv")
      write.csv(df, csv.path, row.names = FALSE)
      gc()
    }
    
  }
cat("Stop parallel process!\n")
parallel::stopCluster(cl = my_cluster)
unlink(tmp.year, recursive = T)
}
#############################################################################
#We extracted radar values, as well as date (YY/MM/DD) and time (HH:MM:SS) from
#radar files, removed rows containing the -99 value and replaced NAs with 0.
#We outputed the csv files per year per radar station
#############################################################################
library(foreach)
library(doParallel)
library(rgdal)
library(raster)
library(stringr)
library(gtools)
library(tools)
library(data.table)

csv <- read.csv("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/5_Stations_rand_points_75.csv")
forecast.dir <- "/Volumes/forecast2/output/"
radars <- list.files(forecast.dir)
years <- c(2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021)
eBird <- raster("/Volumes/forecast_predictors/ebird_raster/ebird_raster_template.tif")
dest.dir <- "/Volumes/forecast_predictors/extracted_points/2_Radars/"

extract_date <- function(myfile){
  filename <- basename(myfile)
  filename <- file_path_sans_ext(filename)
  file.digits <- str_extract_all(filename, pattern ="\\d")
  file.digits <- unlist(file.digits)
  file.year <- paste(file.digits[1:4], collapse = "")
  file.year <- as.numeric(file.year)
  file.month <- paste(file.digits[5:6], collapse = "")
  file.month <- as.numeric(file.month)
  file.day <- paste(file.digits[7:8], collapse = "")
  file.day <- as.numeric(file.day)
  file.hour <- paste(file.digits[9:10], collapse = "")
  file.hour <- as.numeric(file.hour)
  file.minute <- paste(file.digits[11:12], collapse = "")
  file.minute <- as.numeric(file.minute)
  file.second <- paste(file.digits[13:14], collapse = "")
  file.second <- as.numeric(file.second)
  output <- c(file.year, file.month, file.day, file.hour, file.minute, file.second)
  return(output)
}

cat("Start parallel process!\n")
n.cores <- parallel::detectCores() - 2
my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
print(my_cluster)
doParallel::registerDoParallel(cl = my_cluster)

foreach (radar = 1:length(radars), .errorhandling = c("pass"), .packages=c("data.table","rgdal", "raster","stringr","gtools","tools")) %dopar% {
  
  radar.points <- csv[csv$Radar.Stations==radars[radar], ]
  required.cols <- radar.points[c("Radar.Stations", "X", "Y")]
  
  for (year in years) {
    
    raster.dir <- paste(sep = "", forecast.dir, radars[radar], '/', year, '/', 
                        "raster")
    if (dir.exists(raster.dir)){
      tif.files <- list.files(raster.dir, full.names = TRUE)
      year.df <- data.frame()
      
      for (tif in 1:length(tif.files)) {
        
        df <- data.frame()
        df <- cbind(required.cols)
        dates <- extract_date(tif.files[tif])
        radar.year <- as.numeric(dates[1])
        radar.month <- as.numeric(dates[2])
        radar.day <- as.numeric(dates[3])
        radar.hour <- as.numeric(dates[4])
        radar.minute <- as.numeric(dates[5])
        radar.second <- as.numeric(dates[6])
        
        df <- cbind(df, radar.year, radar.month, radar.day, radar.hour, radar.minute, radar.second)
        colnames(df)[4:9] <- c("Year", "Month", "Day", "Hour", "Minute", "Second")
        
        focal.points <- required.cols
        coordinates(focal.points) <- ~ X + Y
        crs(focal.points) = crs(eBird)
        rast <- raster(tif.files[tif])
        focal.points <- spTransform(focal.points, crs(rast))
        # rast <- projectRaster(rast, eBird, method = "ngb")
        # rast <- resample(rast, eBird, method = "ngb")
        rasterValue <- extract(rast, focal.points, method = "simple")
        rasterValue <- as.data.frame(rasterValue)
        colnames(rasterValue) <- "Radar.value"
        df <- cbind(df, rasterValue)
        df[is.na(df)] <- 0
        df <- df[!(df$Radar.value==-99),]
        
        year.df <- rbindlist(list(year.df, df))
        
      }
      csv.dir <- paste(sep = "", dest.dir, radars[radar], "/", year, "/")
      ifelse(!dir.exists(file.path(csv.dir)), 
             dir.create(file.path(csv.dir), recursive=T), FALSE)
      csv.path <- paste(sep = "", csv.dir, year, "_", radars[radar], ".csv")
      year.df <- as.data.frame(year.df)
      write.csv(year.df, csv.path, row.names = FALSE)
    }
  }
  
}
cat("Stop parallel process!\n")
parallel::stopCluster(cl = my_cluster)

  

#############################################################################
#Here we create csv files per year for all radar stations, containing radar
#values. We also combined all date and time columns, and formatted as
#YYYY/MM/DD HH:MM:SS. We also created a new column, UTM_interval, to group
#date and times by 3-hour intervals
#############################################################################
library(foreach)
library(doParallel)
library(lubridate)
library(stringr)
library(data.table)

base.dir <- "/Volumes/forecast_predictors/extracted_points/2_Radars/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/3_UTM_intervals/"
radars.list <- list.files(base.dir)
years <- c(2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021)

cat("Start parallel process!\n")
n.cores <- parallel::detectCores() - 8
my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
print(my_cluster)
doParallel::registerDoParallel(cl = my_cluster)

foreach (year = years, .errorhandling = c("pass"), .packages=c("data.table","lubridate", "stringr")) %dopar% {

  year.file <- data.frame()
  for (radar in 1:length(radars.list)) {
    csv.dir <- paste(sep = "", base.dir, radars.list[radar], '/', year, '/')
    if (dir.exists(csv.dir)){
      csv.file <- list.files(csv.dir, pattern = "*.csv", full.names = T)
      csv <- read.csv(csv.file)
      
      csv$Year <- as.character(csv$Year)
      csv$Month <- sprintf("%02d", csv$Month)
      csv$Day <- sprintf("%02d", csv$Day)
      csv$Hour <- sprintf("%02d", csv$Hour)
      csv$Minute <- sprintf("%02d", csv$Minute)
      csv$Second <- sprintf("%02d", csv$Second)
      csv["Date_Time"] <- ymd_hms(paste(sep = "", csv$Year, csv$Month, csv$Day,
                                           csv$Hour, csv$Minute, csv$Second))
      csv["UTM_interval"] <- round_date(csv$Date_Time, "3 hours")
      csv$Date_Time <- format(csv$Date_Time,"%Y/%m/%d %H:%M:%S")
      csv$UTM_interval <- format(csv$UTM_interval,"%Y/%m/%d %H:%M:%S")
      year.file <- rbindlist(list(year.file, csv))
    }
  }
  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  csv.out.name <- paste(sep="", csv.out.dir, year, ".csv")
  year.file <- as.data.frame(year.file)
  # write.csv(year.file, csv.out.name, row.names = FALSE)
  fwrite(year.file, csv.out.name, quote = FALSE)
}
cat("Stop parallel process!\n")
parallel::stopCluster(cl = my_cluster)




#############################################################################
#We added the Unique ID to each unique combination of coordinates/radar 
#using the original csv file that I created with ~10,000 points. I also moved 
#the Unique ID column to the beginning of the csv file.
#############################################################################
library(foreach)
library(doParallel)
library(data.table)
library(dplyr)

og_points <- read.csv("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/6_Stations_rand_points_75.csv")
og_points <- og_points[-c(5:20)]
base.dir <- "/Volumes/forecast_predictors/extracted_points/3_UTM_intervals/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/4_Values_with_unique_id/"
years <- list.files(base.dir)

cat("Start parallel process!\n")
n.cores <- parallel::detectCores() - 5
my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
print(my_cluster)
doParallel::registerDoParallel(cl = my_cluster)

foreach (year = years, .errorhandling = c("pass"), .packages=c("data.table","dplyr")) %dopar% {
  csv.path <- paste(sep = "", base.dir, year, '/')
  csv.list <- list.files(csv.path, pattern = "*.csv", full.names = TRUE)
  csv <- fread(csv.list, data.table = FALSE)
  
  #Assign Unique ID from the og_points csv file based on unique combinations of
  #Radar station names as well as the Lat and Long
  csv <- as.data.frame(setDT(csv)[unique(og_points), on = c("Radar.Stations", "X", "Y"), nomatch=0])
  
  #Move the Unique ID column from the last to the first
  csv <- csv %>%
    select(Unique.ID, everything())
  
  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  csv.out.name <- paste(sep="", csv.out.dir, year, ".csv")
  
  fwrite(csv, csv.out.name, quote = FALSE)
}
cat("Stop parallel process!\n")
parallel::stopCluster(cl = my_cluster)




# eg.file <- fread("/Volumes/forecast_predictors/extracted_points/old_3_UTM_intervals/2014.csv",
#                  data.table = FALSE)
# 
# sub_file <- eg.file[1:6000,]
# eg.file <- as.data.frame(setDT(eg.file)[unique(og_points), on = c("Radar.Stations", "X", "Y"), nomatch=0])
# 
# unique(sub_file$Unique.ID)
# length(sub_file$Unique.ID)
# subfile2 <- head(eg.file, 10000)
# 
# eg.file <- eg.file %>%
#   select(Unique.ID, everything())
# 
# eg.file$Unique.ID

#############################################################################
#For terrestrial data, I combined the annual data together, and assigned the
#Unique ID value using the original csv file
#############################################################################
#https://stackoverflow.com/questions/70974563/r-merge-two-data-frames-based-on-nearest-date-and-time-match

library(foreach)
library(doParallel)
library(data.table)
library(dplyr)
library(lubridate)

base.dir <- "/Volumes/forecast_predictors/extracted_points/1_Terrestrials/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/5_Terrestrials_annual_uniqueID/"
months <- c(3,4,5,6,7,8,9,10,11)
years <- list.files(base.dir)
og_points <- read.csv("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/6_Stations_rand_points_75.csv")
og_points <- og_points[-c(5:20)]

cat("Start parallel process!\n")
n.cores <- parallel::detectCores() - 5
my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
print(my_cluster)
doParallel::registerDoParallel(cl = my_cluster)

foreach (year = years, .errorhandling = c("pass"), .packages=c("data.table","dplyr","lubridate")) %dopar% {
  
  year.df <- data.frame()
  for (month in months) {
    csv.dir <- paste(sep = "", base.dir, year, '/', month)
    csv.list <- list.files(csv.dir, pattern = "*.csv", full.names = T)
    csv <- fread(csv.list, data.table = FALSE)
    
    csv <- as.data.frame(setDT(csv)[unique(og_points), on = c("Radar.Stations", "X", "Y"), nomatch=0])
    csv <- csv %>%
      select(Unique.ID, everything())
    
    csv$Year <- as.character(csv$Year)
    csv$Month <- sprintf("%02d", csv$Month)
    csv$Day <- sprintf("%02d", csv$Day)
    
    csv["Date_Time"] <- ymd(paste(sep = "", csv$Year, csv$Month, csv$Day))
    csv$Date_Time <- format(csv$Date_Time,"%Y/%m/%d")
    
    year.df <- rbindlist(list(year.df, csv))
  }
  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  csv.out.name <- paste(sep="", csv.out.dir, year, ".csv")
  year.df <- as.data.frame(year.df)
  fwrite(year.df, csv.out.name, quote = FALSE)
}
cat("Stop parallel process!\n")
parallel::stopCluster(cl = my_cluster)











#############################################################################
#I combined the radar data and terrestrial data grouped by the Unique.ID and
#nearest time stamp (YYYY/MM/DD). I avoided using the parallel processing
#because each R instance gets as big as ~170 GB, while the whole available
#physical memory for the tower is ~250GB.
#############################################################################
library(data.table)
library(lubridate)

terrest.dir <- "/Volumes/forecast_predictors/extracted_points/5_Terrestrials_annual_uniqueID/"
radar.dir <- "/Volumes/forecast_predictors/extracted_points/4_RadarValues_with_unique_id/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/6_Radar_Terrestrial_combined/"

years <- list.files(radar.dir)


for (year in years) {
  
  rd.csv.dir <- paste(sep = "", radar.dir, year, '/')
  rd.csv.list <- list.files(rd.csv.dir, pattern = "*.csv", full.names = T)
  print(rd.csv.list)
  rd.csv <- fread(rd.csv.list, data.table = F)
  
  cat("Change column names\n")
  rd.csv <- setnames(rd.csv, old = c("Year", "Month", "Day", "Hour", "Minute", "Second"), 
                     new = c("Radar.Year", "Radar.Month", "Radar.Day", "Radar.Hour", "Radar.Minute", "Radar.Second"),
                     skip_absent=TRUE)
  rd.csv$Radar.Year <- as.character(rd.csv$Radar.Year)
  rd.csv$Radar.Month <- sprintf("%02d", rd.csv$Radar.Month)
  rd.csv$Radar.Day <- sprintf("%02d", rd.csv$Radar.Day)
  rd.csv["Date"] <- ymd(paste(sep = "", rd.csv$Radar.Year, rd.csv$Radar.Month, rd.csv$Radar.Day))
  
  terrest.csv.dir <- paste(sep = "", terrest.dir, year, '/')
  terrest.csv.list <- list.files(terrest.csv.dir, pattern = "*.csv", full.names = T)
  terrest.csv <- fread(terrest.csv.list, data.table = F)
  colnames(terrest.csv)[which(names(terrest.csv) == "Date_Time")] <- "Date"
  terrest.csv$Date <- ymd(terrest.csv$Date)
  
  rd.csv <- setDT(rd.csv)
  terrest.csv <- setDT(terrest.csv)
  
  cat("Merging data for ", year, '\n')
  rd.csv <- terrest.csv[rd.csv, on = .(Unique.ID ,Date) , roll = "nearest", by = Unique.ID]
  rd.csv <- as.data.frame(rd.csv)
  rd.csv <- subset(rd.csv, select = -c(Period, Date, i.Radar.Stations, i.X, i.Y))
  
  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  
  csv.out.name <- paste(sep="", csv.out.dir, year, ".csv")
  cat("Writint out the data for ", year, '\n')
  fwrite(rd.csv, csv.out.name, quote = FALSE)
  Sys.sleep(10)
  remove(rd.csv)
  gc()
}



# library(foreach)
# library(doParallel)
# library(data.table)
# library(tidyverse)
# library(lubridate)
# 
# terrest.dir <- "/Volumes/forecast_predictors/extracted_points/5_Terrestrials_annual_uniqueID/"
# radar.dir <- "/Volumes/forecast_predictors/extracted_points/4_RadarValues_with_unique_id/"
# dest.dir <- "/Volumes/forecast_predictors/extracted_points/6_Radar_Terrestrial_combined/"
# 
# years <- list.files(radar.dir)
# 
# cat("Start parallel process!\n")
# n.cores <- parallel::detectCores() - 5
# my_cluster <- parallel::makeCluster(n.cores) #, type = "PSOCK" or "FORK"
# print(my_cluster)
# doParallel::registerDoParallel(cl = my_cluster)
# 
# foreach (year = years, .errorhandling = c("pass"), .packages=c("data.table","tidyverse","lubridate")) %dopar% {
#   
#   combined.df <- data.frame()
#   rd.csv.dir <- paste(sep = "", radar.dir, year, '/')
#   rd.csv.list <- list.files(rd.csv.dir, pattern = "*.csv", full.names = T)
#   rd.csv <- fread(rd.csv.list, data.table = F)
#   
#   rd.csv <- setnames(rd.csv, old = c("Year", "Month", "Day", "Hour", "Minute", "Second"), 
#                      new = c("Radar.Year", "Radar.Month", "Radar.Day", "Radar.Hour", "Radar.Minute", "Radar.Second"),
#                      skip_absent=TRUE)
#   rd.csv$Radar.Year <- as.character(rd.csv$Radar.Year)
#   rd.csv$Radar.Month <- sprintf("%02d", rd.csv$Radar.Month)
#   rd.csv$Radar.Day <- sprintf("%02d", rd.csv$Radar.Day)
#   rd.csv["Date"] <- ymd(paste(sep = "", rd.csv$Radar.Year, rd.csv$Radar.Month, rd.csv$Radar.Day))
#   
#   terrest.csv.dir <- paste(sep = "", terrest.dir, year, '/')
#   terrest.csv.list <- list.files(terrest.csv.dir, pattern = "*.csv", full.names = T)
#   terrest.csv <- fread(terrest.csv.list, data.table = F)
#   colnames(terrest.csv)[which(names(terrest.csv) == "Date_Time")] <- "Date"
#   terrest.csv$Date <- ymd(terrest.csv$Date)
#   
#   for (id in 1:10103) {
#     
#     sub.rd.csv <- rd.csv %>% filter(Unique.ID == id)
#     sub.terrest.csv <- terrest.csv %>% filter(Unique.ID == id)
#     
#     tmp.combined <- as.data.frame(
#       setDT(sub.terrest.csv)[sub.rd.csv, on = "Date", roll = "nearest"])
#     
#     combined.df <- rbindlist(list(combined.df, tmp.combined))
#   }
#   combined.df <- as.data.frame(combined.df)
#   combined.df <- subset(combined.df, select = -c(i.Radar.Stations, i.Unique.ID, i.X, i.Y, Period, Date))
#   csv.out.dir <- paste(sep = "", dest.dir, year, '/')
#   ifelse(!dir.exists(file.path(csv.out.dir)), 
#          dir.create(file.path(csv.out.dir), recursive=T), FALSE)
#   csv.out.name <- paste(sep="", csv.out.dir, year, ".csv")
#   combined.df <- as.data.frame(combined.df)
#   fwrite(combined.df, csv.out.name, quote = FALSE)
# }
# cat("Stop parallel process!\n")
# parallel::stopCluster(cl = my_cluster)












#############################################################################
#I combined atmospheric data for all 9 points per month (using column-based, 
#or cbind style). This process can be done through parallel processing since
#it's not hitting the max memory
#############################################################################
library(data.table)

base.dir <- "/Volumes/night_winds/data_wide/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/7_AtmosphericData_combined_monthly/"

# elev <- "/Volumes/forecast_predictors/elevation/elevation_csv/elevation.csv"

# years <- c(2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021)
months <- c("03", "04", "05", "06", "07", "08", "09", "10", "11")

for (year in 2012) {
  
  for (month in months) {
    
    focal.csv <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_c_"), 
                            full.names = T)
    cat(focal.csv, '\n')
    c.csv <- fread(focal.csv)
    neworder <- c("RdrSttn", "date", "utc")
    setcolorder(c.csv, neworder = neworder)
    setnames(c.csv, 1:3, c("Unique.ID", "Date", "UTC"))
    c.csv <- subset(c.csv, select = -c(longitude, latitude))
    print(colnames(c.csv))
    
    #75 km North
    n.75 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_n_075"), 
                       full.names = T)
    n.75 <- fread(n.75)
    setcolorder(n.75, neworder = neworder)
    setnames(n.75, 1:3, c("Unique.ID", "Date", "UTC"))
    n.75 <- subset(n.75, select = -c(longitude, latitude))
    setnames(n.75, 4:length(n.75), paste0(names(n.75)[4:length(n.75)], '_75N'))
    print(colnames(n.75))
    
    # 75 km South
    s.75 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_s_075"), 
                       full.names = T)
    s.75 <- fread(s.75)
    setcolorder(s.75, neworder = neworder)
    setnames(s.75, 1:3, c("Unique.ID", "Date", "UTC"))
    s.75 <- subset(s.75, select = -c(longitude, latitude))
    setnames(s.75, 4:length(s.75), paste0(names(s.75)[4:length(s.75)], '_75S'))
    print(colnames(s.75))
    
    #75 km East
    e.75 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_e_075"), 
                       full.names = T)
    e.75 <- fread(e.75)
    setcolorder(e.75, neworder = neworder)
    setnames(e.75, 1:3, c("Unique.ID", "Date", "UTC"))
    e.75 <- subset(e.75, select = -c(longitude, latitude))
    setnames(e.75, 4:length(e.75), paste0(names(e.75)[4:length(e.75)], '_75E'))
    print(colnames(e.75))
    
    #75 km West
    w.75 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_w_075"), 
                       full.names = T)
    w.75 <- fread(w.75)
    setcolorder(w.75, neworder = neworder)
    setnames(w.75, 1:3, c("Unique.ID", "Date", "UTC"))
    w.75 <- subset(w.75, select = -c(longitude, latitude))
    setnames(w.75, 4:length(w.75), paste0(names(w.75)[4:length(w.75)], '_75W'))
    print(colnames(w.75))
    
    #150 km North
    n.150 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_n_150"), 
                       full.names = T)
    n.150 <- fread(n.150)
    setcolorder(n.150, neworder = neworder)
    setnames(n.150, 1:3, c("Unique.ID", "Date", "UTC"))
    n.150 <- subset(n.150, select = -c(longitude, latitude))
    setnames(n.150, 4:length(n.150), paste0(names(n.150)[4:length(n.150)], '_150N'))
    print(colnames(n.150))
    
    #150 km South
    s.150 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_s_150"), 
                        full.names = T)
    s.150 <- fread(s.150)
    setcolorder(s.150, neworder = neworder)
    setnames(s.150, 1:3, c("Unique.ID", "Date", "UTC"))
    s.150 <- subset(s.150, select = -c(longitude, latitude))
    setnames(s.150, 4:length(s.150), paste0(names(s.150)[4:length(s.150)], '_150S'))
    print(colnames(s.150))
    
    #150 km East
    e.150 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_e_150"), 
                        full.names = T)
    e.150 <- fread(e.150)
    setcolorder(e.150, neworder = neworder)
    setnames(e.150, 1:3, c("Unique.ID", "Date", "UTC"))
    e.150 <- subset(e.150, select = -c(longitude, latitude))
    setnames(e.150, 4:length(e.150), paste0(names(e.150)[4:length(e.150)], '_150E'))
    print(colnames(e.150))
    
    #150 km West
    w.150 <- list.files(base.dir, pattern = paste(sep = "", "NARR_", year, month, "_w_150"), 
                        full.names = T)
    w.150 <- fread(w.150)
    setcolorder(w.150, neworder = neworder)
    setnames(w.150, 1:3, c("Unique.ID", "Date", "UTC"))
    w.150 <- subset(w.150, select = -c(longitude, latitude))
    setnames(w.150, 4:length(w.150), paste0(names(w.150)[4:length(w.150)], '_150W'))
    print(colnames(w.150))
    
    cat("Merge focal with 75 N and call it NARR\n")
    narr <- c.csv[unique(n.75), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 75 S\n")
    narr <- narr[unique(s.75), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 75 E\n")
    narr <- narr[unique(e.75), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 75 W\n")
    narr <- narr[unique(w.75), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 150 N\n")
    narr <- narr[unique(n.150), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 150 S\n")
    narr <- narr[unique(s.150), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 150 E\n")
    narr <- narr[unique(e.150), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    cat("Merge NARR with 150 W\n")
    narr <- narr[unique(w.150), on = c("Unique.ID", "Date", "UTC"), nomatch=0]
    
    narr <- as.data.frame(narr)
    csv.out.dir <- paste(sep = "", dest.dir, year, '/', month, '/')
    ifelse(!dir.exists(file.path(csv.out.dir)), 
           dir.create(file.path(csv.out.dir), recursive=T), FALSE)
    
    csv.out.name <- paste(sep="", csv.out.dir, year, month, ".csv")
    cat("Writint out the data for ", "YYYY:", year, "MM:", month, '\n')
    fwrite(narr, csv.out.name, quote = FALSE)
    
    remove(c.csv, n.75, s.75, e.75, w.75, n.150, s.150, e.150, w.150)
    gc()
  }
}





#############################################################################
#We combined all atmospheric data to create annual datasets. This process 
#results in >100 GB per file, and SHOULD NOT be done through parallel
#processing to avoid crashing R
#############################################################################
library(data.table)

elev <- fread("/Volumes/forecast_predictors/elevation/elevation_csv/elevation.csv")
setkey(elev, Unique.ID)

base.dir <- "/Volumes/forecast_predictors/extracted_points/7_AtmosphericData_combined_monthly/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/8_Atmospheric_annual/"

years <- list.files(base.dir)
months <- c("03", "04", "05", "06", "07", "08", "09", "10", "11")

# start.time <- Sys.time()
for (year in years) {
  
  narr <- data.table()
  for (month in months) {
    
    csv.dir <- paste(sep = "", base.dir, year, '/', month)
    csv.list <- list.files(csv.dir, pattern = "*.csv", full.names = T)
    cat("Reading ", csv.list, '\n')
    csv <- fread(csv.list)
    setkey(csv, Unique.ID)
    
    narr <- rbindlist(list(narr, csv))
  }
  setkey(narr, Unique.ID)
  cat("Combining the Elevation data\n")
  narr <- narr[unique(elev), on = c("Unique.ID"), nomatch=0]
  cat("Converting the ", year, "to Dataframe\n")
  narr <- as.data.frame(narr)
  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  
  csv.out.name <- paste(sep="", csv.out.dir, year, ".csv")
  cat("Writint out the data for ", "YYYY:", year, '\n')
  fwrite(narr, csv.out.name, quote = FALSE)
  Sys.sleep(5)
  remove(narr)
  gc()
}



#############################################################################
#Calculate Long and Lat for X & Y coordinates for the original 10103 points
#In the second section I dropped 40% of points per radar station randomly
#############################################################################
library(data.table)
library(terra)

# ebird <- rast("/Volumes/forecast_predictors/ebird_raster/ebird_raster_template.tif")
og_points <- fread("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/6_Stations_rand_points_75.csv")
longlat <- matrix(c(og_points$X, og_points$Y), nrow = nrow(og_points))
og_vect <- vect(longlat, crs = "+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs")
og_proj <- project(og_vect, "+proj=longlat +datum=WGS84")
points <- as.data.table(geom(og_proj, df=T)[, c("geom","x", "y")])
points <- setnames(points, old = c("geom", "x", "y"), 
                   new = c("Unique.ID", "X.Lon", "Y.Lat"),
                   skip_absent=TRUE)
og_points <- og_points[unique(points), on = c("Unique.ID"), nomatch=0]
og_points <- setcolorder(og_points, neworder = c("Unique.ID", "Radar Stations",
                                                 "X", "Y", "X.Lon", "Y.Lat"))
fwrite(og_points,"/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/7_Stations_rand_points_LatLong.csv",
       quote = F)

#Second section:
og_points <- fread("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/7_Stations_rand_points_LatLong.csv")

og_points <- setnames(og_points, old = c("Radar Stations"),
                      new = c("Radar.Stations"),
                      skip_absent=TRUE)

og_points2 <- og_points[, .SD[sample(.N, size = round(.N*0.6,0))], by=Radar.Stations]
setkey(og_points2, Radar.Stations,Unique.ID)
og_points2 <- setcolorder(og_points2, neworder = c("Unique.ID", "Radar.Stations",
                                                   "X", "Y", "X.Lon", "Y.Lat"))


fwrite(og_points2,"/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/8_Stations_LatLong_reducedBy40%.csv",
       quote = F)


#############################################################################
#COMMENT HERE!
#############################################################################
library(lubridate)
library(maptools)
library(data.table)

og_points <- fread("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/7_Stations_rand_points_LatLong.csv")
setnames(og_points, "Radar Stations", "Radar.Stations")
# og_points <- fread("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/8_Stations_LatLong_reducedBy40%.csv")
og_points <- subset(og_points, select = c(Unique.ID, Radar.Stations, X, Y, X.Lon, Y.Lat))
# og_points2 <- subset(og_points, select = Unique.ID)

atm.dir <- "/Volumes/forecast_predictors/extracted_points/8_Atmospheric_annual/"
radar.dir <- "/Volumes/forecast_predictors/extracted_points/6_Radar_Terrestrial_combined/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/9_Radar_Atm_combined_Annual/"

years <- list.files(radar.dir)

for (year in years) {
  
  atm.csv.dir <- paste(sep = "", atm.dir, year)
  atm.csv.list <- list.files(atm.csv.dir, pattern = "*.csv", full.names = T)
  print(atm.csv.list)
  atm <- fread(atm.csv.list)
  
  radar.csv.dir <- paste(sep = "", radar.dir, year)
  radar.csv.list <- list.files(radar.csv.dir, pattern = "*.csv", full.names = T)
  print(radar.csv.list)
  radar <- fread(radar.csv.list)
  
  #Trimming columns for atmospheric data
  atm.drop.cols <- grep(pattern = "(.*)_75?|(.*)75_hPa|(.*)25_hPa",
                    colnames(atm), value = T)
  cat("Trimming the columns for", year, "atmospheric data\n")
  atm <- atm[, (atm.drop.cols) := NULL]
  atm <- as.data.table(atm)

  #Trimming columns for terrestrial data
  radar <- subset(radar, select = -c(Year, Month, Day))
  radar.drop.cols <- grep(pattern = "(.*)_75?|LC(.*)150E|LC(.*)150W|(.*)EVI_150E|(.*)EVI_150W",
                            colnames(radar), value = T)
  cat("Trimming the columns for", year, "radar/terrestrial data\n")
  radar <- radar[, (radar.drop.cols) := NULL]
  radar <- as.data.table(radar)
  setkey(radar, Unique.ID)


  #Add different landcovers and merge
  cat("Calculate the Forest, Shrubland, Savanna, and Cropland covers for", year, "data\n")
  radar$Type.Forest <- round(radar$LC.Type1 + radar$LC.Type2 + radar$LC.Type3 + radar$LC.Type4 + radar$LC.Type5,
                        digits = 2)
  radar$Type.Shrubland <- round(radar$LC.Type6 + radar$LC.Type7, digits = 2)
  radar$Type.Savanna <- round(radar$LC.Type8 + radar$LC.Type9)
  radar$Type.Cropland <- round(radar$LC.Type12 + radar$LC.Type14)
  radar <- subset(radar, select = -c(LC.Type1, LC.Type2, LC.Type3, LC.Type4,
                                     LC.Type5, LC.Type6, LC.Type7, LC.Type8,
                                     LC.Type9, LC.Type12, LC.Type14))
  #Add landcovers for 150 km North
  cat("Calculate the same cover types for 150 km North of focal cells for", year, "data\n")
  radar$Type.Forest_150N <- round(radar$LC.Type1_150N + radar$LC.Type2_150N + 
                                    radar$LC.Type3_150N + radar$LC.Type4_150N + 
                                    radar$LC.Type5_150N,
                             digits = 2)
  radar$Type.Shrubland_150N <- round(radar$LC.Type6_150N + radar$LC.Type7_150N, digits = 2)
  radar$Type.Savanna_150N <- round(radar$LC.Type8_150N + radar$LC.Type9_150N)
  radar$Type.Cropland_150N <- round(radar$LC.Type12_150N + radar$LC.Type14_150N)

  #Add landcovers for 150 km South
  cat("Calculate the same cover types for 150 km South of focal cells for", year, "data\n")
  radar$Type.Forest_150S <- round(radar$LC.Type1_150S + radar$LC.Type2_150S + 
                                    radar$LC.Type3_150S + radar$LC.Type4_150S + 
                                    radar$LC.Type5_150S,
                                  digits = 2)
  radar$Type.Shrubland_150S <- round(radar$LC.Type6_150S + radar$LC.Type7_150S, digits = 2)
  radar$Type.Savanna_150S <- round(radar$LC.Type8_150S + radar$LC.Type9_150S)
  radar$Type.Cropland_150S <- round(radar$LC.Type12_150S + radar$LC.Type14_150S)

  radar2.drop.cols <- grep(pattern = "(.*)Type1_|(.*)Type2_|(.*)Type3_|(.*)Type4_|(.*)Type5_|(.*)Type6_|(.*)Type7_|(.*)Type8_|(.*)Type9_|(.*)Type12_|(.*)Type14_",
                          colnames(radar), value = T)
  cat("Drop unnecessary land cover types for", year, "data\n")
  radar <- radar[, (radar2.drop.cols) := NULL]
  radar <- as.data.table(radar)
  gc()

  # cat("Drop 40% of locations randomly for", year, "radar data\n")
  radar <- radar[unique(og_points), on = c("Unique.ID", "Radar.Stations", "X", "Y"), nomatch=0]
  # cat("Drop the same 40% of locations randomly for", year, "atmospheric data\n")
  # atm <- atm[unique(og_points2), on = "Unique.ID", nomatch=0]

  cat("Create a POSIXct Date-type column for", year, "radar data\n")
  radar$Date <- as.POSIXct(paste0(as.character(radar$Radar.Year),"-",
                               sprintf("%02d", radar$Radar.Month), "-",
                               sprintf("%02d", radar$Radar.Day)), tz = "UTC")
  radar <- subset(radar, select = -Date_Time)
  
  cat("Create a POSIXct Date/Time-type column for", year, "radar data\n")  
  radar$Radar.Time <- as.POSIXct(paste0(as.character(radar$Radar.Year),"-",
                                     sprintf("%02d", radar$Radar.Month), "-",
                                     sprintf("%02d", radar$Radar.Day), " ",
                                     sprintf("%02d", radar$Radar.Hour), ":",
                                     sprintf("%02d", radar$Radar.Minute), ":",
                                     sprintf("%02d", radar$Radar.Second)), tz = "UTC")


  cat("Create a matrix of Long & Lat\n")
  longlat <- matrix(c(radar$X.Lon, radar$Y.Lat),
                  nrow = nrow(radar))
  
  cat("Calculate the sunset time for", year, "radar/terrestrial data\n")
  radar$Sunset <- sunriset(longlat, radar$Date-86400, direction = "sunset",
                        POSIXct.out =T)[,2]

  cat("Calculate the time difference after sunset for", year, "\n")
  radar$TimeAfterSunset.Hour <- radar[, as.character(round(difftime(Radar.Time, Sunset, tz = "UTC", units = "hours"), 1))]
  radar$TimeAfterSunset.Hour <- as.numeric(radar$TimeAfterSunset.Hour)

  cat("Convert the date to the Julian style for", year, "\n")
  radar$Julian.Date <- radar[, format(radar$Date, "%j")]
  radar$Julian.Date <- as.numeric(radar$Julian.Date)
  # if (year == 2012 | year == 2016 | year == 2020){
  #   radar$Julian.Date <- dt$Julian - 1
  #   cat("Julian date fixed for the bissextile/leap years (i.e., 2012,2016,2020)\n")
  # }

  remove(longlat)
  gc()

  cat("Convert atmospheric UTC to an actual time style for", year, "\n")
  atm$UTC <- paste(sep="", sprintf("%02d", atm$UTC*3), ":00:00")

  cat("Create a new column, called UTM_interval (incorrectly) for", year, "atmospheric data\n")
  atm$UTM_interval = ymd_hms(paste(sep="", atm$Date, atm$UTC))
  setkey(atm, Unique.ID, UTM_interval)



  radar$UTM_interval <- ymd_hms(radar$UTM_interval)
  setkey(radar, Unique.ID, UTM_interval)

  cat("Combine Radar and atmospheric data for", year, "\n")
  radar <- atm[radar, on = .(Unique.ID ,UTM_interval) , roll = "nearest", nomatch=0]
  radar <- subset(radar, select = -c(Date, UTC))
  setnames(radar, old = c("i.Date", "UTM_interval"), 
           new = c("Date", "UTC_interval"), skip_absent=TRUE)
  setcolorder(radar, neworder = c("Unique.ID", "Radar.Stations", "X", "Y",
                                  "X.Lon", "Y.Lat", "Date", "Radar.Time"))
  
  cat("Number of rows for", year, ":", nrow(radar), "\n")

  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  
  csv.out.name <- paste(sep="", csv.out.dir, year, ".rds")
  cat("Writint out the data for ", "YYYY:", year, 'in RDS format\n')
  saveRDS(radar, csv.out.name)

}




#############################################################################
#Create a final training set -- this one failed!
#############################################################################
library(data.table)

# main.dir <- "/Volumes/forecast_predictors/extracted_points/9_Radar_Atm_combined_Annual/"
# dest.dir <- "/Volumes/forecast_predictors/extracted_points/10_trainingSet/"
# 
# years <- list.files(main.dir)
# trainSet <- data.table()
# start <- Sys.time()
# for (year in years) {
#   
#   rds.path <- paste(sep = "", main.dir, year)
#   rds.list <- list.files(rds.path, pattern = "*.rds", full.names = T)
#   cat("**Reading: ", rds.list, "**\n")
#   rds <- readRDS(rds.list)
#   cat("Combining the", year, "data with the training set\n")
#   trainSet <- rbindlist(list(trainSet, rds))
#   Sys.sleep(10)
#   remove(rds)
#   gc()
#   
# }
# 
# cat("Converting to a data table")
# trainSet <- as.data.table(trainSet)
# rds.out.name <- paste(sep = "", dest.dir, "trainingSet.rds")
# cat("** Writing out:", rds.out.name, "**\n")
# saveRDS(trainSet, rds.out.name)
# end <- Sys.time()
# end-start

main.dir <- "/Volumes/forecast_predictors/extracted_points/9_Radar_Atm_combined_Annual/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/10_trainingSet/"

years <- list.files(main.dir)
# trainSet <- data.table()
rds.out.name <- paste(sep = "", dest.dir, "trainingSet.csv")
start <- Sys.time()
for (year in years) {
  
  rds.path <- paste(sep = "", main.dir, year)
  rds.list <- list.files(rds.path, pattern = "*.rds", full.names = T)
  cat("**Reading: ", rds.list, "**\n")
  rds <- readRDS(rds.list)
  # cat("Combining the", year, "data with the training set\n")
  # trainSet <- rbindlist(list(trainSet, rds))
  fwrite(rds, rds.out.name, append = T, quote = F)
  Sys.sleep(10)
  remove(rds)
  gc()
  
}
end <- Sys.time()
end-start


# cat("Converting to a data table")
# trainSet <- as.data.table(trainSet)
# rds.out.name <- paste(sep = "", dest.dir, "trainingSet.rds")
# cat("** Writing out:", rds.out.name, "**\n")
# saveRDS(trainSet, rds.out.name)

#############################################################################
#Create a proof-of-concept forecast for the Wilson conference:
#Extract 14 radars, and measure the distance of each point to radar
#############################################################################
library(data.table)
library(sp)
library(raster)

og_points <- fread("/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/7_Stations_rand_points_LatLong.csv")
sub.radars <- fread("/Volumes/forecast_predictors/Radar_stations_rasters/4_Mikko_region/radsites.csv")
setnames(og_points, "Radar Stations", "Radar.Stations")
setnames(sub.radars, old = "site", "Radar.Stations")

#Extract points associated with these 14 radar stations
wilson.points <- og_points[Radar.Stations == "KSGF" | Radar.Stations == "KSRX"|
                             Radar.Stations == "KNQA"|Radar.Stations == "KOHX"|
                             Radar.Stations == "KHPX"|Radar.Stations == "KHTX"|
                             Radar.Stations == "KILX"|Radar.Stations == "KIND"|
                             Radar.Stations == "KPAH"|Radar.Stations == "KLSX"|
                             Radar.Stations == "KLVX"|Radar.Stations == "KLZK"|
                             Radar.Stations == "KEAX"|Radar.Stations == "KVWX"]
wilson.points <- subset(wilson.points, select = c("Unique.ID", "Radar.Stations",
                                                  "X", "Y", "X.Lon", "Y.Lat"))

setkey(wilson.points, Unique.ID, Radar.Stations)

#Change the projection of those radars from Long/Lat to X/Y coordinates
coordinates(sub.radars) <- ~lon + lat
proj4string(sub.radars) <- CRS("+proj=longlat +datum=WGS84")
proj.sub.radar <- spTransform(sub.radars, 
                 CRS("+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs"))
proj.sub.radar <- coordinates(proj.sub.radar)
colnames(proj.sub.radar) <- c('X', 'Y')
proj.sub.radar <- as.data.table(proj.sub.radar)
sub.radars <- as.data.table(sub.radars)
sub.radars <- cbind(sub.radars, proj.sub.radar)
setnames(sub.radars, old = c("lon", "lat", "X", "Y"), 
         new = c("Radar.Lon", "Radar.Lat", "Radar.X", "Radar.Y"))
remove(proj.sub.radar)

#Combine the two dataframes
wilson.points <- wilson.points[unique(sub.radars), on = c("Radar.Stations"), nomatch=0]
setkey(wilson.points, Unique.ID, Radar.Stations)

#Calculate the distance from radar for each point
wilson.points$Distance.Radar.km <- wilson.points[, round(sqrt((wilson.points$Radar.X - wilson.points$X)^2 + 
                                                                (wilson.points$Radar.Y - wilson.points$Y)^2)/1000, 1)]
#Save the final dataframe
filename <- "/Volumes/forecast_predictors/Radar_stations_rasters/3_csv_files/9_Wilson_points.csv"
fwrite(wilson.points, filename, quote = F)

#Load combined data per year, extract the points for these 14 radar stations,
#and drop the radar data except for 2-4 hours after sunset

main.dir <- "/Volumes/forecast_predictors/extracted_points/9_Radar_Atm_combined_Annual/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/10_Wilson_results/01_wilson_annual/"

years <- list.files(main.dir)
wilson <- subset(wilson.points, select = c("Unique.ID", "Radar.Stations", "Distance.Radar.km"))

for (year in 2013:2021) {
  
  radar.path <- paste(sep = "", main.dir, year, '/')
  radar.rds <- list.files(radar.path, full.names = T)
  print(radar.rds)
  radar <- readRDS(radar.rds)
  
  cat("Extract the points of 14 radars for", year, "data\n")
  radar <- radar[unique(wilson), on = c("Unique.ID", "Radar.Stations"), nomatch=0]
  
  cat("Only keep the radar data for 2-4 hours after sunset\n")
  radar <- radar[TimeAfterSunset.Hour >= 2]
  radar <- radar[TimeAfterSunset.Hour <= 4]
  
  gc()
  
  csv.out.dir <- paste(sep = "", dest.dir, year, '/')
  ifelse(!dir.exists(file.path(csv.out.dir)), 
         dir.create(file.path(csv.out.dir), recursive=T), FALSE)
  
  csv.out.name <- paste(sep="", csv.out.dir, year, ".rds")
  cat("Writint out the data for ", "YYYY:", year, 'in RDS format\n')
  saveRDS(radar, csv.out.name)
}





# View(radar[Unique.ID == 2326, c(1:4, 184)])
# sort(unique(radar$TimeAfterSunset.Hour))

main.dir <- "/Volumes/forecast_predictors/extracted_points/10_Wilson_results/01_wilson_annual/"
dest.dir <- "/Volumes/forecast_predictors/extracted_points/10_Wilson_results/02_wilson_allData/"

years <- list.files(main.dir)

all.data <- data.table()

for (year in years) {
  
  radar.path <- paste(sep = "", main.dir, year, '/')
  radar.rds <- list.files(radar.path, full.names = T)
  print(radar.rds)
  radar <- readRDS(radar.rds)
  
  cat("Combine", year, "data with all data\n")
  all.data <- rbindlist(list(all.data, radar))
  Sys.sleep(10)
  
  remove(radar)
  gc()
}

all.data <- as.data.table(all.data)
filename <- paste(sep = "", dest.dir, "all_data.rds")
cat("Writing out the final file\n")
saveRDS(all.data, filename)







