# Within-night variation in predictor importance highlights dynamic nature of bird migration

This repository accompanies the research presented in:

*Jimenez, M. F., Khalighifar, A., & Horton, K. G. (In review). Within-night variation in predictor importance highlights dynamic nature of bird migration. Ecology Letters.*

It contains the scripts and codebase for downloading/processing data, and training and deploying gradient boosted trees that analyze the associations between bird migration intensity and predictor variables. 

## Summary of scripts
The 'download_processing' subfolder contains:
- **EVI_full_processing.R:** This script processes NASA MODIS EVI (Enhanced Vegetation Index) satellite data. Specifically, it converts raw HDF files to GeoTIFF format, mosaics individual tiles into global maps, crops them to the US extent, applies quality control using QA layers, and spatially resamples the data to match an eBird reference raster.
- **NEXRAD_forecast_download.R:** This script downloads NEXRAD weather radar files for a specified set of radar stations and time range. It filters files by time of day and restricts downloads to nighttime periods between sunset and sunrise using solar twilight calculations. 
- **landcover_full_processing.R:** This script processes NASA MODIS Land Cover HDF files into analysis-ready rasters for the contiguous US. It converts raw HDF tiles to GeoTIFF format, mosaics and crops them to a US bounding polygon, then reclassifies each of the 16 land cover types into individual binary layers which are aggregated, reprojected, and resampled to match an eBird reference grid. 
- **pointExtraction_full_processing.R:** The script extracts 10,000 focal points, as well as their associated North, South, East, and West points, across 143 stations from all terrestrial variables, and sorts them based on EVI periods.
- **viirs_full_processing.R:** This script uses parallel processing to unzip each tgz file from the light pollution folder (VIIRS), and only extract the tif file that has the actual light pollution data.

The 'model_training' subfolder contains:
- **1_Sample20_makeFullData.R:** This script builds a training dataset by repeatedly sampling radar-atmospheric predictor data across multiple years. In each of 10 rounds, it randomly draws 20% of spatial grid points (stratified by radar station), then loops through annual RDS data files to extract observations within 0–2 hours after local sunset with nonzero radar values, keeping only the sampled points via a merge. The filtered data across all years is combined into a single dataset and saved per round, effectively creating 10 bootstrap-style training sets for model development.
- **2_Training_seasonal_model.R:** This script trains separate LightGBM gradient boosting models for spring and fall seasons across multiple rounds, using radar reflectivity as the response variable. Each round splits the data 70/15/15 into train, validation, and test sets, trains models with early stopping up to 1000 rounds, and records R² on the held-out test set. The resulting models and per-round performance metrics are saved to disk for later ensemble or comparison analysis.
- **3_Extract_feat-Importance.R:** This script loads the previously trained LightGBM models for each round and season, extracts feature importance (Gain) from each, and accumulates them into a single wide table by merging on feature name. After processing all rounds, it computes each feature's mean Gain across the 10 models and writes the ranked results to CSV files separately for spring and fall seasons.
- **4_PartialDependencePlots_loop.R** This script computes partial dependence plots (PDPs) for all predictor variables across each of the 10 trained spring and fall LightGBM models. For each variable, it steps through 20 quantile-based grid values, substitutes that value across a subsampled dataset, generates predictions, and summarizes the mean and standard deviation of predicted responses at each grid point. The resulting PDP summaries are saved per model and season, and can later be averaged across the 10 rounds to produce stable, ensemble-level variable response curves.
- **5_PartialDependencePlots_avg.R** This script aggregates the per-model PDP summaries from the previous step by reading in all 10 seasonal files, stacking them, and computing the median of each summary statistic (mean, SD, and confidence bounds) across models for each predictor-grid value combination. Using the median rather than the mean makes the ensemble PDP curves robust to any outlier models, and the results are saved as a single averaged PDP file for each season.

## Input data requirements for model_training

To use the scripts in this repository, you will need the data stored on FigShare [https://figshare.com/articles/dataset/Within-night_training_data/28755569]. To run sample analyses for 2012 timestep 0-2hr, download folders '01_cell-coordinates' and '02_Radar_Atm_combined_Annual' and move both into Rproject within_night data folder.  

Due to the large size of the input datasets (hundreds of GB), we have only included a subset of the data for the year 2012. However, the download_processing scripts can be used to download and process the additional years of data used in our study (2012-2022). 

We used the following folder structure for our pipeline and recommend this structure for best results:
## 📁 Data Folder Structure

All data used to train and evaluate the gradient boosted tree models are organized within the `data/` directory as follows:

```text
data/
├── 01_cell-coordinates/                   # spatial coordinates for analysis grid cells
├── 02_Radar_Atm_combined_Annual/         # annual radar and atmospheric predictor data
│   ├── 2012/
│   ├── 2013/
│   ├── 2014/
│   ├── 2015/
│   ├── 2016/
│   ├── 2017/
│   ├── 2018/
│   ├── 2019/
│   ├── 2020/
│   ├── 2021/
│   └── 2022/
├── 03_randomSamplingPoints/              # randomly sampled background/pseudo-absence data
│   ├── 2012/
│   ├── 2013/
│   ├── 2014/
│   ├── 2015/
│   ├── 2016/
│   ├── 2017/
│   ├── 2018/
│   ├── 2019/
│   ├── 2020/
│   ├── 2021/
│   └── 2022/
├── 04_trainingData/                      # processed training datasets for model input
│   ├── 2012/
│   ├── 2013/
│   ├── 2014/
│   ├── 2015/
│   ├── 2016/
│   ├── 2017/
│   ├── 2018/
│   ├── 2019/
│   ├── 2020/
│   ├── 2021/
│   └── 2022/
├── 05_savedModels/                       # trained gradient boosted tree models
│   ├── 2012/
│   ├── 2013/
│   ├── 2014/
│   ├── 2015/
│   ├── 2016/
│   ├── 2017/
│   ├── 2018/
│   ├── 2019/
│   ├── 2020/
│   ├── 2021/
│   └── 2022/
├── 06_Model_performance/                 # evaluation metrics for each model
│   ├── 2012/
│   ├── 2013/
│   ├── 2014/
│   ├── 2015/
│   ├── 2016/
│   ├── 2017/
│   ├── 2018/
│   ├── 2019/
│   ├── 2020/
│   ├── 2021/
│   └── 2022/
├── 07_FeatureImportance/                 # feature importance results per model
    ├── 2012/
    ├── 2013/
    ├── 2014/
    ├── 2015/
    ├── 2016/
    ├── 2017/
    ├── 2018/
    ├── 2019/
    ├── 2020/
    ├── 2021/
    └── 2022/
```
