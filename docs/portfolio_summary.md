# Portfolio Summary

## Project

**PlayerPulse LiveOps — MMORPG Player Segmentation, Retention & Forecasting Analytics**

## Problem

LiveOps teams need to monitor player activity, retention, lifecycle health, and early warning signals. This project builds an end-to-end analytics system that turns public MMORPG avatar history data into dashboard-ready insights and ranked LiveOps recommendations.

## Tools

- Python
- SQL
- DuckDB
- Pandas
- Streamlit
- Plotly
- Jupyter
- Parquet

## Dataset Size

- **36,472,825** clean avatar observation rows
- **91,056** unique avatar proxies
- **1,107** daily metric rows
- Date range: `2005-12-31` to `2009-01-10`

`avatar_id` is used as a player proxy. The dataset does not contain real account-level player IDs or revenue data.

## Methods

- Raw TXT parsing and anomaly handling
- Clean parquet staging
- Player-day fact table
- DAU, WAU, MAU, stickiness, new/returning/reactivated avatars
- Exact-day D1/D7/D14/D30 cohort retention
- Monthly lifecycle segmentation
- Rolling-origin forecast backtesting
- Trend alert rules
- LiveOps recommendation mapping
- Streamlit dashboard

## Key Outputs

- `fct_player_daily.parquet`
- `agg_daily_metrics.parquet`
- `agg_cohort_retention.parquet`
- `mart_player_segments.parquet`
- `mart_forecast_daily.parquet`
- `mart_trend_alerts.parquet`
- `mart_liveops_recommendations.parquet`
- Streamlit dashboard app

## 4 Strongest Insights

1. **Retention risk:** D7 retention dropped versus the recent cohort baseline, making onboarding and early progression the top priority.
2. **Engagement risk:** Core Engaged avatars declined by **948** over the latest 3-month comparison.
3. **Lapsed growth:** `Lapsed Players` are the largest segment with **83,459** avatars and continued growth.
4. **Forecast baseline:** `moving_avg_30d` was the best explainable DAU forecast baseline, with MAE **267.29** and sMAPE **17.36%**.

## Business Value

The project shows how a gaming analytics team can move from raw telemetry-like data to business decisions:

- Detect player health issues.
- Prioritize retention and engagement work.
- Monitor lifecycle segment movement.
- Create explainable forecasts.
- Translate alerts into LiveOps recommendations.

## Limitations

- `avatar_id` is a proxy, not a verified account-level player ID.
- No revenue, CLV, or monetization data is available.
- No patch, event, or marketing calendar is available.
- Forecasting is baseline-level and explainable, not a production ML system.

## Links

- GitHub: `[add GitHub link here]`
- Dashboard: `[add hosted dashboard link here]`
- Screenshots: `[add screenshot links here]`
