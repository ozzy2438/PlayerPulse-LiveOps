-- Monthly player lifecycle features and segmentation views for WoWAH.
-- Expects a DuckDB view or table named fct_player_daily to already exist.

CREATE OR REPLACE VIEW lifecycle_dataset_bounds AS
SELECT
    MIN(activity_date) AS min_activity_date,
    MAX(activity_date) AS max_activity_date
FROM fct_player_daily
WHERE avatar_id IS NOT NULL
  AND activity_date IS NOT NULL
;

CREATE OR REPLACE VIEW lifecycle_monthly_snapshots AS
WITH month_end_snapshots AS (
    SELECT
        DATE_TRUNC('month', activity_date) AS snapshot_month,
        MAX(activity_date) AS snapshot_date
    FROM fct_player_daily
    WHERE avatar_id IS NOT NULL
      AND activity_date IS NOT NULL
    GROUP BY 1
),
final_snapshot AS (
    SELECT
        DATE_TRUNC('month', max_activity_date) AS snapshot_month,
        max_activity_date AS snapshot_date
    FROM lifecycle_dataset_bounds
)
SELECT DISTINCT
    snapshot_month,
    snapshot_date
FROM (
    SELECT * FROM month_end_snapshots
    UNION ALL
    SELECT * FROM final_snapshot
) snapshots
ORDER BY snapshot_date
;

CREATE OR REPLACE VIEW lifecycle_avatar_bounds AS
SELECT
    avatar_id,
    MIN(activity_date) AS first_seen_date,
    MAX(activity_date) AS last_seen_date
FROM fct_player_daily
WHERE avatar_id IS NOT NULL
  AND activity_date IS NOT NULL
GROUP BY 1
;

CREATE OR REPLACE VIEW lifecycle_avatar_activity_with_prev AS
SELECT
    avatar_id,
    activity_date,
    last_seen_at_that_day,
    observations_count,
    level_end,
    level_max,
    level_gain_day,
    primary_zone,
    guild_id_latest,
    guild_member_flag_latest,
    LAG(activity_date) OVER (
        PARTITION BY avatar_id
        ORDER BY activity_date
    ) AS previous_activity_date
FROM fct_player_daily
WHERE avatar_id IS NOT NULL
  AND activity_date IS NOT NULL
;

CREATE OR REPLACE VIEW lifecycle_snapshot_avatar_base AS
SELECT
    s.snapshot_date,
    a.avatar_id,
    a.first_seen_date
FROM lifecycle_monthly_snapshots s
JOIN lifecycle_avatar_bounds a
    ON a.first_seen_date <= s.snapshot_date
;

CREATE OR REPLACE VIEW lifecycle_snapshot_recent_windows AS
SELECT
    sab.snapshot_date,
    sab.avatar_id,
    COUNT(DISTINCT CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 6 DAY AND sab.snapshot_date
            THEN f.activity_date
        ELSE NULL
    END) AS active_days_7,
    COUNT(DISTINCT CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 29 DAY AND sab.snapshot_date
            THEN f.activity_date
        ELSE NULL
    END) AS active_days_30,
    COUNT(DISTINCT CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 59 DAY AND sab.snapshot_date - INTERVAL 30 DAY
            THEN f.activity_date
        ELSE NULL
    END) AS active_days_prev_30,
    SUM(CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 6 DAY AND sab.snapshot_date
            THEN COALESCE(f.observations_count, 0)
        ELSE 0
    END) AS observations_7,
    SUM(CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 29 DAY AND sab.snapshot_date
            THEN COALESCE(f.observations_count, 0)
        ELSE 0
    END) AS observations_30,
    SUM(CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 59 DAY AND sab.snapshot_date - INTERVAL 30 DAY
            THEN COALESCE(f.observations_count, 0)
        ELSE 0
    END) AS observations_prev_30,
    SUM(CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 6 DAY AND sab.snapshot_date
            THEN COALESCE(f.level_gain_day, 0)
        ELSE 0
    END) AS level_gain_7,
    SUM(CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 29 DAY AND sab.snapshot_date
            THEN COALESCE(f.level_gain_day, 0)
        ELSE 0
    END) AS level_gain_30,
    COUNT(DISTINCT CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 29 DAY AND sab.snapshot_date
         AND f.primary_zone IS NOT NULL
         AND f.primary_zone <> ''
            THEN f.primary_zone
        ELSE NULL
    END) AS zones_visited_30,
    COUNT(DISTINCT CASE
        WHEN f.activity_date BETWEEN sab.snapshot_date - INTERVAL 29 DAY AND sab.snapshot_date
         AND COALESCE(f.guild_member_flag_latest, FALSE)
            THEN f.activity_date
        ELSE NULL
    END) AS guild_active_days_30
FROM lifecycle_snapshot_avatar_base sab
LEFT JOIN fct_player_daily f
    ON sab.avatar_id = f.avatar_id
   AND f.activity_date BETWEEN sab.snapshot_date - INTERVAL 59 DAY AND sab.snapshot_date
GROUP BY 1, 2
;

CREATE OR REPLACE VIEW lifecycle_snapshot_primary_zone_30 AS
WITH zone_ranked AS (
    SELECT
        sab.snapshot_date,
        sab.avatar_id,
        f.primary_zone,
        COUNT(*) AS zone_day_count_30,
        MAX(f.activity_date) AS zone_last_activity_date,
        ROW_NUMBER() OVER (
            PARTITION BY sab.snapshot_date, sab.avatar_id
            ORDER BY COUNT(*) DESC, MAX(f.activity_date) DESC, f.primary_zone ASC
        ) AS rn
    FROM lifecycle_snapshot_avatar_base sab
    JOIN fct_player_daily f
        ON sab.avatar_id = f.avatar_id
       AND f.activity_date BETWEEN sab.snapshot_date - INTERVAL 29 DAY AND sab.snapshot_date
    WHERE f.primary_zone IS NOT NULL
      AND f.primary_zone <> ''
    GROUP BY 1, 2, 3
)
SELECT
    snapshot_date,
    avatar_id,
    primary_zone AS primary_zone_30
FROM zone_ranked
WHERE rn = 1
;

CREATE OR REPLACE VIEW lifecycle_snapshot_latest_state AS
WITH latest_ranked AS (
    SELECT
        sab.snapshot_date,
        sab.avatar_id,
        f.activity_date,
        f.last_seen_at_that_day,
        f.level_end,
        f.guild_id_latest,
        f.guild_member_flag_latest,
        ROW_NUMBER() OVER (
            PARTITION BY sab.snapshot_date, sab.avatar_id
            ORDER BY f.activity_date DESC, f.last_seen_at_that_day DESC, f.avatar_id ASC
        ) AS rn
    FROM lifecycle_snapshot_avatar_base sab
    JOIN fct_player_daily f
        ON sab.avatar_id = f.avatar_id
       AND f.activity_date <= sab.snapshot_date
)
SELECT
    snapshot_date,
    avatar_id,
    activity_date AS last_seen_date,
    level_end AS level_current,
    guild_id_latest,
    guild_member_flag_latest
FROM latest_ranked
WHERE rn = 1
;

CREATE OR REPLACE VIEW lifecycle_snapshot_level_max_ever AS
SELECT
    sab.snapshot_date,
    sab.avatar_id,
    MAX(COALESCE(f.level_max, f.level_end)) AS level_max_ever
FROM lifecycle_snapshot_avatar_base sab
JOIN fct_player_daily f
    ON sab.avatar_id = f.avatar_id
   AND f.activity_date <= sab.snapshot_date
GROUP BY 1, 2
;

CREATE OR REPLACE VIEW lifecycle_snapshot_reactivation_flags AS
SELECT
    sab.snapshot_date,
    sab.avatar_id,
    MAX(CASE
        WHEN a.activity_date BETWEEN sab.snapshot_date - INTERVAL 6 DAY AND sab.snapshot_date
         AND a.previous_activity_date IS NOT NULL
         AND DATE_DIFF('day', a.previous_activity_date, a.activity_date) > 30
            THEN 1
        ELSE 0
    END)::BOOLEAN AS reactivated_30d_flag
FROM lifecycle_snapshot_avatar_base sab
LEFT JOIN lifecycle_avatar_activity_with_prev a
    ON sab.avatar_id = a.avatar_id
   AND a.activity_date BETWEEN sab.snapshot_date - INTERVAL 6 DAY AND sab.snapshot_date
GROUP BY 1, 2
;

CREATE OR REPLACE VIEW mart_player_lifecycle_features_base AS
SELECT
    sab.snapshot_date,
    sab.avatar_id,
    sab.first_seen_date,
    ls.last_seen_date,
    DATE_DIFF('day', sab.first_seen_date, sab.snapshot_date) AS days_since_first_seen,
    DATE_DIFF('day', ls.last_seen_date, sab.snapshot_date) AS recency_days,
    COALESCE(rw.active_days_7, 0) AS active_days_7,
    COALESCE(rw.active_days_30, 0) AS active_days_30,
    COALESCE(rw.active_days_prev_30, 0) AS active_days_prev_30,
    COALESCE(rw.observations_7, 0) AS observations_7,
    COALESCE(rw.observations_30, 0) AS observations_30,
    COALESCE(rw.observations_prev_30, 0) AS observations_prev_30,
    CASE
        WHEN COALESCE(rw.active_days_30, 0) > 0
            THEN rw.observations_30 * 1.0 / rw.active_days_30
        ELSE NULL
    END AS avg_observations_per_active_day_30,
    ls.level_current,
    lme.level_max_ever,
    COALESCE(rw.level_gain_7, 0) AS level_gain_7,
    COALESCE(rw.level_gain_30, 0) AS level_gain_30,
    COALESCE(rw.zones_visited_30, 0) AS zones_visited_30,
    pz.primary_zone_30,
    ls.guild_id_latest,
    ls.guild_member_flag_latest,
    COALESCE(rw.guild_active_days_30, 0) AS guild_active_days_30,
    CASE
        WHEN COALESCE(rw.active_days_prev_30, 0) > 0
            THEN (rw.active_days_prev_30 - COALESCE(rw.active_days_30, 0)) * 1.0 / rw.active_days_prev_30
        ELSE NULL
    END AS activity_drop_pct_30_vs_prev30,
    COALESCE(rf.reactivated_30d_flag, FALSE) AS reactivated_30d_flag
FROM lifecycle_snapshot_avatar_base sab
LEFT JOIN lifecycle_snapshot_recent_windows rw
    USING (snapshot_date, avatar_id)
LEFT JOIN lifecycle_snapshot_primary_zone_30 pz
    USING (snapshot_date, avatar_id)
LEFT JOIN lifecycle_snapshot_latest_state ls
    USING (snapshot_date, avatar_id)
LEFT JOIN lifecycle_snapshot_level_max_ever lme
    USING (snapshot_date, avatar_id)
LEFT JOIN lifecycle_snapshot_reactivation_flags rf
    USING (snapshot_date, avatar_id)
;

CREATE OR REPLACE VIEW lifecycle_snapshot_thresholds AS
SELECT
    snapshot_date,
    QUANTILE_CONT(observations_30, 0.75) FILTER (WHERE active_days_30 > 0) AS observations_30_p75_active,
    QUANTILE_CONT(level_gain_30, 0.75) FILTER (WHERE active_days_30 > 0) AS level_gain_30_p75_active
FROM mart_player_lifecycle_features_base
GROUP BY 1
;

CREATE OR REPLACE VIEW mart_player_lifecycle_features AS
SELECT
    fb.snapshot_date,
    fb.avatar_id,
    fb.first_seen_date,
    fb.last_seen_date,
    fb.days_since_first_seen,
    fb.recency_days,
    fb.active_days_7,
    fb.active_days_30,
    fb.active_days_prev_30,
    fb.observations_7,
    fb.observations_30,
    fb.observations_prev_30,
    fb.avg_observations_per_active_day_30,
    fb.level_current,
    fb.level_max_ever,
    fb.level_gain_7,
    fb.level_gain_30,
    fb.zones_visited_30,
    fb.primary_zone_30,
    fb.guild_id_latest,
    fb.guild_member_flag_latest,
    fb.guild_active_days_30,
    fb.activity_drop_pct_30_vs_prev30,
    fb.reactivated_30d_flag,
    CASE
        WHEN fb.active_days_30 > 0
         AND th.level_gain_30_p75_active IS NOT NULL
         AND fb.level_gain_30 > th.level_gain_30_p75_active
            THEN TRUE
        ELSE FALSE
    END AS fast_progressor_flag,
    CASE
        WHEN COALESCE(fb.guild_member_flag_latest, FALSE)
         AND fb.active_days_30 >= 5
            THEN TRUE
        ELSE FALSE
    END AS guild_engaged_flag,
    th.observations_30_p75_active,
    th.level_gain_30_p75_active
FROM mart_player_lifecycle_features_base fb
LEFT JOIN lifecycle_snapshot_thresholds th
    USING (snapshot_date)
;

CREATE OR REPLACE VIEW mart_player_segments AS
SELECT
    snapshot_date,
    avatar_id,
    CASE
        WHEN recency_days > 30
            THEN 'Lapsed Players'
        WHEN reactivated_30d_flag
            THEN 'Reactivated Players'
        WHEN days_since_first_seen <= 7
         AND active_days_7 >= 1
            THEN 'New Explorers'
        WHEN recency_days BETWEEN 8 AND 30
         AND active_days_prev_30 >= 5
         AND (
             active_days_30 <= 2
             OR COALESCE(activity_drop_pct_30_vs_prev30, 0) >= 0.5
         )
            THEN 'At-Risk Players'
        WHEN active_days_30 >= 15
          OR (
              observations_30_p75_active IS NOT NULL
              AND observations_30 >= observations_30_p75_active
          )
            THEN 'Core Engaged'
        WHEN fast_progressor_flag
         AND active_days_30 >= 3
            THEN 'Fast Progressors'
        WHEN guild_engaged_flag
            THEN 'Social/Guild Engaged'
        WHEN active_days_30 BETWEEN 2 AND 7
         AND recency_days <= 30
            THEN 'Casual Returners'
        ELSE 'Low Activity / Other'
    END AS lifecycle_segment,
    CASE
        WHEN recency_days > 30 THEN 1
        WHEN reactivated_30d_flag THEN 2
        WHEN days_since_first_seen <= 7 AND active_days_7 >= 1 THEN 3
        WHEN recency_days BETWEEN 8 AND 30
         AND active_days_prev_30 >= 5
         AND (
             active_days_30 <= 2
             OR COALESCE(activity_drop_pct_30_vs_prev30, 0) >= 0.5
         ) THEN 4
        WHEN active_days_30 >= 15
          OR (
              observations_30_p75_active IS NOT NULL
              AND observations_30 >= observations_30_p75_active
          ) THEN 5
        WHEN fast_progressor_flag
         AND active_days_30 >= 3 THEN 6
        WHEN guild_engaged_flag THEN 7
        WHEN active_days_30 BETWEEN 2 AND 7
         AND recency_days <= 30 THEN 8
        ELSE 9
    END AS segment_priority,
    recency_days,
    active_days_30,
    active_days_prev_30,
    observations_30,
    level_current,
    level_gain_30,
    zones_visited_30,
    guild_member_flag_latest,
    reactivated_30d_flag,
    fast_progressor_flag,
    guild_engaged_flag,
    CASE
        WHEN recency_days > 30
            THEN 'Win-back campaign / return incentive'
        WHEN reactivated_30d_flag
            THEN 'Reinforce return with limited-time progression or social event'
        WHEN days_since_first_seen <= 7
         AND active_days_7 >= 1
            THEN 'Onboarding support / early-game guidance'
        WHEN recency_days BETWEEN 8 AND 30
         AND active_days_prev_30 >= 5
         AND (
             active_days_30 <= 2
             OR COALESCE(activity_drop_pct_30_vs_prev30, 0) >= 0.5
         )
            THEN 'Targeted reactivation challenge / personalized nudge'
        WHEN active_days_30 >= 15
          OR (
              observations_30_p75_active IS NOT NULL
              AND observations_30 >= observations_30_p75_active
          )
            THEN 'Advanced content / high-engagement event'
        WHEN fast_progressor_flag
         AND active_days_30 >= 3
            THEN 'Recommend advanced zones / progression-focused event'
        WHEN guild_engaged_flag
            THEN 'Guild-based event / group challenge'
        WHEN active_days_30 BETWEEN 2 AND 7
         AND recency_days <= 30
            THEN 'Weekend challenge / lightweight recurring event'
        ELSE 'General engagement monitoring'
    END AS recommended_liveops_action
FROM mart_player_lifecycle_features
;

CREATE OR REPLACE VIEW agg_segment_monthly AS
WITH snapshot_totals AS (
    SELECT
        snapshot_date,
        COUNT(*) AS snapshot_total_players
    FROM mart_player_segments
    GROUP BY 1
)
SELECT
    s.snapshot_date,
    s.lifecycle_segment,
    COUNT(*) AS segment_size,
    COUNT(*) * 1.0 / st.snapshot_total_players AS segment_share,
    AVG(s.recency_days * 1.0) AS avg_recency_days,
    AVG(s.active_days_30 * 1.0) AS avg_active_days_30,
    AVG(s.observations_30 * 1.0) AS avg_observations_30,
    AVG(s.level_current * 1.0) AS avg_level_current,
    AVG(s.level_gain_30 * 1.0) AS avg_level_gain_30,
    AVG(CASE WHEN COALESCE(s.guild_member_flag_latest, FALSE) THEN 1.0 ELSE 0.0 END) AS guild_member_share,
    AVG(CASE WHEN s.fast_progressor_flag THEN 1.0 ELSE 0.0 END) AS fast_progressor_share,
    AVG(CASE WHEN s.reactivated_30d_flag THEN 1.0 ELSE 0.0 END) AS reactivated_share
FROM mart_player_segments s
JOIN snapshot_totals st
    USING (snapshot_date)
GROUP BY 1, 2, st.snapshot_total_players
ORDER BY 1, 2
;

CREATE OR REPLACE VIEW lifecycle_segment_catalog AS
SELECT *
FROM (
    VALUES
        ('Lapsed Players'),
        ('Reactivated Players'),
        ('New Explorers'),
        ('At-Risk Players'),
        ('Core Engaged'),
        ('Fast Progressors'),
        ('Social/Guild Engaged'),
        ('Casual Returners'),
        ('Low Activity / Other')
) AS t(lifecycle_segment)
;

CREATE OR REPLACE VIEW lifecycle_segment_monthly_dense AS
SELECT
    s.snapshot_date,
    c.lifecycle_segment,
    COALESCE(a.segment_size, 0) AS segment_size,
    COALESCE(a.segment_share, 0.0) AS segment_share
FROM lifecycle_monthly_snapshots s
CROSS JOIN lifecycle_segment_catalog c
LEFT JOIN agg_segment_monthly a
    USING (snapshot_date, lifecycle_segment)
;

CREATE OR REPLACE VIEW lifecycle_segment_growth_latest_3m AS
WITH growth_series AS (
    SELECT
        snapshot_date,
        lifecycle_segment,
        segment_size,
        segment_share,
        LAG(segment_size, 3) OVER (
            PARTITION BY lifecycle_segment
            ORDER BY snapshot_date
        ) AS segment_size_3m_ago,
        LAG(segment_share, 3) OVER (
            PARTITION BY lifecycle_segment
            ORDER BY snapshot_date
        ) AS segment_share_3m_ago
    FROM lifecycle_segment_monthly_dense
),
latest_snapshot AS (
    SELECT MAX(snapshot_date) AS latest_snapshot_date
    FROM lifecycle_monthly_snapshots
)
SELECT
    gs.snapshot_date,
    gs.lifecycle_segment,
    gs.segment_size,
    gs.segment_share,
    gs.segment_size_3m_ago,
    gs.segment_share_3m_ago,
    CASE
        WHEN gs.segment_size_3m_ago IS NULL THEN NULL
        ELSE gs.segment_size - gs.segment_size_3m_ago
    END AS segment_size_change_vs_3m_ago,
    CASE
        WHEN gs.segment_share_3m_ago IS NULL THEN NULL
        ELSE gs.segment_share - gs.segment_share_3m_ago
    END AS segment_share_change_vs_3m_ago
FROM growth_series gs
JOIN latest_snapshot ls
    ON gs.snapshot_date = ls.latest_snapshot_date
;
