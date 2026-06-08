-- Forecasting input preparation and trend alert views for PlayerPulse LiveOps.
-- Expects DuckDB views/tables named:
--   agg_daily_metrics, agg_cohort_retention, agg_segment_monthly

CREATE OR REPLACE VIEW forecast_daily_bounds AS
SELECT
    MIN(activity_date) AS min_activity_date,
    MAX(activity_date) AS max_activity_date
FROM agg_daily_metrics
WHERE activity_date IS NOT NULL
;

CREATE OR REPLACE VIEW forecast_input_daily AS
WITH date_spine AS (
    SELECT
        generated_date::DATE AS activity_date
    FROM forecast_daily_bounds b,
         generate_series(b.min_activity_date, b.max_activity_date, INTERVAL 1 DAY) AS t(generated_date)
),
daily_deduped AS (
    SELECT
        activity_date,
        MAX(COALESCE(dau, 0)) AS dau,
        MAX(COALESCE(wau, 0)) AS wau,
        MAX(COALESCE(mau, 0)) AS mau,
        MAX(COALESCE(dau_mau_stickiness, 0)) AS dau_mau_stickiness,
        MAX(COALESCE(total_observations, 0)) AS total_observations,
        MAX(COALESCE(avg_observations_per_avatar, 0)) AS avg_observations_per_avatar,
        MAX(COALESCE(new_avatars, 0)) AS new_avatars,
        MAX(COALESCE(returning_avatars, 0)) AS returning_avatars,
        MAX(COALESCE(reactivated_avatars_30d, 0)) AS reactivated_avatars_30d
    FROM agg_daily_metrics
    WHERE activity_date IS NOT NULL
    GROUP BY 1
)
SELECT
    ds.activity_date,
    COALESCE(d.dau, 0) AS dau,
    COALESCE(d.wau, 0) AS wau,
    COALESCE(d.mau, 0) AS mau,
    COALESCE(d.dau_mau_stickiness, 0) AS dau_mau_stickiness,
    COALESCE(d.total_observations, 0) AS total_observations,
    COALESCE(d.avg_observations_per_avatar, 0) AS avg_observations_per_avatar,
    COALESCE(d.new_avatars, 0) AS new_avatars,
    COALESCE(d.returning_avatars, 0) AS returning_avatars,
    COALESCE(d.reactivated_avatars_30d, 0) AS reactivated_avatars_30d,
    EXTRACT(dow FROM ds.activity_date) AS day_of_week,
    DATE_TRUNC('week', ds.activity_date)::DATE AS week_start_date,
    DATE_TRUNC('month', ds.activity_date)::DATE AS month_start_date,
    (EXTRACT(dow FROM ds.activity_date) IN (0, 6)) AS is_weekend,
    DATE_DIFF('day', b.min_activity_date, ds.activity_date) AS days_since_start
FROM date_spine ds
CROSS JOIN forecast_daily_bounds b
LEFT JOIN daily_deduped d
    ON ds.activity_date = d.activity_date
ORDER BY ds.activity_date
;

CREATE OR REPLACE VIEW trend_daily_latest_windows AS
WITH latest_date AS (
    SELECT MAX(activity_date) AS alert_date
    FROM forecast_input_daily
),
windowed AS (
    SELECT
        l.alert_date,
        AVG(CASE
            WHEN f.activity_date BETWEEN l.alert_date - INTERVAL 6 DAY AND l.alert_date
                THEN f.dau
        END) AS current_dau_7d,
        AVG(CASE
            WHEN f.activity_date BETWEEN l.alert_date - INTERVAL 34 DAY AND l.alert_date - INTERVAL 7 DAY
                THEN f.dau
        END) AS baseline_dau_28d,
        AVG(CASE
            WHEN f.activity_date BETWEEN l.alert_date - INTERVAL 6 DAY AND l.alert_date
                THEN f.mau
        END) AS current_mau_7d,
        AVG(CASE
            WHEN f.activity_date BETWEEN l.alert_date - INTERVAL 34 DAY AND l.alert_date - INTERVAL 7 DAY
                THEN f.mau
        END) AS baseline_mau_28d,
        AVG(CASE
            WHEN f.activity_date BETWEEN l.alert_date - INTERVAL 6 DAY AND l.alert_date
                THEN f.dau_mau_stickiness
        END) AS current_stickiness_7d,
        AVG(CASE
            WHEN f.activity_date BETWEEN l.alert_date - INTERVAL 34 DAY AND l.alert_date - INTERVAL 7 DAY
                THEN f.dau_mau_stickiness
        END) AS baseline_stickiness_28d
    FROM latest_date l
    JOIN forecast_input_daily f
        ON f.activity_date BETWEEN l.alert_date - INTERVAL 34 DAY AND l.alert_date
    GROUP BY 1
)
SELECT * FROM windowed
;

CREATE OR REPLACE VIEW trend_retention_latest_windows AS
WITH eligible AS (
    SELECT
        cohort_date,
        cohort_size,
        d7_retention,
        ROW_NUMBER() OVER (ORDER BY cohort_date DESC) AS recency_rank
    FROM agg_cohort_retention
    WHERE d7_retention IS NOT NULL
),
rolled AS (
    SELECT
        MAX(CASE WHEN recency_rank <= 3 THEN cohort_date END) AS alert_date,
        AVG(CASE WHEN recency_rank <= 3 THEN d7_retention END) AS current_d7_retention_3_cohorts,
        AVG(CASE WHEN recency_rank BETWEEN 4 AND 15 THEN d7_retention END) AS baseline_d7_retention_12_cohorts,
        COUNT(CASE WHEN recency_rank <= 3 THEN 1 END) AS current_cohort_count,
        COUNT(CASE WHEN recency_rank BETWEEN 4 AND 15 THEN 1 END) AS baseline_cohort_count
    FROM eligible
    WHERE recency_rank <= 15
)
SELECT * FROM rolled
;

CREATE OR REPLACE VIEW trend_segment_latest_3mo AS
WITH latest_snapshot AS (
    SELECT MAX(snapshot_date) AS latest_snapshot_date
    FROM agg_segment_monthly
),
ranked_snapshots AS (
    SELECT
        snapshot_date,
        ROW_NUMBER() OVER (ORDER BY snapshot_date DESC) AS snapshot_rank
    FROM (
        SELECT DISTINCT snapshot_date
        FROM agg_segment_monthly
    ) snapshots
),
target_snapshots AS (
    SELECT
        MAX(CASE WHEN snapshot_rank = 1 THEN snapshot_date END) AS latest_snapshot_date,
        MAX(CASE WHEN snapshot_rank = 4 THEN snapshot_date END) AS compare_snapshot_date
    FROM ranked_snapshots
),
target_segments AS (
    SELECT 'At-Risk Players' AS lifecycle_segment
    UNION ALL SELECT 'Core Engaged'
    UNION ALL SELECT 'Lapsed Players'
),
dense AS (
    SELECT
        ts.latest_snapshot_date,
        ts.compare_snapshot_date,
        seg.lifecycle_segment,
        COALESCE(curr.segment_size, 0) AS current_segment_size,
        COALESCE(prev.segment_size, 0) AS baseline_segment_size
    FROM target_snapshots ts
    CROSS JOIN target_segments seg
    LEFT JOIN agg_segment_monthly curr
        ON curr.snapshot_date = ts.latest_snapshot_date
       AND curr.lifecycle_segment = seg.lifecycle_segment
    LEFT JOIN agg_segment_monthly prev
        ON prev.snapshot_date = ts.compare_snapshot_date
       AND prev.lifecycle_segment = seg.lifecycle_segment
)
SELECT * FROM dense
;

CREATE OR REPLACE VIEW mart_trend_alerts AS
WITH daily_alerts AS (
    SELECT
        alert_date,
        'dau_drop_7d_vs_28d' AS alert_type,
        CASE
            WHEN (current_dau_7d - baseline_dau_28d) / baseline_dau_28d <= -0.30 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'dau' AS metric_name,
        current_dau_7d AS current_value,
        baseline_dau_28d AS baseline_value,
        (current_dau_7d - baseline_dau_28d) / baseline_dau_28d AS pct_change,
        'latest 7 days vs previous 28 days' AS evidence_window,
        'Investigate recent content/event cadence and acquisition quality' AS recommended_follow_up
    FROM trend_daily_latest_windows
    WHERE baseline_dau_28d > 0
      AND (current_dau_7d - baseline_dau_28d) / baseline_dau_28d <= -0.15

    UNION ALL

    SELECT
        alert_date,
        'mau_drop_7d_vs_28d' AS alert_type,
        CASE
            WHEN (current_mau_7d - baseline_mau_28d) / baseline_mau_28d <= -0.20 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'mau' AS metric_name,
        current_mau_7d AS current_value,
        baseline_mau_28d AS baseline_value,
        (current_mau_7d - baseline_mau_28d) / baseline_mau_28d AS pct_change,
        'latest 7 days vs previous 28 days' AS evidence_window,
        'Investigate recent content/event cadence and acquisition quality' AS recommended_follow_up
    FROM trend_daily_latest_windows
    WHERE baseline_mau_28d > 0
      AND (current_mau_7d - baseline_mau_28d) / baseline_mau_28d <= -0.10

    UNION ALL

    SELECT
        alert_date,
        'stickiness_drop' AS alert_type,
        CASE
            WHEN (current_stickiness_7d - baseline_stickiness_28d) / baseline_stickiness_28d <= -0.30 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'dau_mau_stickiness' AS metric_name,
        current_stickiness_7d AS current_value,
        baseline_stickiness_28d AS baseline_value,
        (current_stickiness_7d - baseline_stickiness_28d) / baseline_stickiness_28d AS pct_change,
        'latest 7 days vs previous 28 days' AS evidence_window,
        'Review engagement loops and recent changes affecting repeat activity' AS recommended_follow_up
    FROM trend_daily_latest_windows
    WHERE baseline_stickiness_28d > 0
      AND (current_stickiness_7d - baseline_stickiness_28d) / baseline_stickiness_28d <= -0.15
),
retention_alerts AS (
    SELECT
        alert_date,
        'd7_retention_drop' AS alert_type,
        CASE
            WHEN (current_d7_retention_3_cohorts - baseline_d7_retention_12_cohorts) / baseline_d7_retention_12_cohorts <= -0.40 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'd7_retention' AS metric_name,
        current_d7_retention_3_cohorts AS current_value,
        baseline_d7_retention_12_cohorts AS baseline_value,
        (current_d7_retention_3_cohorts - baseline_d7_retention_12_cohorts) / baseline_d7_retention_12_cohorts AS pct_change,
        'latest 3 eligible cohorts vs previous 12 eligible cohorts' AS evidence_window,
        'Review onboarding and early progression experience' AS recommended_follow_up
    FROM trend_retention_latest_windows
    WHERE baseline_cohort_count = 12
      AND current_cohort_count = 3
      AND baseline_d7_retention_12_cohorts > 0
      AND (current_d7_retention_3_cohorts - baseline_d7_retention_12_cohorts) / baseline_d7_retention_12_cohorts <= -0.20
),
segment_alerts AS (
    SELECT
        latest_snapshot_date AS alert_date,
        'at_risk_segment_growth' AS alert_type,
        CASE
            WHEN (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size >= 0.40 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'at_risk_segment_size' AS metric_name,
        current_segment_size::DOUBLE AS current_value,
        baseline_segment_size::DOUBLE AS baseline_value,
        (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size AS pct_change,
        'latest segment snapshot vs 3 snapshots ago' AS evidence_window,
        'Target reactivation challenge' AS recommended_follow_up
    FROM trend_segment_latest_3mo
    WHERE lifecycle_segment = 'At-Risk Players'
      AND baseline_segment_size > 0
      AND (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size >= 0.20

    UNION ALL

    SELECT
        latest_snapshot_date AS alert_date,
        'core_engaged_decline' AS alert_type,
        CASE
            WHEN (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size <= -0.30 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'core_engaged_segment_size' AS metric_name,
        current_segment_size::DOUBLE AS current_value,
        baseline_segment_size::DOUBLE AS baseline_value,
        (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size AS pct_change,
        'latest segment snapshot vs 3 snapshots ago' AS evidence_window,
        'Review endgame/event engagement' AS recommended_follow_up
    FROM trend_segment_latest_3mo
    WHERE lifecycle_segment = 'Core Engaged'
      AND baseline_segment_size > 0
      AND (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size <= -0.15

    UNION ALL

    SELECT
        latest_snapshot_date AS alert_date,
        'lapsed_growth' AS alert_type,
        CASE
            WHEN (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size >= 0.30 THEN 'high'
            ELSE 'medium'
        END AS severity,
        'lapsed_segment_size' AS metric_name,
        current_segment_size::DOUBLE AS current_value,
        baseline_segment_size::DOUBLE AS baseline_value,
        (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size AS pct_change,
        'latest segment snapshot vs 3 snapshots ago' AS evidence_window,
        'Win-back campaign' AS recommended_follow_up
    FROM trend_segment_latest_3mo
    WHERE lifecycle_segment = 'Lapsed Players'
      AND baseline_segment_size > 0
      AND (current_segment_size - baseline_segment_size)::DOUBLE / baseline_segment_size >= 0.15
)
SELECT * FROM daily_alerts
UNION ALL
SELECT * FROM retention_alerts
UNION ALL
SELECT * FROM segment_alerts
ORDER BY alert_date DESC, severity DESC, alert_type
;
