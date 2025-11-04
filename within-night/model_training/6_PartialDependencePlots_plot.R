source("setup.R")

# choose season and predictor
pdp_avg_summary <- readRDS("data/08_pdp/10-12/spring_pdp_summary_avg.rds")
predictor <- "Ordinal.Date"

# if you need to see list of predictors
#unique(pdp_avg_summary$variable)

# filter for chosen predictor
pdp_filtered <- as.data.frame(pdp_avg_summary)
pdp_filtered <- pdp_filtered[pdp_filtered$variable == predictor, ]

# plot with ribbon + smoothed line
ggplot(pdp_filtered, aes(x = xval, y = yhat_mean)) +
  geom_ribbon(aes(ymin = yhat_lo, ymax = yhat_hi), fill = "grey", alpha = 0.5) +
  geom_smooth(
    aes(y = yhat_mean),
    method = "loess", se = FALSE, span = 0.3,
    color = "black", size = 1
  ) +
  labs(
    x = predictor,
    y = "predicted migration traffic"
  ) +
  theme_classic()

