# Metric Dictionary

This dictionary explains the main metrics used in PlayerPulse LiveOps. The dataset does not contain real account-level player IDs, so `avatar_id` is used as a player proxy throughout the project.

## Identity and Time

### `avatar_id`

- **Definition:** Unique avatar identifier in the WoWAH dataset.
- **Why it matters:** It is the closest available proxy for a player identity.
- **Example:** If `avatar_id = 123` appears on three different days, the project treats this as one avatar active on three days.
- **Limitation:** One real person may have multiple avatars. This is not verified account-level tracking.

### `observed_at`

- **Definition:** Timestamp when an avatar observation was recorded.
- **Why it matters:** It is used to build daily activity and player history.
- **Example:** `2007-04-04 12:30:00` means the avatar was observed at that time.
- **Limitation:** Observations are not the same as full session logs.

## Activity Metrics

### DAU

- **Definition:** Daily Active Avatars; count of distinct `avatar_id` values active on a calendar day.
- **Why it matters:** It is the main short-term activity health metric.
- **Example:** If 1,000 unique avatars are active on Monday, DAU is 1,000.
- **Limitation:** Avatar-level, not account-level.

### WAU

- **Definition:** Weekly Active Avatars; count of distinct avatars active in the latest 7-day window.
- **Why it matters:** It smooths daily noise and shows weekly reach.
- **Limitation:** A highly active avatar and a one-time active avatar both count once.

### MAU

- **Definition:** Monthly Active Avatars; count of distinct avatars active in the latest 30-day window.
- **Why it matters:** It measures broader active reach.
- **Limitation:** It does not measure engagement depth by itself.

### DAU/MAU Stickiness

- **Definition:** `DAU / MAU`.
- **Why it matters:** Shows what share of monthly active avatars are active on a given day.
- **Example:** DAU 1,000 and MAU 10,000 gives stickiness of 10%.
- **Limitation:** Strongly affected by acquisition spikes and seasonal behavior.

### New Avatars

- **Definition:** Avatars whose first seen date equals the activity date.
- **Why it matters:** Proxy for new avatar inflow.
- **Limitation:** Existing players with new avatars may appear as new.

### Returning Avatars

- **Definition:** Avatars active after a previous activity gap of 1 to 30 days.
- **Why it matters:** Measures repeat activity from recently active avatars.
- **Limitation:** Does not prove the same real person returned if multiple avatars exist.

### Reactivated Avatars

- **Definition:** Avatars active after a previous activity gap greater than 30 days.
- **Why it matters:** Useful for win-back and reactivation monitoring.
- **Limitation:** Long gaps may reflect missing observation periods, not only player behavior.

## Retention Metrics

### Cohort

- **Definition:** Group of avatars with the same `first_seen_date`.
- **Why it matters:** Cohorts make retention comparable across acquisition periods.
- **Example:** All avatars first seen on `2007-04-03` are one cohort.
- **Limitation:** First seen date is based on dataset coverage, not true account creation.

### D1 Retention

- **Definition:** Share of cohort avatars active exactly 1 day after cohort date.
- **Why it matters:** Early signal for onboarding quality.
- **Example:** 100 new avatars, 30 active exactly next day: D1 retention is 30%.

### D7 Retention

- **Definition:** Share of cohort avatars active exactly 7 days after cohort date.
- **Why it matters:** Indicates whether early engagement lasts beyond the first week.

### D14 Retention

- **Definition:** Share of cohort avatars active exactly 14 days after cohort date.
- **Why it matters:** Shows medium-term retention health.

### D30 Retention

- **Definition:** Share of cohort avatars active exactly 30 days after cohort date.
- **Why it matters:** Common long-term retention indicator.

### Exact-Day Retention

- **Definition:** Retention counted only if the avatar is active on the exact target day.
- **Why it matters:** Keeps retention definitions strict and comparable.
- **Limitation:** It does not count avatars active on day 6 or day 8 for D7.

### Burn-In Period

- **Definition:** First 30 days of the dataset excluded from final retention summaries.
- **Why it matters:** Avoids treating already-existing avatars as truly new.
- **Limitation:** Reduces early data coverage.

### Immature Cohorts

- **Definition:** Cohorts too recent to have reached D1/D7/D14/D30.
- **Why it matters:** Prevents calculating retention before enough time has passed.
- **Example:** A cohort from yesterday cannot have D7 retention yet.

## Lifecycle and Engagement Metrics

### `recency_days`

- **Definition:** Days between latest activity and snapshot date.
- **Why it matters:** Key indicator of whether an avatar is active, cooling down, or lapsed.

### `active_days_7`

- **Definition:** Number of distinct active days in the latest 7-day window.
- **Why it matters:** Measures recent engagement frequency.

### `active_days_30`

- **Definition:** Number of distinct active days in the latest 30-day window.
- **Why it matters:** Measures monthly engagement depth.

### Lapsed Player

- **Definition:** Avatar with `recency_days > 30`.
- **Why it matters:** Candidate for win-back strategy.
- **Limitation:** The dataset cannot confirm why the avatar stopped appearing.

### Reactivated Player

- **Definition:** Avatar active recently after a previous activity gap greater than 30 days.
- **Why it matters:** Useful group for return reinforcement campaigns.

### At-Risk Player

- **Definition:** Avatar with recent inactivity or a sharp activity drop after previous activity.
- **Why it matters:** Good target for reactivation before lapsing.

### Core Engaged Player

- **Definition:** Avatar with high recent active days or high observation volume.
- **Why it matters:** Represents the most engaged activity base.

### Engagement Proxy

- **Definition:** Non-revenue indicators such as active days, observations, level gain, zone diversity, and guild participation.
- **Why it matters:** The dataset has no revenue data, so engagement value must be inferred from behavior.
- **Limitation:** Engagement proxy is not the same as monetization or customer value.

## Forecasting and Alert Metrics

### Trend Alert

- **Definition:** Rule-based signal showing an important drop or growth pattern.
- **Why it matters:** Converts analytics into operational follow-up.
- **Example:** D7 retention drops 20% below recent baseline.

### Forecast Horizon

- **Definition:** Future period being forecast; this project forecasts 30 days of DAU.
- **Why it matters:** Sets the planning window for LiveOps monitoring.

### MAE

- **Definition:** Mean Absolute Error; average absolute difference between forecast and actual.
- **Why it matters:** Easy to understand in DAU units.
- **Example:** MAE 267 means average forecast error is about 267 avatars.

### RMSE

- **Definition:** Root Mean Squared Error; gives more weight to large errors.
- **Why it matters:** Helps detect models that make occasional big mistakes.

### MAPE

- **Definition:** Mean Absolute Percentage Error.
- **Why it matters:** Shows relative forecast error as a percentage.
- **Limitation:** Undefined when actual value is zero; zero actual rows are excluded.

### sMAPE

- **Definition:** Symmetric Mean Absolute Percentage Error.
- **Why it matters:** More stable than MAPE when values vary.
- **Limitation:** Still needs careful handling when actual and forecast are both zero.
