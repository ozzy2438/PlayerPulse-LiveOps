Continue the PlayerPulse LiveOps project.

Important correction:
The previous daily activity metrics step worked technically, but it used:
data/processed/preview_stg_wowah_events.parquet

That is only preview data and produced only 2 activity days. This is not enough for retention, segmentation, churn, or forecasting.

Next task:
Regenerate the daily activity foundation using the FULL clean staged WoWAH dataset, not the preview file.

Before building metrics, first inspect what full clean staged outputs exist.

Check these possible locations:
- data/processed/stg_wowah_events_parts/
- data/processed/stg_wowah_events_clean_parts/
- data/processed/stg_wowah_event_clean_parts/
- data/processed/
- any existing DuckDB view named stg_wowah_events

Goal:
Find the full clean staged Parquet parts created by the staging notebook.

If full clean staged parts do not exist yet:
1. Go back to 02_stg_wowah_events_clean.ipynb.
2. Run the full batch export across all raw WoWAH .txt files.
3. Save clean parts under:
   data/processed/stg_wowah_events_clean_parts/
4. Save anomaly parts under:
   data/processed/stg_wowah_event_anomalies_parts/
5. Do not use preview files for downstream analytics.

If full clean staged parts already exist:
1. Create or replace a DuckDB view:
   stg_wowah_events
   reading from the full clean staged Parquet parts.
2. Confirm that the view is not reading preview_stg_wowah_events.parquet.

Validation required for full stg_wowah_events:
Produce and print:
- total rows
- unique avatar_id
- min observed_at
- max observed_at
- number of distinct activity dates
- duplicate count by observed_at + avatar_id
- null rates for observed_at, avatar_id, level, race, character_class, zone
- level min/max
- top 10 race values
- top 10 character_class values
- top 10 zone values

Expected sanity check:
- distinct activity dates should be much more than 2.
- date range should span a large part of the WoWAH dataset, not only 2005-12-31 to 2006-01-01.
- If still only 2 days appear, stop and report that the source is still preview data.

After validating full staging:
Regenerate:

1. data/processed/fct_player_daily.parquet
2. data/processed/agg_daily_metrics.parquet
3. data/outputs/daily_metrics_validation_summary.csv
4. DuckDB views:
   - fct_player_daily
   - agg_daily_metrics

Use the same definitions as before:

fct_player_daily:
- one row per avatar_id per activity_date
- activity_date = CAST(observed_at AS DATE)
- first_seen_at_that_day
- last_seen_at_that_day
- observations_count
- level_start
- level_end
- level_max
- level_gain_day
- race
- character_class
- guild_id_latest
- guild_member_flag_latest
- zones_visited_count
- primary_zone
- active_flag

agg_daily_metrics:
- activity_date
- dau
- wau
- mau
- dau_mau_stickiness
- total_observations
- active_guild_members
- guild_member_share
- avg_observations_per_avatar
- avg_level
- avg_level_gain_day
- total_level_gain_day
- new_avatars
- returning_avatars
- reactivated_avatars_30d

Important logic:
- DAU = distinct avatar_id active on that day.
- WAU = distinct avatar_id active from current date - 6 days to current date.
- MAU = distinct avatar_id active from current date - 29 days to current date.
- new_avatars = first ever activity date equals current date.
- returning_avatars = active today, seen before, and previous activity was within 30 days.
- reactivated_avatars_30d = active today, seen before, and previous activity gap > 30 days.
- Use avatar_id as player proxy.
- Do not remove rows only because guild_id is null.
- Exclude rows where observed_at or avatar_id is null.

Performance requirements:
- Use DuckDB SQL as much as possible.
- Do not load the full raw dataset into pandas.
- Reading full Parquet parts through DuckDB is preferred.
- Only export final validation summaries to CSV.

Update files:
- notebooks/03_daily_activity_metrics.ipynb
- sql/02_fct_player_daily_and_daily_metrics.sql
- data/processed/fct_player_daily.parquet
- data/processed/agg_daily_metrics.parquet
- data/outputs/daily_metrics_validation_summary.csv

At the end, report exactly:
1. Which full clean source path was used
2. Whether preview file was avoided: yes/no
3. Total rows in stg_wowah_events
4. Unique avatar_id in stg_wowah_events
5. Number of distinct activity dates
6. Date range
7. fct_player_daily row count
8. agg_daily_metrics row count
9. Average DAU
10. Average MAU
11. Days where DAU > MAU
12. Negative level_gain_day count
13. Any warnings