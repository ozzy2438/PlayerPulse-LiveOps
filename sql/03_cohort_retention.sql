-- Cohort retention views for WoWAH player activity.
-- Expects a DuckDB view or table named fct_player_daily to already exist.

CREATE OR REPLACE VIEW cohort_dataset_bounds AS
SELECT
    MIN(activity_date) AS min_activity_date,
    MAX(activity_date) AS max_activity_date
FROM fct_player_daily
WHERE avatar_id IS NOT NULL
  AND activity_date IS NOT NULL
;

CREATE OR REPLACE VIEW cohort_first_seen AS
SELECT
    avatar_id,
    MIN(activity_date) AS first_seen_date
FROM fct_player_daily
WHERE avatar_id IS NOT NULL
  AND activity_date IS NOT NULL
GROUP BY 1
;

CREATE OR REPLACE VIEW cohort_sizes AS
SELECT
    first_seen_date AS cohort_date,
    COUNT(*) AS cohort_size
FROM cohort_first_seen
GROUP BY 1
;

CREATE OR REPLACE VIEW cohort_avatar_daily AS
SELECT
    f.avatar_id,
    fs.first_seen_date AS cohort_date,
    f.activity_date,
    DATE_DIFF('day', fs.first_seen_date, f.activity_date) AS cohort_age_day,
    f.observations_count,
    f.level_gain_day
FROM fct_player_daily f
JOIN cohort_first_seen fs
    USING (avatar_id)
WHERE f.avatar_id IS NOT NULL
  AND f.activity_date IS NOT NULL
  AND f.activity_date >= fs.first_seen_date
;

CREATE OR REPLACE VIEW cohort_window_7d AS
WITH avatar_window_7d AS (
    SELECT
        fs.first_seen_date AS cohort_date,
        fs.avatar_id,
        COUNT(f.activity_date) AS active_days_7d,
        SUM(COALESCE(f.observations_count, 0)) AS observations_7d,
        SUM(COALESCE(f.level_gain_day, 0)) AS level_gain_7d
    FROM cohort_first_seen fs
    LEFT JOIN fct_player_daily f
        ON fs.avatar_id = f.avatar_id
       AND f.activity_date BETWEEN fs.first_seen_date AND fs.first_seen_date + INTERVAL 6 DAY
    GROUP BY 1, 2
)
SELECT
    cohort_date,
    AVG(level_gain_7d * 1.0) AS avg_level_gain_7d,
    AVG(active_days_7d * 1.0) AS avg_active_days_7d,
    AVG(observations_7d * 1.0) AS avg_observations_7d
FROM avatar_window_7d
GROUP BY 1
;

CREATE OR REPLACE VIEW cohort_retention_curve_unfiltered AS
WITH curve_counts AS (
    SELECT
        cohort_date,
        cohort_age_day,
        COUNT(DISTINCT avatar_id) AS retained_avatars
    FROM cohort_avatar_daily
    WHERE cohort_age_day >= 0
    GROUP BY 1, 2
),
cohort_age_grid AS (
    SELECT
        cs.cohort_date,
        gs.cohort_age_day,
        cs.cohort_size
    FROM cohort_sizes cs
    CROSS JOIN cohort_dataset_bounds bounds
    CROSS JOIN LATERAL generate_series(
        0,
        DATE_DIFF('day', cs.cohort_date, bounds.max_activity_date),
        1
    ) AS gs(cohort_age_day)
    WHERE cs.cohort_size > 0
)
SELECT
    cag.cohort_date,
    cag.cohort_age_day,
    cag.cohort_size,
    COALESCE(cc.retained_avatars, 0) AS retained_avatars,
    COALESCE(cc.retained_avatars, 0) * 1.0 / cag.cohort_size AS retention_rate
FROM cohort_age_grid cag
LEFT JOIN curve_counts cc
    USING (cohort_date, cohort_age_day)
;

CREATE OR REPLACE VIEW cohort_retention_summary_model AS
WITH retention_pivots AS (
    SELECT
        cohort_date,
        COUNT(DISTINCT CASE WHEN cohort_age_day = 1 THEN avatar_id ELSE NULL END) AS retained_d1,
        COUNT(DISTINCT CASE WHEN cohort_age_day = 7 THEN avatar_id ELSE NULL END) AS retained_d7,
        COUNT(DISTINCT CASE WHEN cohort_age_day = 14 THEN avatar_id ELSE NULL END) AS retained_d14,
        COUNT(DISTINCT CASE WHEN cohort_age_day = 30 THEN avatar_id ELSE NULL END) AS retained_d30
    FROM cohort_avatar_daily
    GROUP BY 1
),
cohort_flags AS (
    SELECT
        cs.cohort_date,
        cs.cohort_size,
        bounds.min_activity_date,
        bounds.max_activity_date,
        cs.cohort_date >= bounds.min_activity_date + INTERVAL 30 DAY AS passes_burn_in,
        cs.cohort_date + INTERVAL 1 DAY <= bounds.max_activity_date AS eligible_d1,
        cs.cohort_date + INTERVAL 7 DAY <= bounds.max_activity_date AS eligible_d7,
        cs.cohort_date + INTERVAL 14 DAY <= bounds.max_activity_date AS eligible_d14,
        cs.cohort_date + INTERVAL 30 DAY <= bounds.max_activity_date AS eligible_d30,
        cs.cohort_date + INTERVAL 6 DAY <= bounds.max_activity_date AS eligible_7d_window
    FROM cohort_sizes cs
    CROSS JOIN cohort_dataset_bounds bounds
    WHERE cs.cohort_size > 0
)
SELECT
    cf.cohort_date,
    cf.cohort_size,
    CASE WHEN cf.eligible_d1 THEN COALESCE(rp.retained_d1, 0) ELSE NULL END AS retained_d1,
    CASE WHEN cf.eligible_d7 THEN COALESCE(rp.retained_d7, 0) ELSE NULL END AS retained_d7,
    CASE WHEN cf.eligible_d14 THEN COALESCE(rp.retained_d14, 0) ELSE NULL END AS retained_d14,
    CASE WHEN cf.eligible_d30 THEN COALESCE(rp.retained_d30, 0) ELSE NULL END AS retained_d30,
    CASE
        WHEN cf.eligible_d1 THEN COALESCE(rp.retained_d1, 0) * 1.0 / cf.cohort_size
        ELSE NULL
    END AS d1_retention,
    CASE
        WHEN cf.eligible_d7 THEN COALESCE(rp.retained_d7, 0) * 1.0 / cf.cohort_size
        ELSE NULL
    END AS d7_retention,
    CASE
        WHEN cf.eligible_d14 THEN COALESCE(rp.retained_d14, 0) * 1.0 / cf.cohort_size
        ELSE NULL
    END AS d14_retention,
    CASE
        WHEN cf.eligible_d30 THEN COALESCE(rp.retained_d30, 0) * 1.0 / cf.cohort_size
        ELSE NULL
    END AS d30_retention,
    CASE WHEN cf.eligible_7d_window THEN cw.avg_level_gain_7d ELSE NULL END AS avg_level_gain_7d,
    CASE WHEN cf.eligible_7d_window THEN cw.avg_active_days_7d ELSE NULL END AS avg_active_days_7d,
    CASE WHEN cf.eligible_7d_window THEN cw.avg_observations_7d ELSE NULL END AS avg_observations_7d,
    cf.passes_burn_in,
    cf.eligible_d1,
    cf.eligible_d7,
    cf.eligible_d14,
    cf.eligible_d30,
    cf.eligible_7d_window
FROM cohort_flags cf
LEFT JOIN retention_pivots rp
    USING (cohort_date)
LEFT JOIN cohort_window_7d cw
    USING (cohort_date)
;

CREATE OR REPLACE VIEW agg_cohort_retention AS
SELECT
    cohort_date,
    cohort_size,
    retained_d1,
    retained_d7,
    retained_d14,
    retained_d30,
    d1_retention,
    d7_retention,
    d14_retention,
    d30_retention,
    avg_level_gain_7d,
    avg_active_days_7d,
    avg_observations_7d
FROM cohort_retention_summary_model
WHERE passes_burn_in
ORDER BY 1
;

CREATE OR REPLACE VIEW agg_retention_curve AS
SELECT
    rc.cohort_date,
    rc.cohort_age_day,
    rc.cohort_size,
    rc.retained_avatars,
    rc.retention_rate
FROM cohort_retention_curve_unfiltered rc
CROSS JOIN cohort_dataset_bounds bounds
WHERE rc.cohort_date >= bounds.min_activity_date + INTERVAL 30 DAY
ORDER BY 1, 2
;
