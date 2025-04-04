library(data.table)

# start = Sys.time()
# set.seed(123)
data.dir <- '/Volumes/Mikko2/withinnight_test/data/02_Radar_Atm_combined_Annual/'
og_points <- fread('/Volumes/Mikko2/withinnight_test/data/01_cell-coordinates/1_all-trainingPoints-fromStations.csv')
og_points <- og_points[,1:4]
setnames(og_points, old = 'Radar Stations', new = 'Radar.Stations')

# need to change these when running new time step 
smpl.dest.dir <- '/Volumes/Mikko2/withinnight_test/data/03_randomSamplingPoints/test/'
dest.dir <- '/Volumes/Mikko2/withinnight_test/data/04_trainingData/test/'

years <- list.files(data.dir)
start = Sys.time()
for (turn in 1:10) {
  cat('========== Round', turn, '==========\n')
  random.20p <- og_points[, .SD[sample(.N, size = round(.N*0.2,0))], by=Radar.Stations]
  setkey(random.20p, Unique.ID)
  fwrite(random.20p, paste0(smpl.dest.dir, turn, '_randomSample20.csv'),
         quote = F)


  all.10y.data <- data.table()
  
  for (year in years) {
    cat('Year:', year, '\n')
    data.path <- list.files(paste0(data.dir, year), pattern = '.rds',
                            full.names = T)
    cat('Directory:\n', data.path, '\n')
    dt.year <- readRDS(data.path)
    #Only selecting data for 0-2 hours after the local sunset - NEED TO CHANGE FOR EACH TIMESTEP
    dt.year <- dt.year[TimeAfterSunset.Hour>=0 & TimeAfterSunset.Hour<=2]
    #Deleting all zero values for our response variable
    dt.year <- dt.year[Radar.value>0]
    #Merging the 20% data
    dt.year <- dt.year[unique(random.20p), on = c("Unique.ID"), nomatch=0]
    #The above line adds three new columns that we don't need
    dt.year <- dt.year[,1:186]
    gc()
    all.10y.data <- rbindlist(list(all.10y.data, dt.year))
    Sys.sleep(5)
    remove(dt.year)
    gc()
  }
  
  all.10y.data <- as.data.table(all.10y.data)
  dest.path <- paste0(dest.dir, turn, '_allData.rds')
  cat('Writing the final dataset out!\n')
  saveRDS(all.10y.data, dest.path)
  # end = Sys.time()
  # cat('Process ended at:', end, '\n')
  # end-start #47 minutes for each round
}
end = Sys.time()
end-start #The whole process took 20.6 hours




