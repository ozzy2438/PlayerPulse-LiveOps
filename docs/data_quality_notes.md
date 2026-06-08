# Data Quality Notes

This document summarizes important data quality issues and safeguards used in PlayerPulse LiveOps.

## Raw TXT Parsing Issue

The first profiling notebook originally returned zero captured records because the parser did not match the actual TXT format. The parsing logic was updated after inspecting a real WoWAH TXT file.

The corrected parser extracts fields such as:

- `observed_at`
- `avatar_id`
- `level`
- `race`
- `character_class`
- `zone`
- `guild_id`
- guild membership indicators

## Format Drift Handling

Raw TXT logs can contain inconsistent or unexpected row formats. The staging notebook separates clean rows from anomalous rows instead of silently dropping all unexpected records.

Clean rows are written to:

- `data/processed/stg_wowah_events_clean_parts/`

Anomalous rows are written to:

- `data/processed/stg_wowah_event_anomalies_parts/`

## Anomaly Handling

Rows that cannot be parsed or do not meet expected structure are tracked as anomalies. This makes data quality visible and keeps the clean staging table more reliable.

Anomaly handling is important because it prevents one malformed pattern from corrupting downstream metrics.

## Duplicate Handling

Daily player facts are built at one row per:

- `avatar_id`
- `activity_date`

Validation found:

- Duplicate `avatar_id + activity_date` rows in `fct_player_daily`: **0**

## Negative Level Gain Warning

The daily metrics validation found:

- Negative `level_gain_day` rows: **273**

These rows are kept visible as a warning instead of hidden. A negative level gain can happen due to data issues, character changes, parsing edge cases, or observation inconsistencies.

## Guild Member Flag Handling

Guild participation is treated as an engagement proxy. However, guild fields may be missing or inconsistent across observations.

The project uses available guild indicators to calculate:

- latest guild member flag
- guild active days
- guild engaged flag

Limitation: this does not fully represent social behavior or group participation.

## Preview vs Full Data Issue

Early project previews used small sample outputs:

- `preview_stg_wowah_events.parquet`
- `preview_stg_wowah_event_anomalies.parquet`

These preview files covered only a small part of the data and were not suitable for downstream analytics.

The final pipeline uses full clean staging parts and avoids preview files for metrics, retention, segmentation, forecasting, and recommendations.

## Validation Checks Used

Validation checks included:

- total row counts
- unique avatar counts
- min/max dates
- duplicate checks
- null checks
- DAU greater than MAU checks
- negative level gain warnings
- segment share sum checks
- recommendation ID uniqueness
- priority rank uniqueness
- non-null recommended actions
- forecast leakage checks
- non-negative forecast values

## Why Raw and Full Data Should Not Be Committed to GitHub

Raw and full processed files are too large for a clean portfolio repository. They can make the repository hard to clone, review, and maintain.

The `.gitignore` excludes:

- `data/raw/`
- `data/processed/*.parquet`
- `data/processed/*_parts/`
- local DuckDB files
- virtual environments

Small CSV summaries and sample dashboard files are kept so recruiters can inspect the project and run the dashboard in demo mode.

## Important Representation Limits

- This is not real EA internal data.
- This is not verified real player account-level tracking.
- `avatar_id` is used only as a player proxy.
- Revenue and CLV are not modeled because monetization data is unavailable.
