# SNAP and Household Nutrition (FoodAPS)

## Author
Baimat Niiazaliev — Advanced Econometrics, May 2026

---

## Overview
This project estimates the causal effect of SNAP (Supplemental Nutrition
Assistance Program) participation on household calorie intake using the
USDA FoodAPS Public Use File. The primary outcome is **winsorised
calories per capita**. Five estimators are compared: OLS, nearest-neighbour
matching (NN), propensity score matching (PSM), inverse probability
weighting (IPW), and doubly-robust IPW regression adjustment (IPWRA).

---

## Project Structure
```
project/
├── code/
│   └── coding.do          # Full reproducible pipeline
├── data/
│   ├── raw/               # Raw FoodAPS files (NOT included — see Data section)
│   └── clean/             # Intermediate and analytic datasets
├── output/
│   ├── figures/           # PNG graphs (5 figures)
│   ├── tables/            # RTF regression tables
│   └── logs/              # Stata log files
├── docs/
│   ├── writeup.tex        # LaTeX source
│   └── writeup.pdf        # Compiled write-up
└── README.md
```

---

## Data
- **Source:** [USDA FoodAPS Public Use File](https://www.ers.usda.gov/data-products/foodaps-national-household-food-acquisition-and-purchase-survey/)
- Raw data is **not included** in this repository due to size and licensing restrictions
- Place the following files in `data/raw/` before running:
  - `faps_household_puf.dta`
  - `faps_fafhnutrient_PUF.dta`
- Cleaned dataset (`analysis_dataset.dta`) is generated automatically by the pipeline

---

## Methods
| Estimator | Description |
|-----------|-------------|
| OLS | Linear regression with full controls and robust SE |
| NN Matching | 1:1 Mahalanobis nearest-neighbour matching (ATT) |
| PSM | 1:1 propensity score matching via logit (ATT) |
| IPW | Inverse probability weighting (ATT) |
| **IPWRA** | **Doubly-robust IPW regression adjustment (preferred)** |

Robustness checks include: trimming to common support, caliper matching
(0.20 × SD of propensity score), and PSM excluding near-degenerate covariates.
Outcomes are winsorised at the 1st–99th percentile.

---

## How to Reproduce
1. Download FoodAPS raw data and place in `data/raw/`
2. Open Stata 14 or later
3. Run:
```stata
do code/coding.do
```
The script automatically creates all subfolders, saves a timestamped log
file, and writes all figures and tables to `output/`.

**Required packages** (installed automatically by the script):
- `winsor2` — `ssc install winsor2`
- `coefplot` — `ssc install coefplot`

---

## Key Findings
- **Naive OLS** (no controls): +260 kcal, marginally significant — driven
  by household size confounding, not a programme effect
- **OLS with full controls**: −1.84 kcal/person, statistically insignificant
- **NN and PSM**: insignificant, estimates range from −0.21 to +3.35 kcal
- **IPW**: +4.28 kcal/person (p = 0.038)
- **IPWRA (doubly-robust, preferred)**: −3.82 kcal/person (p = 0.016,
  95% CI: [−6.94, −0.70])

The sign divergence between IPW and IPWRA reveals **model dependence**:
results are sensitive to whether the outcome regression is included in the
estimator. IPWRA is preferred because it is consistent if either the
propensity score model or the outcome regression model is correctly
specified — not necessarily both. The preferred estimate suggests SNAP
*maintains* rather than increases per-capita calorie adequacy, with an
effect size of roughly 5% of the counterfactual mean.

---

## Outputs Generated
| File | Description |
|------|-------------|
| `output/figures/fig1_pscore_histogram.png` | Propensity score distribution |
| `output/figures/fig2_pscore_overlap.png` | Overlap (kernel density) |
| `output/figures/fig3_coefplot.png` | ATT estimates across all 5 estimators |
| `output/figures/fig4_pscore_trimmed.png` | Overlap after trimming |
| `output/figures/fig5_psm_robustness.png` | PSM robustness checks |
| `output/tables/table_primary.rtf` | Main table: calories per capita |
| `output/tables/table_secondary.rtf` | Secondary: total calories |
| `output/tables/table2_psm_robustness.rtf` | PSM robustness table |
| `output/logs/coding_DDMMMYYYY.log` | Full Stata log |

---

## AI Use Statement
Claude (Anthropic) was used for assistance with Stata pipeline structure,
debugging, and LaTeX formatting. All analytical decisions, variable
construction, identification strategy, and interpretation of results
are the author's own.
