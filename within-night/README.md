# Weather surveillance radar as a tool for studying the dynamic drivers of migratory bird transitions between terrestrial and aerial habitats

This repository accompanies the research presented in the Jimenez et al. paper. This repository contains the scripts and codebase for downloading/processing data, and training and deploying gradient boosted trees that analyze the associations between bird migration intensity and predictor variables. By integrating radar (NEXRAD) data with weather and terrestrial factors within 2-hour segments, we are able to assess changes in these associations within a single migration night, as birds transition between terrestrial and atmospheric habitat. 

## Input data requirements for model_training

To use the scripts in this repository, you will need the data stored in [link]. Due to the large size of the input datasets (hundreds of GB), we have only included a subset of the data for the year 2012. However, the download_processing scripts can be used to download and process the additional years of data used in our study (2012-2022). 

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
