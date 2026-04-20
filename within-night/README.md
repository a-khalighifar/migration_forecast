# Within-night variation in predictor importance highlights dynamic nature of bird migration

This repository accompanies the research presented in Jimenez et al. (2026). I contains the scripts and codebase for downloading/processing data, and training and deploying gradient boosted trees that analyze the associations between bird migration intensity and predictor variables. 

## Summary of scripts
The 'download_processing' subfolder contains:
- **EVI_full_processing.R:**
- **NEXRAD_forecast_download.R:**
- **landcover_full_processing.R:**
- **pointExtraction_full_processing.R:**
- **viirs_full_processing.R:**

The 'model_training' subfolder contains:
- **1_Sample20_makeFullData.R:**
- **2_Training_seasonal_model.R:**
- **3_Extract_feat-Importance.R:**
- **4_PartialDependencePlots_loop.R**
- **5_PartialDependencePlots_avg.R**
- **6_PartialDependencePlots_plot.R**

## Input data requirements for model_training

To use the scripts in this repository, you will need the data stored on FigShare [https://figshare.com/articles/dataset/Within-night_training_data/28755569]. Due to the large size of the input datasets (hundreds of GB), we have only included a subset of the data for the year 2012. However, the download_processing scripts can be used to download and process the additional years of data used in our study (2012-2022). 

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
