# Interview Story

## 1. 30-Second Project Pitch

PlayerPulse LiveOps is an end-to-end gaming analytics project built on a public MMORPG avatar history dataset. I cleaned raw TXT logs, created daily activity metrics, built cohort retention, lifecycle segmentation, baseline DAU forecasting, trend alerts, and LiveOps recommendations. The final project includes a Streamlit dashboard and portfolio-ready documentation.

## 2. 60-Second Project Pitch

This project shows how I would support a LiveOps or publishing insights team. I started with raw WoWAH avatar history logs and created clean parquet outputs. Then I built DAU, WAU, MAU, retention cohorts, monthly lifecycle segments, forecasting backtests, and trend alerts. I used `avatar_id` as a player proxy because account-level IDs were not available. The final layer converts alerts into ranked business recommendations, such as onboarding review, win-back campaigns, and endgame engagement review.

## 3. 2-Minute Technical Explanation

The pipeline starts with raw TXT parsing. Clean records go to staging parquet files and unusual records go to anomaly outputs. From the clean staging layer, I build `fct_player_daily`, one row per avatar and activity date.

From this fact table, I calculate daily metrics like DAU, WAU, MAU, stickiness, new avatars, returning avatars, and reactivated avatars. I then build cohort retention using first seen date and exact-day D1, D7, D14, and D30 retention.

For segmentation, I create monthly snapshots. Each avatar is assigned to one lifecycle segment using priority logic. Segments include Lapsed Players, Reactivated Players, New Explorers, At-Risk Players, Core Engaged, Fast Progressors, Social/Guild Engaged, Casual Returners, and Low Activity / Other.

For forecasting, I evaluate simple DAU baselines with rolling-origin backtesting. The champion model is `moving_avg_30d`. Finally, trend alerts are mapped into LiveOps recommendations and shown in a Streamlit dashboard.

## 4. What Was the Hardest Part?

The hardest part was making the raw data reliable. The first parser did not capture records correctly, so I inspected the TXT format and fixed the parsing logic. I also separated anomalies from clean rows and added validation checks. This made the later analytics much safer.

## 5. How Did You Validate It?

I used validation at each layer:

- Row counts and date ranges.
- Unique avatar counts.
- Duplicate checks on `avatar_id + activity_date`.
- Null checks.
- DAU greater than MAU checks.
- Retention cohort eligibility checks.
- Segment share sum checks.
- Forecast leakage checks.
- Recommendation ID and priority rank checks.

For forecasting, I used rolling-origin backtesting instead of random split.

## 6. Why Use `avatar_id` as Player Proxy?

The dataset does not include real account-level player IDs. The best available identity field is `avatar_id`. I clearly document this as a proxy. I do not claim it is real player account tracking because one person may have more than one avatar.

## 7. How Did You Define Retention?

I used exact-day cohort retention. First, I find each avatar's first seen date. Then I check if the avatar is active exactly 1, 7, 14, or 30 days later.

Example:

- 100 avatars first seen on Monday.
- 20 are active exactly 7 days later.
- D7 retention is 20%.

I also use burn-in and immature cohort rules to avoid misleading retention values.

## 8. How Did You Build Segmentation?

I created monthly snapshots. For each snapshot, I calculated features like recency, active days, observations, level gain, zone diversity, guild membership, and reactivation flags.

Then I assigned each avatar to one segment using priority logic. This makes the segment counts easy to explain and prevents double-counting.

## 9. How Did You Validate Forecasting?

I tested four simple models:

- `naive_1d`
- `moving_avg_7d`
- `seasonal_naive_7d`
- `moving_avg_30d`

I used rolling-origin backtesting. This means the model only uses past data to forecast future days. I selected the champion model by lowest sMAPE, then lowest MAE. The champion was `moving_avg_30d`.

## 10. What Would You Improve Next?

I would add:

- Patch and event calendar data.
- Marketing campaign data.
- Acquisition channel data.
- Account-level player IDs.
- Monetization data for revenue and CLV analysis.
- More advanced models after comparing them against the baseline forecast.

## CV-Ready Version

**Project: PlayerPulse LiveOps — MMORPG Player Segmentation, Retention & Forecasting Analytics**  
Independent Project | Python, SQL, DuckDB, Pandas, Streamlit, Time-Series Forecasting

- Built an end-to-end MMORPG analytics pipeline over **36M+** cleaned avatar observation rows and **91K+** avatar proxies, producing daily activity, retention, segmentation, forecasting, and recommendation marts.
- Designed D1/D7/D14/D30 exact-day cohort retention analysis with burn-in and immature cohort controls to avoid misleading early-dataset retention results.
- Created **38** monthly lifecycle snapshots and mutually exclusive player segments including Lapsed, At-Risk, Core Engaged, Fast Progressors, and Reactivated Players.
- Evaluated explainable DAU forecasting baselines with rolling-origin backtesting and converted trend alerts into **4** prioritized LiveOps recommendations for onboarding, engagement, win-back, and acquisition/content review.
