"""
================================================================================
 SF Crime Analysis: Python + SQL Pipeline (educational walkthrough)
================================================================================
Author   : Plinio Durango (pipeline written with Claude, Aug 2026)
Purpose  : Reproduce, verify, and export the findings already documented in
           SF_crime_analysis.sql / README.md as a repeatable, non-MySQL
           pipeline that anyone can run with just `python3 run_analysis.py`.

WHY THIS FILE EXISTS
---------------------------------------------------------------------------
The original analysis (SF_crime_analysis.sql) was written against a local
MySQL server. That's great for an interactive session, but it means the
analysis can't be re-run by someone who clones the repo without also
standing up a MySQL instance and importing 60MB of CSVs by hand.

This script does the same analytical work end-to-end using tools anyone
already has:
  1. pandas   -> reads the two raw CSVs
  2. sqlite3  -> Python's built-in SQL engine (no server needed) -- we load
                 the CSVs into an in-memory SQLite database and then run
                 *actual SQL* against them, just like the MySQL version did
  3. pandas   -> reads the SQL query results back out for further use
  4. json/csv -> exports clean summary tables that the HTML dashboard reads

Each section below mirrors a section of SF_crime_analysis.sql, and is
annotated with what the query does, why it's written that way, and what it
found -- so this file doubles as a teaching example of "how do I move a SQL
analysis into a reproducible Python script."
================================================================================
"""

import sqlite3
import json
from pathlib import Path

import pandas as pd

# ----------------------------------------------------------------------------
# STEP 0: Paths
# ----------------------------------------------------------------------------
# We keep the pipeline self-contained: read the raw CSVs from the repo root,
# write every output (cleaned tables + summary CSVs + a JSON bundle for the
# dashboard) into analysis/output/ so nothing pollutes the repo root.
REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

CSV_2024 = REPO_ROOT / "SFcrime2024_processed.csv"
CSV_2025 = REPO_ROOT / "SFcrime2025_processed (1).csv"


def log(msg: str) -> None:
    """Small helper so the pipeline reads like a narrated walkthrough when run."""
    print(f"\n>>> {msg}")


# ----------------------------------------------------------------------------
# STEP 1: Load the raw CSVs with pandas
# ----------------------------------------------------------------------------
log("STEP 1 — Loading raw CSVs with pandas")

# low_memory=False avoids pandas guessing column dtypes chunk-by-chunk, which
# can produce a "mixed types" warning on a 28-31MB file with some blank
# columns (e.g. AnalysisNeighborhood has empty strings in some rows).
df_2024 = pd.read_csv(CSV_2024, low_memory=False)
df_2025 = pd.read_csv(CSV_2025, low_memory=False)

print(f"    sfcrime2024: {len(df_2024):,} rows, {df_2024.shape[1]} columns")
print(f"    sfcrime2025: {len(df_2025):,} rows, {df_2025.shape[1]} columns")

# ----------------------------------------------------------------------------
# STEP 2: Load both DataFrames into a local SQLite database
# ----------------------------------------------------------------------------
# This is the "bridge" step between Python and SQL: pandas' `.to_sql()`
# writes a DataFrame straight into a SQL table. From here on we can write
# real SQL (SELECT / GROUP BY / window functions / views) exactly like the
# MySQL version did, but with zero setup -- SQLite ships with Python.
log("STEP 2 — Loading both years into an in-memory SQLite database")

conn = sqlite3.connect(":memory:")
df_2024.to_sql("sfcrime2024", conn, index=False, if_exists="replace")
df_2025.to_sql("sfcrime2025", conn, index=False, if_exists="replace")
print("    Tables created: sfcrime2024, sfcrime2025")


def q(sql: str) -> pd.DataFrame:
    """Run a SQL query against our SQLite connection and get a DataFrame back."""
    return pd.read_sql_query(sql, conn)


# ----------------------------------------------------------------------------
# STEP 3: Rebuild the SF_crime_analysis.sql Section-3 date-range check
# ----------------------------------------------------------------------------
# This is the single most important finding in the whole project: the file
# named "sfcrime2025" is NOT a clean calendar year. It's a rolling export
# that also contains incidents already dated in 2026. If you trust the file
# name instead of the actual IncidentDate, you conclude crime went UP in
# 2025. Once you filter by the real date, it went DOWN. We reproduce that
# check here so the dashboard can show the "gotcha" explicitly.
log("STEP 3 — Verifying the 2025-file-actually-contains-2026-rows data quality issue")

date_range = q("""
    SELECT
        'sfcrime2025' AS table_name,
        MIN(IncidentDate) AS earliest_date,
        MAX(IncidentDate) AS latest_date,
        SUM(CASE WHEN substr(IncidentDate, 1, 4) = '2026' THEN 1 ELSE 0 END) AS rows_dated_2026,
        COUNT(*) AS total_rows
    FROM sfcrime2025
""")
print(date_range.to_string(index=False))

# ----------------------------------------------------------------------------
# STEP 4: Build the cleaned, unified view (mirrors SF_crime_analysis.sql §4)
# ----------------------------------------------------------------------------
# SQLite doesn't support CREATE OR REPLACE VIEW with the exact same syntax
# nuances as MySQL, but the concept is identical: UNION the two years
# together, drop rows with missing category/district, and derive
# incident_year / incident_month / day_of_week straight from IncidentDate
# rather than trusting which table the row came from.
log("STEP 4 — Building the unified, cleaned view (sfcrime_combined_clean)")

conn.execute("DROP VIEW IF EXISTS sfcrime_combined_clean")
conn.execute("""
    CREATE VIEW sfcrime_combined_clean AS
    SELECT
        RowID,
        IncidentNumber,
        IncidentDate,
        IncidentTime,
        CAST(substr(IncidentDate, 1, 4) AS INTEGER)  AS incident_year,
        CAST(substr(IncidentDate, 6, 2) AS INTEGER)  AS incident_month,
        IncidentDayofWeek                            AS day_of_week,
        IncidentCategory,
        Resolution,
        PoliceDistrict,
        AnalysisNeighborhood,
        Latitude,
        Longitude,
        'sfcrime2024'                                AS source_table
    FROM sfcrime2024
    WHERE IncidentCategory IS NOT NULL AND PoliceDistrict IS NOT NULL

    UNION ALL

    SELECT
        RowID,
        IncidentNumber,
        IncidentDate,
        IncidentTime,
        CAST(substr(IncidentDate, 1, 4) AS INTEGER)  AS incident_year,
        CAST(substr(IncidentDate, 6, 2) AS INTEGER)  AS incident_month,
        IncidentDayofWeek                            AS day_of_week,
        IncidentCategory,
        Resolution,
        PoliceDistrict,
        AnalysisNeighborhood,
        Latitude,
        Longitude,
        'sfcrime2025'                                AS source_table
    FROM sfcrime2025
    WHERE IncidentCategory IS NOT NULL AND PoliceDistrict IS NOT NULL
""")
row_count = q("SELECT COUNT(*) AS n FROM sfcrime_combined_clean").iloc[0]["n"]
print(f"    View created. {row_count:,} total rows across both years (pre year-filter).")

# ----------------------------------------------------------------------------
# STEP 5: Year-over-year totals (mirrors §5a)
# ----------------------------------------------------------------------------
log("STEP 5 — Year-over-year totals, filtered to true calendar years 2024/2025")

yoy_totals = q("""
    SELECT incident_year, COUNT(*) AS total_incidents
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY incident_year
    ORDER BY incident_year
""")
print(yoy_totals.to_string(index=False))

pct_change = (
    (yoy_totals.loc[yoy_totals.incident_year == 2025, "total_incidents"].iloc[0]
     - yoy_totals.loc[yoy_totals.incident_year == 2024, "total_incidents"].iloc[0])
    / yoy_totals.loc[yoy_totals.incident_year == 2024, "total_incidents"].iloc[0]
    * 100
)
print(f"    => {pct_change:.2f}% change 2024 -> 2025")
yoy_totals.to_csv(OUTPUT_DIR / "yoy_totals.csv", index=False)

# ----------------------------------------------------------------------------
# STEP 6: Year-over-year change by crime category (mirrors §5b)
# ----------------------------------------------------------------------------
log("STEP 6 — Year-over-year change per crime category")

yoy_category = q("""
    WITH y2024 AS (
        SELECT IncidentCategory AS category, COUNT(*) AS incidents_2024
        FROM sfcrime2024
        WHERE substr(IncidentDate, 1, 4) = '2024'
        GROUP BY IncidentCategory
    ),
    y2025 AS (
        SELECT IncidentCategory AS category, COUNT(*) AS incidents_2025
        FROM sfcrime2025
        WHERE substr(IncidentDate, 1, 4) = '2025'
        GROUP BY IncidentCategory
    )
    SELECT
        y2024.category,
        y2024.incidents_2024,
        y2025.incidents_2025,
        (y2025.incidents_2025 - y2024.incidents_2024) AS net_change,
        ROUND(
            (y2025.incidents_2025 - y2024.incidents_2024) * 100.0 / y2024.incidents_2024, 2
        ) AS pct_change
    FROM y2024
    JOIN y2025 ON y2024.category = y2025.category
    ORDER BY pct_change DESC
""")
print(yoy_category.head(5).to_string(index=False))
print("    ...")
print(yoy_category.tail(5).to_string(index=False))
yoy_category.to_csv(OUTPUT_DIR / "yoy_category.csv", index=False)

# ----------------------------------------------------------------------------
# STEP 7: Crime breakdowns — category / district / resolution (mirrors §6)
# ----------------------------------------------------------------------------
log("STEP 7 — Breakdowns by category, police district, and resolution outcome")

by_category = q("""
    SELECT
        incident_year,
        IncidentCategory,
        COUNT(*) AS num_crimes,
        ROUND(
            COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY incident_year), 2
        ) AS pct_of_year
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY incident_year, IncidentCategory
    ORDER BY incident_year, num_crimes DESC
""")
by_category.to_csv(OUTPUT_DIR / "by_category.csv", index=False)

by_district = q("""
    SELECT
        incident_year,
        PoliceDistrict,
        COUNT(*) AS num_crimes,
        ROUND(
            COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY incident_year), 2
        ) AS pct_of_year
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY incident_year, PoliceDistrict
    ORDER BY incident_year, num_crimes DESC
""")
by_district.to_csv(OUTPUT_DIR / "by_district.csv", index=False)

by_resolution = q("""
    SELECT
        incident_year,
        Resolution,
        COUNT(*) AS num_cases,
        ROUND(
            COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY incident_year), 2
        ) AS pct_of_year
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY incident_year, Resolution
    ORDER BY incident_year, num_cases DESC
""")
by_resolution.to_csv(OUTPUT_DIR / "by_resolution.csv", index=False)

print("    Wrote by_category.csv, by_district.csv, by_resolution.csv")

# ----------------------------------------------------------------------------
# STEP 8: Time-based patterns — day of week + monthly seasonality (mirrors §7)
# ----------------------------------------------------------------------------
log("STEP 8 — Day-of-week and monthly seasonality patterns")

# SQLite has no FIELD() function like MySQL, so we sort weekdays with a
# Python list instead of doing it in SQL -- a nice example of splitting work
# between the two tools where each is strongest.
by_day = q("""
    SELECT
        day_of_week,
        COUNT(*) AS total_incidents,
        SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS incidents_2024,
        SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END) AS incidents_2025
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY day_of_week
""")
weekday_order = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
by_day["day_of_week"] = pd.Categorical(by_day["day_of_week"], categories=weekday_order, ordered=True)
by_day = by_day.sort_values("day_of_week")
by_day.to_csv(OUTPUT_DIR / "by_day_of_week.csv", index=False)

by_month = q("""
    SELECT
        incident_month,
        SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS incidents_2024,
        SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END) AS incidents_2025
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY incident_month
    ORDER BY incident_month
""")
month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
by_month["month_name"] = by_month["incident_month"].apply(lambda m: month_names[m - 1])
by_month.to_csv(OUTPUT_DIR / "by_month.csv", index=False)

print("    Wrote by_day_of_week.csv, by_month.csv")

# ----------------------------------------------------------------------------
# STEP 9: Neighborhood / district safety ranking (mirrors §8)
# ----------------------------------------------------------------------------
log("STEP 9 — District safety ranking (by combined 2024+2025 incident volume)")

safety_rank = q("""
    SELECT
        PoliceDistrict,
        SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS incidents_2024,
        SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END) AS incidents_2025,
        COUNT(*) AS total_incidents,
        RANK() OVER (ORDER BY COUNT(*) ASC) AS safety_rank
    FROM sfcrime_combined_clean
    WHERE incident_year IN (2024, 2025)
    GROUP BY PoliceDistrict
    ORDER BY safety_rank
""")
print(safety_rank.to_string(index=False))
safety_rank.to_csv(OUTPUT_DIR / "safety_rank.csv", index=False)

top_category_per_district = q("""
    SELECT PoliceDistrict, IncidentCategory, num_incidents, cat_rank
    FROM (
        SELECT
            PoliceDistrict,
            IncidentCategory,
            COUNT(*) AS num_incidents,
            RANK() OVER (PARTITION BY PoliceDistrict ORDER BY COUNT(*) DESC) AS cat_rank
        FROM sfcrime_combined_clean
        WHERE incident_year IN (2024, 2025)
        GROUP BY PoliceDistrict, IncidentCategory
    )
    WHERE cat_rank <= 5
    ORDER BY PoliceDistrict, cat_rank
""")
top_category_per_district.to_csv(OUTPUT_DIR / "top_category_per_district.csv", index=False)

print("    Wrote safety_rank.csv, top_category_per_district.csv")

# ----------------------------------------------------------------------------
# STEP 10: Bundle everything into one JSON file for the HTML dashboard
# ----------------------------------------------------------------------------
# The dashboard is a single self-contained HTML file (no server, no build
# step) so it can be opened by double-clicking or hosted as a static page.
# Embedding the data as JSON keeps it fully self-contained -- no separate
# CSV fetch calls that would fail when opened via file://.
log("STEP 10 — Bundling all summary tables into dashboard_data.json")

bundle = {
    "generated_from": {
        "rows_2024": int(len(df_2024)),
        "rows_2025_raw": int(len(df_2025)),
    },
    "yoy_totals": yoy_totals.to_dict(orient="records"),
    "yoy_category": yoy_category.to_dict(orient="records"),
    "by_category": by_category.to_dict(orient="records"),
    "by_district": by_district.to_dict(orient="records"),
    "by_resolution": by_resolution.to_dict(orient="records"),
    "by_day_of_week": by_day.to_dict(orient="records"),
    "by_month": by_month.to_dict(orient="records"),
    "safety_rank": safety_rank.to_dict(orient="records"),
    "top_category_per_district": top_category_per_district.to_dict(orient="records"),
    "date_quality_check": date_range.to_dict(orient="records"),
}
with open(OUTPUT_DIR / "dashboard_data.json", "w") as f:
    json.dump(bundle, f, indent=2, default=str)

conn.close()
log("DONE — all summary CSVs + dashboard_data.json written to analysis/output/")
