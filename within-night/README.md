High-Resolution Nightly Bird Migration Forecasts Using Radar (NEXRAD), Weather, and Terrestrial Data

This repository accompanies the research presented in the Jimenez & Khalighifar, et al. paper. This repository contains the scripts and codebase for training and deploying an ensemble of 25 models to predict bird migration patterns across the U.S. at high spatial and temporal resolution. By integrating radar (NEXRAD) data with weather and terrestrial factors, these models enable real-time, detailed forecasts of bird migration activity. The goal is to aid in tracking migratory behavior and advancing conservation efforts for migratory birds. Perfect for anyone interested in understanding and protecting migratory birds.
Input data requirements

To use the scripts in this repository, you will need the following input data:

    Training Data Located in the trainingData folder. This contains variables spanning 10 years, split into 25 smaller datasets.
    Forecasting Data A dataset combining weather and terrestrial factors, stored in the NAM-Land_Combined folder. This is used to forecast bird migration for selected nights in the study.
    eBird Raster Template A raster template required for data alignment and modeling.

Note: Due to the large size of the input datasets (hundreds of GB), these files are not included in the repository. Kyle Horton at Colorado State University (kyle.horton@colostate.edu) is the point of contact and is responsible for providing access to these data upon request.
