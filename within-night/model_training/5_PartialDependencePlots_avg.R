library(data.table)

# function to average pdp summaries
average_pdp <- function(season, input_dir, output_file) {
  # list all pdp summary files for that season
  files <- list.files(input_dir, pattern = paste0("^", season, "_model\\d+_pdp_summary\\.rds$"), full.names = TRUE)
  
  # read them in and stack
  pdp_list <- lapply(files, readRDS)
  pdp_dt <- rbindlist(pdp_list, use.names = TRUE, fill = TRUE, idcol = "model_id")
  
  # average across models by predictor + xval
  pdp_avg <- pdp_dt[, .(
    yhat_mean = median(yhat_mean, na.rm = TRUE),
    yhat_sd   = median(yhat_sd, na.rm = TRUE),
    yhat_lo   = median(yhat_lo, na.rm = TRUE),
    yhat_hi   = median(yhat_hi, na.rm = TRUE)
  ), by = .(variable, xval)]
  
  # save averaged pdp
  saveRDS(pdp_avg, output_file)
  return(pdp_avg)
}

# paths
input_dir <- "data/08_pdp/0-2"

# run for spring and fall
spring_avg <- average_pdp("spring", input_dir, file.path(input_dir, "spring_pdp_summary_avg.rds"))
fall_avg   <- average_pdp("fall",   input_dir, file.path(input_dir, "fall_pdp_summary_avg.rds"))
