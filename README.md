# SF Crime Analysis: San Francisco Incidents 2024 vs 2025

**Author:** Plinio Durango  
**Tool:** MySQL / SQL  
**Dataset:** SFPD Incident Reports 2024 & 2025 (San Francisco Police Department Open Data)  
**Source:** [SF Open Data Portal](https://data.sfgov.org/Public-Safety/Police-Department-Incident-Reports)  

---

## Overview

This project analyzes 225,000+ police incident records from the San Francisco Police Department spanning 2024 and 2025. The goal is to determine whether crime is rising or falling across the city, identify which crime types and neighborhoods drive the most activity, uncover weekly and seasonal patterns, and rank districts by relative safety. The analysis covers year-over-year volume changes, geographic breakdowns, resolution outcomes, and time-based trends.

---

## Dataset

| Attribute | 2024 Table | 2025 Table |
|-----------|-----------|----------|
| Rows | 109,626 | 115,835 |
| Columns | 22 | 22 |
| Unique ID | RowID + IncidentNumber | RowID + IncidentNumber |

### Key Columns

| Column | Description |
|--------|-------------|
| `IncidentDate` | Date the incident occurred |
| `IncidentTime` | Time the incident occurred |
| `IncidentCategory` | High-level crime type (e.g., Larceny Theft, Assault) |
| `IncidentDescription` | Detailed description of the incident |
| `Resolution` | Outcome: Open, Cite/Arrest, Exceptional Adult, etc. |
| `PoliceDistrict` | One of SF's 10 police districts |
| `Latitude / Longitude` | Geographic coordinates of the incident |

---

## Project Structure

```
sf_crime_2024_2025/
├── SF_crime_analysis.sql          # Full SQL analysis (9 sections)
├── SFcrime2024_processed.csv      # Cleaned 2024 incident data
├── SFcrime2025_processed (1).csv  # Cleaned 2025 incident data
├── Plinio_Durango_case_study3.ipynb  # Jupyter notebook with visualizations
└── README.md                      # This file
```

---

## Methodology

### Data Cleaning

A unified cleaning view (`sfcrime_combined_clean`) was created using `UNION ALL` across both years. Rows with NULL `IncidentCategory` or `PoliceDistrict` were excluded. The view also derives `incident_year`, `incident_month`, and `day_of_week` columns from `IncidentDate` for time-based analysis.

**EDA issues identified:**
- Some rows have NULL Latitude/Longitude (location not captured at scene)
- Both tables share the same 22-column schema — safe to UNION ALL
- 2025 dataset is ~5.7% larger than 2024 (115,835 vs 109,626 rows)

---

## Analysis

### Section 5: Year-over-Year Comparison

| Year | Total Incidents | Change |
|------|----------------|--------|
| 2024 | 109,626 | — |
| 2025 | 115,835 | +5.7% |

A side-by-side JOIN query compares each crime category individually to reveal which categories improved and which worsened between years.

### Section 6: Crime Breakdowns

**6a. By Type of Crime** — Window functions compute each category's percentage share within each year, revealing shifts in the crime mix beyond raw volume changes.

**6b. By Police District** — Geographic breakdown identifies the most active districts and year-over-year changes in crime concentration.

**6c. By Resolution** — Tracks whether cases are cleared (arrest/cite) or remain open/active, providing a proxy for law enforcement effectiveness.

### Section 7: Time-Based Patterns

**7a. Day of Week** — Pivots incidents by day using conditional aggregation, revealing consistent weekly crime cycles (e.g., Friday/Saturday spikes).

**7b. Monthly Seasonality** — Month-by-month comparison identifies seasonal drivers of the overall year-over-year variance (e.g., summer outdoor crime peaks).

### Section 8: Neighborhood Safety Ranking

Districts are ranked by total incident count (fewest = safest). A secondary query identifies the top 5 most frequent crime categories per district.

**Safety definition caveat:** This metric measures incident volume, not severity. A high-density district may report more incidents simply due to population size, not inherently greater danger.

---

## Tools & Technologies

| Tool | Purpose |
|------|---------|
| MySQL | Core SQL analysis |
| Window Functions (`RANK`, `LAG`, `SUM OVER`) | YoY change, district ranking, category shares |
| `UNION ALL` | Combining 2024 and 2025 datasets |
| `CREATE OR REPLACE VIEW` | Centralized data cleaning layer |
| Jupyter Notebook (Python) | Data visualization and plots |

---

## Key Findings

### Overall Crime Volume

| Metric | Value |
|--------|-------|
| 2024 Incidents | 109,626 |
| 2025 Incidents | 115,835 |
| Net Change | +6,209 |
| % Change | ~+5.7% |

### Crime Type (Top Categories)
Larceny Theft consistently ranks as the most common crime category in both years. Categories with the largest percentage increases signal areas requiring deeper investigation into root causes such as economic conditions or policy changes.

### Geographic Concentration
Crime is not evenly distributed across SF's 10 police districts. The Tenderloin and Mission districts typically account for a disproportionate share of total incidents. Some districts may show improvement year-over-year while others worsen.

### Resolution Trends
Tracking resolution rates across years reveals whether a growing backlog of open cases is developing — a potential signal of resource constraints within the department.

---

## Lingering Questions

- Does the 2025 increase reflect actual crime growth or improved incident reporting practices?
- Are there demographic or socioeconomic factors driving district-level spikes?
- How does SF compare to other major U.S. cities (NYC, LA, Chicago) over the same period?
- Can incident description text be mined via NLP for more granular pattern detection?
