-- Final LiveOps recommendation and dashboard summary marts.
-- Expects DuckDB views/tables named:
--   agg_daily_metrics, agg_cohort_retention, agg_segment_monthly,
--   mart_player_segments, mart_forecast_daily, mart_forecast_backtest,
--   mart_trend_alerts

CREATE OR REPLACE VIEW liveops_latest_activity AS
SELECT *
FROM agg_daily_metrics
QUALIFY ROW_NUMBER() OVER (ORDER BY activity_date DESC) = 1
;

CREATE OR REPLACE VIEW liveops_forecast_model_metrics AS
SELECT
    model_name,
    AVG(abs_error) AS mae,
    SQRT(AVG(squared_error)) AS rmse,
    AVG(CASE WHEN actual_dau <> 0 THEN ABS((forecast_dau - actual_dau) / actual_dau) END) AS mape,
    AVG(CASE
        WHEN ABS(actual_dau) + ABS(forecast_dau) <> 0
            THEN 2 * ABS(forecast_dau - actual_dau) / (ABS(actual_dau) + ABS(forecast_dau))
    END) AS smape,
    AVG(error) AS bias
FROM mart_forecast_backtest
GROUP BY 1
;

CREATE OR REPLACE VIEW liveops_champion_model AS
SELECT
    f.model_name,
    m.mae,
    m.rmse,
    m.mape,
    m.smape,
    m.bias
FROM (
    SELECT DISTINCT model_name
    FROM mart_forecast_daily
    WHERE is_champion_model
) f
LEFT JOIN liveops_forecast_model_metrics m
    ON f.model_name = m.model_name
;

CREATE OR REPLACE VIEW mart_liveops_recommendations AS
WITH ranked_alerts AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                CASE severity WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
                ABS(pct_change) DESC,
                alert_date DESC,
                alert_type
        ) AS priority_rank,
        alert_date::DATE AS recommendation_date,
        severity,
        alert_type,
        metric_name,
        current_value,
        baseline_value,
        pct_change,
        recommended_follow_up
    FROM mart_trend_alerts
),
mapped AS (
    SELECT
        priority_rank,
        recommendation_date,
        severity,
        CASE alert_type
            WHEN 'd7_retention_drop' THEN 'New Explorers'
            WHEN 'core_engaged_decline' THEN 'Core Engaged'
            WHEN 'lapsed_growth' THEN 'Lapsed Players'
            WHEN 'mau_drop_7d_vs_28d' THEN 'Broad active player base'
            WHEN 'dau_drop_7d_vs_28d' THEN 'Daily active player base'
            WHEN 'stickiness_drop' THEN 'Repeat active player base'
            WHEN 'at_risk_segment_growth' THEN 'At-Risk Players'
            ELSE 'All players'
        END AS target_segment,
        CASE alert_type
            WHEN 'd7_retention_drop' THEN 'D7 retention dropped versus recent cohort baseline'
            WHEN 'core_engaged_decline' THEN 'Core Engaged segment declined versus 3 snapshots ago'
            WHEN 'lapsed_growth' THEN 'Lapsed Players segment grew versus 3 snapshots ago'
            WHEN 'mau_drop_7d_vs_28d' THEN 'MAU trend dropped versus previous 28-day baseline'
            WHEN 'dau_drop_7d_vs_28d' THEN 'DAU trend dropped versus previous 28-day baseline'
            WHEN 'stickiness_drop' THEN 'DAU/MAU stickiness dropped versus previous 28-day baseline'
            WHEN 'at_risk_segment_growth' THEN 'At-Risk Players segment grew versus 3 snapshots ago'
            ELSE 'Trend alert triggered'
        END AS issue_detected,
        metric_name AS evidence_metric,
        current_value,
        baseline_value,
        pct_change,
        CASE alert_type
            WHEN 'd7_retention_drop' THEN 'Onboarding / early progression review'
            WHEN 'core_engaged_decline' THEN 'Endgame content and event engagement review'
            WHEN 'lapsed_growth' THEN 'Win-back campaign'
            WHEN 'mau_drop_7d_vs_28d' THEN 'Acquisition quality and content cadence review'
            WHEN 'dau_drop_7d_vs_28d' THEN 'Activity cadence and acquisition quality review'
            WHEN 'stickiness_drop' THEN 'Daily engagement loop review'
            WHEN 'at_risk_segment_growth' THEN 'Targeted reactivation challenge'
            ELSE COALESCE(recommended_follow_up, 'Review triggered LiveOps alert')
        END AS recommended_action,
        CASE alert_type
            WHEN 'd7_retention_drop' THEN 'Increase early repeat activity and D7 retention'
            WHEN 'core_engaged_decline' THEN 'Stabilize highly engaged player activity'
            WHEN 'lapsed_growth' THEN 'Reduce lapsed population and increase returning avatars'
            WHEN 'mau_drop_7d_vs_28d' THEN 'Stabilize monthly active player base'
            WHEN 'dau_drop_7d_vs_28d' THEN 'Stabilize daily active player base'
            WHEN 'stickiness_drop' THEN 'Improve DAU/MAU stickiness'
            WHEN 'at_risk_segment_growth' THEN 'Reduce at-risk player share'
            ELSE 'Improve player engagement health'
        END AS expected_impact_direction,
        CASE alert_type
            WHEN 'd7_retention_drop' THEN 'Early retention is a leading indicator of future active player supply; improving onboarding can lift downstream DAU and cohort value.'
            WHEN 'core_engaged_decline' THEN 'Core Engaged players are the most active non-monetary engagement base; decline here can weaken event participation and community activity.'
            WHEN 'lapsed_growth' THEN 'A growing lapsed segment indicates more avatars are leaving the active base; win-back offers can recover addressable inactive players.'
            WHEN 'mau_drop_7d_vs_28d' THEN 'MAU decline indicates a broad engagement slowdown; reviewing acquisition quality and content cadence helps identify supply or activity issues.'
            WHEN 'dau_drop_7d_vs_28d' THEN 'DAU decline is an immediate activity signal; content cadence and acquisition quality are first-order operational checks.'
            WHEN 'stickiness_drop' THEN 'Stickiness decline means fewer monthly players are active daily; daily loops should be reviewed for repeat engagement friction.'
            WHEN 'at_risk_segment_growth' THEN 'At-Risk growth shows previously active players are slowing down; targeted challenges can intervene before they lapse.'
            ELSE 'Triggered trend alerts require LiveOps review before they become larger player-health issues.'
        END AS business_rationale,
        alert_type AS source_alert_type
    FROM ranked_alerts
)
SELECT
    'REC-' || STRFTIME(recommendation_date, '%Y%m%d') || '-' || LPAD(priority_rank::VARCHAR, 3, '0') AS recommendation_id,
    recommendation_date,
    priority_rank,
    severity,
    target_segment,
    issue_detected,
    evidence_metric,
    current_value,
    baseline_value,
    pct_change,
    recommended_action,
    expected_impact_direction,
    business_rationale,
    source_alert_type
FROM mapped
ORDER BY priority_rank
;

CREATE OR REPLACE VIEW dashboard_kpi_summary AS
WITH latest AS (
    SELECT * FROM liveops_latest_activity
),
last_30 AS (
    SELECT
        AVG(dau) AS avg_dau_30d,
        AVG(mau) AS avg_mau_30d
    FROM agg_daily_metrics
    WHERE activity_date BETWEEN (SELECT activity_date FROM latest) - INTERVAL 29 DAY
                            AND (SELECT activity_date FROM latest)
),
forecast AS (
    SELECT
        AVG(forecast_value) AS latest_forecast_30d_avg_dau
    FROM mart_forecast_daily
    WHERE is_champion_model
),
alerts AS (
    SELECT
        COUNT(*) AS active_alert_count,
        SUM(CASE WHEN severity = 'high' THEN 1 ELSE 0 END) AS high_alert_count
    FROM mart_trend_alerts
)
SELECT
    l.activity_date AS latest_activity_date,
    l.dau AS latest_dau,
    l.wau AS latest_wau,
    l.mau AS latest_mau,
    l.dau_mau_stickiness AS latest_stickiness,
    r.avg_dau_30d,
    r.avg_mau_30d,
    f.latest_forecast_30d_avg_dau,
    a.active_alert_count,
    a.high_alert_count
FROM latest l
CROSS JOIN last_30 r
CROSS JOIN forecast f
CROSS JOIN alerts a
;

CREATE OR REPLACE VIEW dashboard_retention_summary AS
WITH eligible AS (
    SELECT *
    FROM agg_cohort_retention
    WHERE d1_retention IS NOT NULL
       OR d7_retention IS NOT NULL
       OR d14_retention IS NOT NULL
       OR d30_retention IS NOT NULL
),
overall AS (
    SELECT
        AVG(d1_retention) AS average_d1_retention,
        AVG(d7_retention) AS average_d7_retention,
        AVG(d14_retention) AS average_d14_retention,
        AVG(d30_retention) AS average_d30_retention
    FROM eligible
),
latest AS (
    SELECT
        cohort_date AS latest_eligible_cohort_date,
        d1_retention AS latest_d1_retention,
        d7_retention AS latest_d7_retention,
        d14_retention AS latest_d14_retention,
        d30_retention AS latest_d30_retention
    FROM eligible
    QUALIFY ROW_NUMBER() OVER (ORDER BY cohort_date DESC) = 1
),
trend AS (
    SELECT
        cohort_date,
        cohort_size,
        d1_retention,
        d7_retention,
        d14_retention,
        d30_retention,
        AVG(d7_retention) OVER (
            ORDER BY cohort_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS d7_retention_30_cohort_avg,
        d7_retention - LAG(d7_retention, 30) OVER (ORDER BY cohort_date) AS d7_retention_change_vs_30_cohorts_ago
    FROM eligible
)
SELECT
    t.cohort_date,
    t.cohort_size,
    t.d1_retention,
    t.d7_retention,
    t.d14_retention,
    t.d30_retention,
    o.average_d1_retention,
    o.average_d7_retention,
    o.average_d14_retention,
    o.average_d30_retention,
    l.latest_eligible_cohort_date,
    l.latest_d1_retention,
    l.latest_d7_retention,
    l.latest_d14_retention,
    l.latest_d30_retention,
    t.d7_retention_30_cohort_avg,
    t.d7_retention_change_vs_30_cohorts_ago
FROM trend t
CROSS JOIN overall o
CROSS JOIN latest l
ORDER BY t.cohort_date
;

CREATE OR REPLACE VIEW dashboard_segment_summary AS
WITH latest_snapshot AS (
    SELECT MAX(snapshot_date) AS snapshot_date
    FROM agg_segment_monthly
),
ranked_snapshots AS (
    SELECT
        snapshot_date,
        ROW_NUMBER() OVER (ORDER BY snapshot_date DESC) AS snapshot_rank
    FROM (
        SELECT DISTINCT snapshot_date
        FROM agg_segment_monthly
    ) s
),
compare_snapshot AS (
    SELECT snapshot_date
    FROM ranked_snapshots
    WHERE snapshot_rank = 4
),
latest AS (
    SELECT s.*
    FROM agg_segment_monthly s
    JOIN latest_snapshot l
        ON s.snapshot_date = l.snapshot_date
),
previous AS (
    SELECT s.*
    FROM agg_segment_monthly s
    JOIN compare_snapshot c
        ON s.snapshot_date = c.snapshot_date
),
addressable AS (
    SELECT SUM(segment_size) AS addressable_total
    FROM latest
    WHERE lifecycle_segment <> 'Lapsed Players'
),
joined AS (
    SELECT
        l.snapshot_date,
        l.lifecycle_segment,
        l.segment_size,
        l.segment_share,
        CASE
            WHEN l.lifecycle_segment <> 'Lapsed Players' AND a.addressable_total > 0
                THEN l.segment_size::DOUBLE / a.addressable_total
        END AS addressable_segment_share,
        COALESCE(p.segment_size, 0) AS segment_size_3mo_ago,
        l.segment_size - COALESCE(p.segment_size, 0) AS segment_size_change_3mo,
        CASE
            WHEN COALESCE(p.segment_size, 0) > 0
                THEN (l.segment_size - p.segment_size)::DOUBLE / p.segment_size
        END AS segment_pct_change_3mo,
        l.avg_recency_days,
        l.avg_active_days_30,
        l.avg_observations_30,
        l.avg_level_current,
        l.avg_level_gain_30,
        l.guild_member_share,
        l.fast_progressor_share,
        l.reactivated_share
    FROM latest l
    CROSS JOIN addressable a
    LEFT JOIN previous p
        ON l.lifecycle_segment = p.lifecycle_segment
),
markers AS (
    SELECT
        (SELECT lifecycle_segment FROM joined ORDER BY segment_size DESC, lifecycle_segment LIMIT 1) AS largest_segment,
        (SELECT lifecycle_segment FROM joined ORDER BY segment_size_change_3mo DESC, lifecycle_segment LIMIT 1) AS fastest_growing_segment,
        (SELECT lifecycle_segment FROM joined ORDER BY segment_size_change_3mo ASC, lifecycle_segment LIMIT 1) AS fastest_shrinking_segment
)
SELECT
    j.*,
    m.largest_segment,
    m.fastest_growing_segment,
    m.fastest_shrinking_segment
FROM joined j
CROSS JOIN markers m
ORDER BY j.segment_size DESC, j.lifecycle_segment
;

CREATE OR REPLACE VIEW dashboard_forecast_summary AS
WITH range_summary AS (
    SELECT
        MIN(forecast_date) AS final_forecast_start_date,
        MAX(forecast_date) AS final_forecast_end_date,
        AVG(forecast_value) AS average_forecast_dau_30d,
        MIN(lower_bound_simple) AS min_lower_bound_simple,
        MAX(upper_bound_simple) AS max_upper_bound_simple
    FROM mart_forecast_daily
    WHERE is_champion_model
)
SELECT
    f.forecast_created_at,
    f.forecast_date,
    f.model_name AS champion_model,
    c.mae AS champion_mae,
    c.rmse AS champion_rmse,
    c.mape AS champion_mape,
    c.smape AS champion_smape,
    c.bias AS champion_bias,
    r.final_forecast_start_date,
    r.final_forecast_end_date,
    r.average_forecast_dau_30d,
    f.forecast_value,
    f.lower_bound_simple,
    f.upper_bound_simple
FROM mart_forecast_daily f
LEFT JOIN liveops_champion_model c
    ON f.model_name = c.model_name
CROSS JOIN range_summary r
WHERE f.is_champion_model
ORDER BY f.forecast_date
;
