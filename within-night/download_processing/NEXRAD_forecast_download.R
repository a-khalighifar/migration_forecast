library(aws.s3)
library(data.table)
library(maptools)
library(stringr)

setwd("/Volumes/forecast4/raw_data") #edited to the USB drive
meta=read.csv("/Volumes/forecast4/meta_data/nexrad_site_list_with_utm.csv")
meta=subset(meta, SITE!="JAN")
meta=subset(meta, LONGITUDE_W>(-130) & LONGITUDE_W<(-65))
meta=subset(meta, LATITUDE_N>(20) & LATITUDE_N<(50))
meta=meta[73:74,]
#####################
#set these things

directory="/Volumes/forecast4/raw_data" # this will be the directory your data will download to. Change as needed

##SET STATION ID - four letter character string
#STATION <- "KMTX" # this is Salt Lake radar
STATION <- meta$SITE

#STATION <- "all"

year=2008:2018

#Range of dates (change only day line 21 and the first month variable line 22)
days=str_pad(1:31, 2, pad = "0")

month=str_pad(c(3,4,5,6,7,8,9,10,11), 2, pad = "0") # change to whatever range of months you might need

month=rep(month, each=length(days))

##Start and end hours of interest for each day (must be same for all days) as integer 0-23
startHOUR <-0
endHOUR <- 23

#range of samples after sunset. This might be of interest, however it's largely coded for nocturnal filtering. 
#I think you could easily invert the filter (line 115) to sample only diurnal. Currently this filter is turned off, 
#so all data between startHOUR and endHOUR will be downloaded. Remember, times are in UTC. 
#**Line 92 restricts the samples to one per hour, rather than every 5-10 mintues. 
#sun_range1=0.25
#sun_range2=0.75
##############################################################################

radars=paste("K", meta$SITE, sep="")
for (r in radars){
print(r)

meta_station=subset(meta, SITE==substr(r, 2,4))

for(y in year){
  print(y)

  DATES=paste(y, month,days, sep="")
  DATES=DATES[1:262]
  dates.year <- substring(DATES, 1, 4)
  dates.month <- substring(DATES, 5, 6)
  dates.day <- substring(DATES, 7,9)

AWSbucket = "https://noaa-nexrad-level2.s3.amazonaws.com/"

location <- paste0(dates.year, "/", dates.month, "/", dates.day, "/", r, "/")

#########################################################
substrRight <- function(x, n){
  substr(x, nchar(x)-n+1, nchar(x))
}

#collects all the file names and links for the date range
all <- as.list(rep(NA, 1200))
for (n in 1:length(location)){
  print(location[n])
  day_files=get_bucket(bucket = "noaa-nexrad-level2", location[n])
  data_all <- data.frame()
  for (l in 1: length(day_files)){
    data_all=rbind(cbind(Key=day_files[l]$Contents$Key, Size=day_files[l]$Contents$Size),data_all)
  }
  all[[n]] <- data_all
}

all=all[1:n]
library(data.table)
all=rbindlist(all)

if (nrow(all)==0){
  next
}else{
#this removes non-files
all=subset(all, Size != 65)
all=subset(all, Size != 33)
all=subset(all, Size != 0)

#post2016
#all=subset(all, nchar(as.character(all$Key))==39)
#pre2016
#all=subset(all, nchar(as.character(all$Key))==42)

#this subsets based on the time of interest 
all=subset(all, as.numeric(substr(all$Key, 30,31))>= startHOUR & as.numeric(substr(all$Key, 30,31))<=endHOUR)

all$date=substr(all$Key,21,31)
all$md_removal=substrRight(all$Key, 3)
all=subset(all, md_removal!="MDM")

#all$Key=as.character(all$Key)
#all$Key=ifelse(str_sub(all$Key,-2,-1)!="gz", paste(all$Key, ".gz", sep=""), all$Key)


#########################################################  

#long and lat for twilight calculation
longlat <- matrix(c(meta_station$LONGITUDE_W, meta_station$LATITUDE_N), nrow=1)

#dates for twilight calculation 
date_data=as.POSIXct(substr(all$Key, 1,10),  tz="UTC")

## Civil Twilight
all$sunset=crepuscule(longlat, date_data-86400, solarDep=0, direction="dusk", POSIXct.out=TRUE)[,2]
all$sunrise=crepuscule(longlat, date_data, solarDep=0, direction="dawn", POSIXct.out=TRUE)[,2]

all$filetime=as.POSIXct(paste(date_data,substr(all$Key, 30,35)), format="%Y-%m-%d %H%M%S", tz="UTC")

#Calculate Difference
all$sun_diff_sunset=difftime(as.POSIXct(paste(date_data,substr(all$Key, 30,35)), format="%Y-%m-%d %H%M%S", tz="UTC"),
                      as.POSIXct(all$sunset, format="%Y-%m-%d %H%M%S", tz="UTC"), units=c("hours"))

all$sun_diff_sunrise=difftime(as.POSIXct(all$sunrise, format="%Y-%m-%d %H%M%S", tz="UTC"), 
                     as.POSIXct(paste(date_data,substr(all$Key, 30,35)), format="%Y-%m-%d %H%M%S", tz="UTC"),units=c("hours"))

all=subset(all, sun_diff_sunset>= 0 & sun_diff_sunrise>=0)

library(plyr)

all$round_30= round_any(as.numeric(all$sun_diff_sunset),0.5,f = floor)
all = all[order(all$filetime),] 
all$sampling_event=as.Date(substr(all$date, 1,8),format="%Y%m%d")
library(dplyr)
all$sampling_event=if_else(as.numeric(substr(all$date,10,11))>=0 & as.numeric(substr(all$date,10,11))<=22 ,
                          all$sampling_event - 1, all$sampling_event)
all=all %>%
  group_by(sampling_event, round_30) %>%
  filter(row_number()==1)

toDWNLD <- all$Key
DWNLDURLS <- c(t(outer(AWSbucket, toDWNLD, paste0)))
################################
#creates directory for saving data
dir.exists <- function(d) {
  de <- file.info(d)$isdir
  ifelse(is.na(de), FALSE, de)
}
saveLoc=paste0(directory, "/", r, "/")

if (dir.exists(saveLoc)==T){
  "directory exists"
} else{
  dir.create(file.path(paste0(saveLoc)))
} 
################################

saveFile=substr(toDWNLD, 17, 42)
dub <- (saveFile  %in% list.files(saveLoc))
saveFile = saveFile[!dub]

saveFile=paste0(saveLoc, saveFile)
toDWNLD =toDWNLD[!dub]

#the actual downloading function
lapply(1:length(DWNLDURLS), function (i){
  tryCatch({download.file(DWNLDURLS[i], destfile = saveFile[i], quiet = T)}, silent = T, condition = function(err) { })
})
}
}
}
