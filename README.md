# SNAP and Household Nutrition (FoodAPS)

## Author
Baimat Niiazaliev

## Overview
This project analyzes the impact of SNAP (Supplemental Nutrition Assistance Program) participation on household nutrition using FoodAPS data.

The goal is to estimate whether SNAP participation affects calorie intake and other nutritional outcomes.

---

## Project Structure

├── code/ # Stata do-file
├── data/
│ ├── raw/ # (not included in repo)
│ └── clean/ # cleaned dataset used for analysis
├── output/
│ ├── figures/ # graphs
│ ├── tables/ # regression tables
│ └── logs/ # log files
│
├── README.md


---

## Data

- Data source: FoodAPS (USDA)
- Raw data is **not included** due to size restrictions
- Clean dataset is included in `data/clean/`

---

## Methods

The analysis uses several econometric approaches:

- Ordinary Least Squares (OLS)
- Nearest Neighbor Matching (NN)
- Propensity Score Matching (PSM)
- Inverse Probability Weighting (IPW)

---

## How to Run

1. Download FoodAPS raw data and place in:
   data/raw/


2. Open Stata

3. Run:
do code/coding.do

---

## Outputs

The script generates:

- Regression tables (RTF format)
- Figures (PNG)
- Log files

All outputs are stored in the `output/` folder.

---

## Key Findings

- Naive OLS suggests a positive relationship between SNAP and calorie intake
- After controlling for covariates, the effect becomes insignificant
- Matching and IPW estimates show no statistically significant effect

This suggests that the OLS estimate is biased due to selection.

---

## Reproducibility

The project is fully reproducible:
- Uses relative paths
- Automatically generates outputs
- Organized folder structure

---

## Notes

This project was completed as part of an Advanced Econometrics course.
