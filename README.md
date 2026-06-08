# PlayerPulse LiveOps

**MMORPG Player Segmentation, Retention & Forecasting Analytics**

PlayerPulse LiveOps is an end-to-end gaming analytics portfolio project built on the public WoWAH MMORPG avatar history dataset. The project turns raw timestamped avatar observations into clean staging tables, daily activity metrics, retention cohorts, lifecycle segments, explainable DAU forecasts, trend alerts, and ranked LiveOps recommendations. It is designed to show practical skills for gaming analytics, publishing insights, and data science roles.

## Business Problem

LiveOps and publishing teams need to understand player health before problems become visible in headline metrics. They need answers to questions like:

- Are active players growing, stable, or declining?
- Are new avatars returning after D1/D7/D14/D30?
- Which lifecycle segments are growing or shrinking?
- Which player groups need LiveOps action?
- What is a reasonable near-term DAU outlook?

This project builds a compact analytics system that converts gameplay activity data into monitoring dashboards and recommendation-ready actions.

## Dataset

The project uses the public **WoWAH MMORPG avatar history dataset**.

Important dataset notes:

- `avatar_id` is used as the player proxy because account-level user IDs are not available.
- The data represents avatar observations, not verified real player account tracking.
- There is no monetization, revenue, purchase, or CLV data.
- Revenue and CLV are therefore not modeled.
- Guild, level, race, class, zone, and observation timestamps are used as engagement signals.

## Key Project Outcomes

- Parsed and cleaned **36,472,825** WoWAH event rows.
- Built player-day facts for **91,056** unique avatars.
- Generated **1,107** daily metric rows from `2005-12-31` to `2009-01-10`.
- Built D1/D7/D14/D30 exact-day retention cohorts.
- Created **38** monthly lifecycle snapshots.
- Built lifecycle segmentation across **1,816,697** avatar-snapshot rows.
- Evaluated four explainable DAU forecasting baselines.
- Selected `moving_avg_30d` as the champion baseline model.
- Generated a 30-day DAU forecast from `2009-01-11` to `2009-02-09`.
- Created **4** ranked LiveOps recommendations from trend alerts.
- Packaged a Streamlit dashboard for recruiter and interview walkthroughs.

## Architecture

```text
raw TXT logs
  -> clean staging parquet
  -> fct_player_daily
  -> agg_daily_metrics
  -> cohort retention
  -> lifecycle segmentation
  -> baseline forecasting and backtesting
  -> trend alerts
  -> LiveOps recommendations
  -> dashboard summary marts
  -> Streamlit dashboard
```

## Repository Structure

```text
dashboard/
  streamlit_app.py

data/
  outputs/                 small validation and recommendation CSVs
  processed/               local parquet outputs, ignored by Git
  sample/                  lightweight dashboard demo CSVs

docs/
  data_quality_notes.md
  executive_memo.md
  final_project_checklist.md
  interview_story.md
  metric_dictionary.md
  model_validation.md
  portfolio_summary.md
  segmentation_logic.md

notebooks/
  01_data_profile.ipynb
  02_stg_wowah_events_clean.ipynb
  03_daily_activity_metrics.ipynb
  04_retention_cohort_analysis.ipynb
  05_player_lifecycle_segmentation.ipynb
  06_forecasting_trend_detection.ipynb
  07_liveops_recommendations_dashboard_marts.ipynb

sql/
  01_stg_wowah_events.sql
  02_fct_player_daily_and_daily_metrics.sql
  03_cohort_retention.sql
  04_player_lifecycle_segmentation.sql
  05_forecasting_trend_detection.sql
  06_liveops_recommendations_dashboard_marts.sql
```

## Analytics Layers

### Staging Layer

Raw WoWAH TXT logs are parsed into clean event records. Invalid or unusual rows are separated into anomaly outputs. Full staging is stored as parquet parts rather than one large file.

### Daily Metrics

`fct_player_daily` creates one row per `avatar_id` and activity date. `agg_daily_metrics` summarizes DAU, WAU, MAU, DAU/MAU stickiness, observations, new avatars, returning avatars, and reactivated avatars.

### Retention Cohorts

Cohorts are based on `first_seen_date`. Retention is exact-day retention:

- D1: active exactly 1 day after first seen
- D7: active exactly 7 days after first seen
- D14: active exactly 14 days after first seen
- D30: active exactly 30 days after first seen

Average retention from the final output:

- D1 retention: **28.62%**
- D7 retention: **12.48%**
- D14 retention: **9.12%**
- D30 retention: **6.41%**

### Lifecycle Segmentation

Monthly snapshots assign each avatar to one mutually exclusive lifecycle segment:

- Lapsed Players
- Reactivated Players
- New Explorers
- At-Risk Players
- Core Engaged
- Fast Progressors
- Social/Guild Engaged
- Casual Returners
- Low Activity / Other

The latest snapshot on `2009-01-10` shows `Lapsed Players` as the largest segment, with **83,459** avatars.

### Forecasting and Backtesting

The forecasting layer evaluates simple, explainable DAU baselines:

- `naive_1d`
- `moving_avg_7d`
- `seasonal_naive_7d`
- `moving_avg_30d`

Rolling-origin backtesting is used instead of random train/test splits because this is time-series data.

Champion model:

- Model: `moving_avg_30d`
- MAE: **267.29**
- RMSE: **459.09**
- MAPE: **14.43%**
- sMAPE: **17.36%**

This is positioned as explainable baseline forecasting, not a final production ML forecast.

### Trend Alerts

Trend alerts monitor:

- DAU drop
- MAU drop
- DAU/MAU stickiness drop
- D7 retention drop
- At-Risk segment growth
- Core Engaged decline
- Lapsed segment growth

### LiveOps Recommendations

Trend alerts are mapped into ranked LiveOps recommendations. The latest recommendation layer produced **4** actions:

1. Onboarding / early progression review
2. Endgame content and event engagement review
3. Win-back campaign
4. Acquisition quality and content cadence review

## Key Insights

- The latest active base shows pressure: latest DAU is **881**, while 30-day average DAU is **1,855**.
- `Lapsed Players` dominate the latest lifecycle snapshot, which suggests many avatars are no longer active.
- `Core Engaged` declined by **948** avatars over the latest 3-month comparison, triggering a high-severity alert.
- D7 retention dropped materially versus the recent cohort baseline, making early progression and onboarding a priority.
- The champion baseline forecast expects a 30-day average DAU of about **1,855**, but this should be interpreted with caution because no patch, marketing, or event calendar is available.

## Dashboard Pages

The Streamlit dashboard includes:

1. **Executive Summary**: latest DAU, WAU, MAU, stickiness, alert counts, and top recommendations.
2. **Player Activity**: DAU, MAU, stickiness, new/returning/reactivated avatars.
3. **Retention & Cohorts**: D1/D7/D14/D30 retention, retention trends, and retention curve.
4. **Lifecycle Segments**: latest segment distribution, addressable distribution, segment trends, and 3-month change.
5. **Forecasting**: DAU history, 30-day forecast, simple bounds, and champion model metrics.
6. **Trend Alerts & Recommendations**: alert table and ranked LiveOps action table.

## How to Run Locally

Create and activate a virtual environment:

```bash
python -m venv .venv
source .venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the dashboard:

```bash
streamlit run dashboard/streamlit_app.py
```

Notes:

- The dashboard first looks for local parquet files in `data/processed/`.
- Large processed parquet files are ignored by Git.
- If processed parquet files are not available, the dashboard can use lightweight CSV files in `data/sample/`.
- Raw data is not required to view the packaged dashboard demo.

## Data Limitations

- `avatar_id` is a proxy for player identity, not a verified account-level player ID.
- The dataset has no revenue, purchase, marketing campaign, or CLV fields.
- Forecasting does not include patch notes, expansion releases, content calendars, or marketing events.
- Some negative level gain rows exist and are documented as data quality warnings.
- Guild activity is interpreted only from available fields and may not fully capture social engagement.
- The data is historical public research data and should not be described as real EA internal data or current production telemetry.

## Future Improvements

- Add patch, event, and marketing calendar metadata.
- Add account-level identity if available.
- Add monetization data to support ARPDAU, payer conversion, and CLV analysis.
- Add more advanced time-series models after validating against baseline performance.
- Add segment-level retention and forecast views.
- Add screenshots and a hosted dashboard link for the GitHub README.

## Interview Talking Points

- Built an end-to-end gaming analytics pipeline from raw text logs to dashboard-ready marts.
- Used `avatar_id` as a transparent player proxy because account IDs were unavailable.
- Designed exact-day retention logic with burn-in and immature cohort handling.
- Built mutually exclusive lifecycle segmentation with monthly snapshots.
- Used rolling-origin backtesting for time-series forecasting validation.
- Converted trend alerts into ranked LiveOps recommendations.
- Kept raw and large processed files out of GitHub while providing sample dashboard data.

## CV-Ready Project Bullets

**Project: PlayerPulse LiveOps — MMORPG Player Segmentation, Retention & Forecasting Analytics**  
Independent Project | Python, SQL, DuckDB, Pandas, Streamlit, Time-Series Forecasting

- Built an end-to-end MMORPG analytics pipeline over **36M+** cleaned avatar observation rows and **91K+** avatar proxies, producing daily activity, retention, segmentation, forecasting, and recommendation marts.
- Designed D1/D7/D14/D30 exact-day cohort retention analysis with burn-in and immature cohort controls to avoid misleading early-dataset retention results.
- Created **38** monthly lifecycle snapshots and mutually exclusive player segments including Lapsed, At-Risk, Core Engaged, Fast Progressors, and Reactivated Players.
- Evaluated explainable DAU forecasting baselines with rolling-origin backtesting and converted trend alerts into **4** prioritized LiveOps recommendations for onboarding, engagement, win-back, and acquisition/content review.
