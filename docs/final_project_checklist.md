# Final Project Checklist

## Data Pipeline

- **Completed:** Raw TXT profiling notebook created.
- **Completed:** TXT parsing fixed after initial zero-record issue.
- **Completed:** Clean staging parquet parts generated.
- **Completed:** Anomaly outputs generated.
- **Completed:** Preview files excluded from downstream analytics.
- **Needs optional future improvement:** Add automated unit tests for parser edge cases.

## Metrics

- **Completed:** `fct_player_daily.parquet` created.
- **Completed:** `agg_daily_metrics.parquet` created.
- **Completed:** DAU, WAU, MAU, stickiness, new avatars, returning avatars, and reactivated avatars calculated.
- **Completed:** Daily metrics validation summary created.

## Retention

- **Completed:** Cohort retention SQL and notebook created.
- **Completed:** D1/D7/D14/D30 exact-day retention calculated.
- **Completed:** Burn-in period applied.
- **Completed:** Immature cohort handling applied.
- **Completed:** Retention validation summary created.

## Segmentation

- **Completed:** Monthly lifecycle snapshots created.
- **Completed:** Mutually exclusive lifecycle segments created.
- **Completed:** Segment monthly aggregate created.
- **Completed:** Segment validation summary created.
- **Needs optional future improvement:** Add segment-level retention and forecast views.

## Forecasting

- **Completed:** Baseline DAU forecasting layer created.
- **Completed:** Rolling-origin backtesting used.
- **Completed:** Champion model selected.
- **Completed:** Forecast validation summary created.
- **Needs optional future improvement:** Add patch, event, and marketing calendar features.

## Recommendation Layer

- **Completed:** Trend alerts created.
- **Completed:** LiveOps recommendations created.
- **Completed:** Recommendation validation checks passed.
- **Completed:** Dashboard summary marts created.

## Dashboard

- **Completed:** Streamlit dashboard app created.
- **Completed:** Dashboard reads processed parquet outputs.
- **Completed:** Dashboard falls back to lightweight `data/sample` CSVs.
- **Needs manual screenshot:** Capture screenshots for GitHub README.
- **Needs optional future improvement:** Host the dashboard publicly.

## Documentation

- **Completed:** README rewritten in professional portfolio style.
- **Completed:** Metric dictionary created.
- **Completed:** Segmentation logic documentation created.
- **Completed:** Model validation documentation created.
- **Completed:** Executive memo created.
- **Completed:** Data quality notes created.
- **Completed:** Portfolio summary created.
- **Completed:** Interview story created.

## GitHub Hygiene

- **Completed:** `.gitignore` created.
- **Completed:** Raw data ignored.
- **Completed:** Large processed parquet files ignored.
- **Completed:** Virtual environments ignored.
- **Completed:** Small output CSVs and sample dashboard CSVs kept.
- **Needs manual screenshot:** Add dashboard screenshots after running locally.

## CV / LinkedIn Readiness

- **Completed:** CV-ready bullets added to README.
- **Completed:** CV-ready bullets added to interview story.
- **Completed:** Recruiter one-page summary created.
- **Needs manual step:** Add GitHub link to CV/LinkedIn.
- **Needs manual step:** Add screenshots or demo link to portfolio.
