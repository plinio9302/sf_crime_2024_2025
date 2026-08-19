# SF Crime Analysis: San Francisco Incidents 2024 vs 2025

**🔗 Live dashboard:** [plinio9302.github.io/sf_crime_2024_2025](https://plinio9302.github.io/sf_crime_2024_2025/)

**Author:** Plinio Durango  
**Tool:** MySQL / SQL, Python (pandas, seaborn, sqlite3)  
**Dataset:** SFPD Incident Reports 2024 & 2025 (San Francisco Police Department Open Data)  
**Source:** [SF Open Data Portal](https://data.sfgov.org/Public-Safety/Police-Department-Incident-Reports)  

---

## Overview

This project analyzes 230,000+ police incident records from the San Francisco Police Department covering 2024 and 2025. The goal is to determine whether crime is rising or falling across the city, identify which crime types and neighborhoods drive the most activity, uncover weekly and seasonal patterns, and rank districts by relative safety. The analysis covers year-over-year volume changes, geographic breakdowns, resolution outcomes, and time-based trends using MySQL window functions, and visualizes the results in a companion Jupyter notebook.

**A data-quality catch worth calling out:** the "2025" source table is a rolling open-data export, not a clean single calendar year — it also contains ~26,400 incidents already dated in 2026. A naive `COUNT(*)` on that table makes 2025 look *larger* than 2024. Filtering to the date-derived calendar year (rather than trusting which table a row came from) reverses the conclusion: **2025 actually saw 13.8% fewer incidents than 2024.** This distinction is documented in `SF_crime_analysis.sql` (Sections 2–3) and is the reason every year-over-year query in this project filters explicitly on `incident_year`.

---

## Dataset

| Attribute | 2024 Table | 2025 Table |
|-----------|-----------|----------|
| Raw rows | 109,626 | 121,194 (94,732 dated 2025 + 26,462 dated 2026) |
| Clean rows used in YoY analysis | 109,342 | 94,280 |
| Columns | 22 | 22 |
| Unique ID | RowID + IncidentNumber | RowID + IncidentNumber |

### Key Columns

| Column | Description |
|--------|-------------|
| `IncidentDate` | Date the incident occurred |
| `IncidentTime` | Time the incident occurred |
| `IncidentCategory` | High-level crime type (e.g., Larceny Theft, Assault) |
| `IncidentDescription` | Detailed description of the incident |
| `Resolution` | Outcome: Open or Active, Cite or Arrest Adult, Exceptional Adult, Unfounded |
| `PoliceDistrict` | One of SF's 10 police districts (plus an "Out of SF" catch-all) |
| `AnalysisNeighborhood` | SF planning neighborhood (finer-grained than PoliceDistrict) |
| `Latitude / Longitude` | Geographic coordinates of the incident |

---

## Project Structure

```
sf_crime_2024_2025/
├── SF_crime_analysis.sql          # Full SQL analysis (9 sections)
├── SFcrime2024_processed.csv      # Cleaned 2024 incident data
├── SFcrime2025_processed (1).csv  # Cleaned 2025 incident data (includes 2026 spillover rows)
├── Plinio_Durango_case_study3.ipynb  # Jupyter notebook with visualizations
└── README.md                      # This file
```

---

## Methodology

### Data Cleaning

A unified cleaning view (`sfcrime_combined_clean`) was created using `UNION ALL` across both years. Rows with NULL `IncidentCategory` or `PoliceDistrict` were excluded. The view derives `incident_year`, `incident_month`, and `day_of_week` directly from `IncidentDate` — this derived year, not the source table a row came from, is what every comparison below groups and filters on.

**EDA issues identified:**
- Some rows have NULL Latitude/Longitude (location not captured at scene).
- Both tables share the same 22-column schema — safe to `UNION ALL`.
- The "2025" table's `IncidentDate` ranges from 2025-01-02 to 2026-04-25 (479 days), not a clean calendar year; 26,462 of its rows are already dated in 2026. All year-over-year figures in this project filter on `incident_year IN (2024, 2025)` to keep the comparison apples-to-apples.

---

## Analysis

### Section 5: Year-over-Year Comparison

| Year | Total Incidents (clean, true calendar year) | Change |
|------|----------------------------------------------|--------|
| 2024 | 109,342 | — |
| 2025 | 94,280 | **-13.78%** |

A side-by-side JOIN query compares each crime category individually to reveal which categories improved and which worsened between years. Largest increases: **Drug Offense +62.15%** (4,122 → 6,684) and **Warrant +23.89%** (4,534 → 5,617). Largest decreases: **Vandalism -49.38%**, **Motor Vehicle Theft -43.07%** (7,226 → 4,114), **Recovered Vehicle -42.40%**, **Burglary -26.82%**.

### Section 6: Crime Breakdowns

**6a. By Type of Crime** — Window functions compute each category's percentage share within each year. Larceny Theft remains the #1 category both years but shrank as a share of total crime (24.07% of 2024 → 21.54% of 2025), while Drug Offense grew from 3.77% to 7.09% of the year.

**6b. By Police District** — Southern district overtook Mission as the top-volume district in 2025 (14,841 vs 13,480 incidents), with Mission second and Tenderloin third (12,388).

**6c. By Resolution** — Clearance actually improved alongside the drop in volume: `Cite or Arrest Adult` rose from 23.62% of cases (2024) to 30.40% (2025), while `Open or Active` fell from 75.70% to 68.89%.

### Section 7: Time-Based Patterns

**7a. Day of Week** — Wednesday (31,120 incidents) and Friday (30,955) are the busiest days; Sunday (26,058) is the quietest.

**7b. Monthly Seasonality** — Every single month of 2025 came in below its 2024 counterpart — the decline is broad-based across the year, not driven by one outlier month. 2024 ranged roughly 8,000–9,770 incidents/month; 2025 ranged roughly 7,000–7,860/month.

### Section 8: Neighborhood Safety Ranking

Districts are ranked by two-year total incident count (fewest = safest): **1. Out of SF, 2. Park, 3. Richmond, 4. Taraval, 5. Ingleside, 6. Bayview, 7. Central, 8. Northern, 9. Tenderloin, 10. Mission, 11. Southern** (least safe by volume). A secondary window-function query identifies the top 5 crime categories per district — Tenderloin is led by Drug Offense (4,568) and Warrant (3,418), a distinct mix from Mission and Southern, which are both led by Larceny Theft.

**Safety definition caveat:** This metric measures incident volume, not severity. A high-density district may report more incidents simply due to population size, not inherently greater danger.

---

## Tools & Technologies

| Tool | Purpose |
|------|---------|
| MySQL | Core SQL analysis |
| Window Functions (`RANK`, `SUM OVER`) | YoY change, district ranking, category shares |
| `UNION ALL` | Combining 2024 and 2025 datasets |
| `CREATE OR REPLACE VIEW` | Centralized data cleaning layer |
| Jupyter Notebook (Python: pandas, seaborn, matplotlib) | Data visualization — neighborhood bar charts, category heatmap, resolution-rate charts, seasonal line chart |

---

## Key Findings

### Overall Crime Volume

| Metric | Value |
|--------|-------|
| 2024 Incidents (clean) | 109,342 |
| 2025 Incidents (clean) | 94,280 |
| Net Change | -15,062 |
| % Change | **-13.78%** |

### Crime Type Shifts
Larceny Theft consistently ranks as the most common crime category in both years, though its share of total crime fell. Drug Offense (+62.15%) and Warrant (+23.89%) were the standout increases; Motor Vehicle Theft (-43.07%) and Burglary (-26.82%) drove much of the overall decline.

### Geographic Concentration
Crime is not evenly distributed across SF's 10 police districts. Southern, Mission, and Tenderloin account for the largest shares of total incidents; Southern overtook Mission as the single highest-volume district in 2025.

### Resolution Trends
The clearance rate (Cite or Arrest Adult) improved from 23.62% to 30.40% year-over-year, while the open-case share fell — consistent with, and possibly a contributor to, the drop in total incident volume.

---

## Interactive Dashboard (Python + SQL, reproducible)

`sf_crime_dashboard.html` is a self-contained, interactive dashboard that communicates the
findings above — open it directly in any browser, no server or install needed.

It's built by `analysis/run_analysis.py`, a heavily-commented Python script that reproduces
the MySQL analysis above **without needing a MySQL server**:

1. `pandas.read_csv()` loads both raw CSVs.
2. `df.to_sql()` loads them into a local SQLite database.
3. The same SQL logic as `SF_crime_analysis.sql` (cleaning view, year-over-year comparison,
   category/district/resolution breakdowns, day-of-week and monthly seasonality, and the
   district safety ranking) runs against SQLite instead of MySQL.
4. Results are exported to `analysis/output/*.csv` and bundled into
   `analysis/output/dashboard_data.json`, which the dashboard embeds directly.

To regenerate everything from scratch:

```bash
pip install pandas
python3 analysis/run_analysis.py     # writes analysis/output/*.csv + dashboard_data.json
```

Then rebuild the dashboard HTML by embedding the fresh JSON into
`analysis/dashboard_template.html` (see the script's Step 10 comment for the exact fields).

Every number in the dashboard was independently recomputed with this pipeline and matched
the original MySQL results exactly (109,342 / 94,280 / -13.78% YoY, same category and
district rankings) — a useful sanity check that the two approaches (MySQL window functions
vs. SQLite + pandas) agree.

---

## Lingering Questions

- Does the 2025 decrease reflect an actual reduction in crime, or a reporting/backlog lag (2025 cases still being processed or reclassified after extraction)?
- Are there demographic or socioeconomic factors driving the district-level divergence (Southern's rise vs. Mission's relative plateau)?
- How does SF compare to other major U.S. cities (NYC, LA, Chicago) over the same period?
- Can incident description text be mined via NLP for more granular pattern detection?
