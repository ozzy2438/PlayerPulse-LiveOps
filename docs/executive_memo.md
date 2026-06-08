# Executive Memo

## 1. Executive Summary

PlayerPulse LiveOps turns historical MMORPG avatar activity into a practical player health monitoring system. The project measures activity, retention, lifecycle segments, DAU forecasts, trend alerts, and recommended LiveOps actions.

The latest view shows pressure in the active player base: lapsed avatars are the largest segment, D7 retention has dropped versus recent cohort baselines, and the Core Engaged segment declined in the latest 3-month comparison.

## 2. What We Measured

The project measured:

- Daily active, weekly active, and monthly active avatars.
- DAU/MAU stickiness.
- New, returning, and reactivated avatars.
- D1/D7/D14/D30 cohort retention.
- Monthly lifecycle segments.
- 30-day DAU forecast.
- Trend alerts and LiveOps recommendations.

`avatar_id` is used as a player proxy because account-level user IDs are not available.

## 3. Key Findings

- The latest DAU is **881**.
- The latest MAU is **7,499**.
- The latest DAU/MAU stickiness is **11.75%**.
- The 30-day average DAU is **1,855**.
- The largest segment is `Lapsed Players`, with **83,459** avatars.
- There are **4** active LiveOps recommendations.

## 4. Player Retention Health

Average retention:

- D1 retention: **28.62%**
- D7 retention: **12.48%**
- D14 retention: **9.12%**
- D30 retention: **6.41%**

The latest alert shows a high-severity D7 retention drop. This means recent cohorts are returning less often after one week compared with the recent baseline.

Decision implication: onboarding and early progression should be reviewed first.

## 5. Segment Health

The latest segment snapshot shows:

- `Lapsed Players`: **83,459**
- `Low Activity / Other`: **2,368**
- `Core Engaged`: **1,911**
- `Casual Returners`: **1,814**
- `At-Risk Players`: **535**

The largest growth over the latest 3-month comparison is in `Lapsed Players`. The `Core Engaged` segment declined by **948** avatars.

Decision implication: protect highly engaged players while also planning a win-back campaign.

## 6. Forecast Outlook

The champion baseline forecast model is `moving_avg_30d`.

Forecast summary:

- Forecast window: `2009-01-11` to `2009-02-09`
- Average forecast DAU: **1,855**
- MAE: **267**
- sMAPE: **17.36%**

This is a simple baseline forecast, not a final production ML forecast.

## 7. LiveOps Recommendations

Top recommendations:

1. **Onboarding / early progression review** for D7 retention decline.
2. **Endgame content and event engagement review** for Core Engaged decline.
3. **Win-back campaign** for Lapsed Players growth.
4. **Acquisition quality and content cadence review** for MAU decline.

## 8. Risks and Limitations

- `avatar_id` is a proxy and not a real account-level player ID.
- No revenue or monetization data is available.
- No marketing, patch, or event calendar is available.
- Observations are not full session telemetry.
- Some level progression anomalies exist and are documented.

## 9. Suggested Next Steps

- Review onboarding and early progression friction.
- Investigate why Core Engaged avatars declined.
- Design a win-back campaign for lapsed avatars.
- Add patch/event/marketing calendar data before using advanced forecasting.
- Add monetization data if payer behavior or CLV analysis becomes a goal.
