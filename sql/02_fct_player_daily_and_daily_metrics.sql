-- Player daily fact and aggregate daily metrics for WoWAH activity.
-- Expects a DuckDB view named stg_wowah_events to already exist.

CREATE OR REPLACE VIEW fct_player_daily AS
WITH base_events AS (
    SELECT
        avatar_id,
        CAST(observed_at AS DATE) AS activity_date,
        observed_at,
        player_or_group_id,
        guild_id,
        CASE
            WHEN level BETWEEN 1 AND 80 THEN level
            ELSE NULL
        END AS level_clean,
        race,
        character_class,
        zone,
        guild_member_flag,
        source_file
    FROM stg_wowah_events
    WHERE observed_at IS NOT NULL
      AND avatar_id IS NOT NULL
),
first_daily_observation AS (
    SELECT
        avatar_id,
        activity_date,
        observed_at AS first_seen_at_that_day,
        level_clean AS level_start,
        ROW_NUMBER() OVER (
            PARTITION BY avatar_id, activity_date
            ORDER BY observed_at ASC, COALESCE(source_file, '') ASC, COALESCE(player_or_group_id, -1) ASC
        ) AS rn
    FROM base_events
),
last_daily_observation AS (
    SELECT
        avatar_id,
        activity_date,
        observed_at AS last_seen_at_that_day,
        level_clean AS level_end,
        race,
        character_class,
        guild_id AS guild_id_latest,
        guild_member_flag AS guild_member_flag_latest,
        ROW_NUMBER() OVER (
            PARTITION BY avatar_id, activity_date
            ORDER BY observed_at DESC, COALESCE(source_file, '') DESC, COALESCE(player_or_group_id, -1) DESC
        ) AS rn
    FROM base_events
),
zone_frequency AS (
    SELECT
        avatar_id,
        activity_date,
        zone,
        COUNT(*) AS zone_observation_count,
        MAX(observed_at) AS zone_last_seen_at,
        ROW_NUMBER() OVER (
            PARTITION BY avatar_id, activity_date
            ORDER BY COUNT(*) DESC, MAX(observed_at) DESC, zone ASC
        ) AS rn
    FROM base_events
    WHERE zone IS NOT NULL
      AND zone <> ''
    GROUP BY 1, 2, 3
),
daily_rollup AS (
    SELECT
        avatar_id,
        activity_date,
        COUNT(*) AS observations_count,
        MAX(level_clean) AS level_max,
        COUNT(DISTINCT NULLIF(zone, '')) AS zones_visited_count
    FROM base_events
    GROUP BY 1, 2
)
SELECT
    dr.avatar_id,
    dr.activity_date,
    fo.first_seen_at_that_day,
    lo.last_seen_at_that_day,
    dr.observations_count,
    fo.level_start,
    lo.level_end,
    dr.level_max,
    CASE
        WHEN fo.level_start IS NOT NULL AND lo.level_end IS NOT NULL
            THEN lo.level_end - fo.level_start
        ELSE NULL
    END AS level_gain_day,
    lo.race,
    lo.character_class,
    lo.guild_id_latest,
    lo.guild_member_flag_latest,
    dr.zones_visited_count,
    zf.zone AS primary_zone,
    1::INTEGER AS active_flag
FROM daily_rollup dr
LEFT JOIN first_daily_observation fo
    ON dr.avatar_id = fo.avatar_id
   AND dr.activity_date = fo.activity_date
   AND fo.rn = 1
LEFT JOIN last_daily_observation lo
    ON dr.avatar_id = lo.avatar_id
   AND dr.activity_date = lo.activity_date
   AND lo.rn = 1
LEFT JOIN zone_frequency zf
    ON dr.avatar_id = zf.avatar_id
   AND dr.activity_date = zf.activity_date
   AND zf.rn = 1
;

CREATE OR REPLACE VIEW agg_daily_metrics AS
WITH date_spine AS (
    SELECT CAST(activity_date AS DATE) AS activity_date
    FROM generate_series(
        (SELECT MIN(activity_date) FROM fct_player_daily),
        (SELECT MAX(activity_date) FROM fct_player_daily),
        INTERVAL 1 DAY
    ) AS t(activity_date)
),
daily_rollup AS (
    SELECT
        activity_date,
        COUNT(DISTINCT avatar_id) AS dau,
        SUM(observations_count) AS total_observations,
        SUM(CASE WHEN COALESCE(guild_member_flag_latest, FALSE) THEN 1 ELSE 0 END) AS active_guild_members,
        AVG(observations_count * 1.0) AS avg_observations_per_avatar,
        AVG(level_end * 1.0) AS avg_level,
        AVG(level_gain_day * 1.0) AS avg_level_gain_day,
        SUM(COALESCE(level_gain_day, 0)) AS total_level_gain_day
    FROM fct_player_daily
    GROUP BY 1
),
rolling_activity AS (
    SELECT
        ds.activity_date,
        COUNT(DISTINCT CASE
            WHEN f.activity_date BETWEEN ds.activity_date - INTERVAL 6 DAY AND ds.activity_date
                THEN f.avatar_id
            ELSE NULL
        END) AS wau,
        COUNT(DISTINCT CASE
            WHEN f.activity_date BETWEEN ds.activity_date - INTERVAL 29 DAY AND ds.activity_date
                THEN f.avatar_id
            ELSE NULL
        END) AS mau
    FROM date_spine ds
    LEFT JOIN fct_player_daily f
        ON f.activity_date BETWEEN ds.activity_date - INTERVAL 29 DAY AND ds.activity_date
    GROUP BY 1
),
avatar_lifecycle AS (
    SELECT
        avatar_id,
        activity_date,
        MIN(activity_date) OVER (PARTITION BY avatar_id) AS first_seen_date,
        LAG(activity_date) OVER (PARTITION BY avatar_id ORDER BY activity_date) AS previous_activity_date
    FROM fct_player_daily
),
lifecycle_rollup AS (
    SELECT
        activity_date,
        SUM(CASE
            WHEN activity_date = first_seen_date THEN 1
            ELSE 0
        END) AS new_avatars,
        SUM(CASE
            WHEN previous_activity_date IS NOT NULL
             AND DATE_DIFF('day', previous_activity_date, activity_date) BETWEEN 1 AND 30
                THEN 1
            ELSE 0
        END) AS returning_avatars,
        SUM(CASE
            WHEN previous_activity_date IS NOT NULL
             AND DATE_DIFF('day', previous_activity_date, activity_date) > 30
                THEN 1
            ELSE 0
        END) AS reactivated_avatars_30d
    FROM avatar_lifecycle
    GROUP BY 1
)
SELECT
    ds.activity_date,
    CAST(COALESCE(dr.dau, 0) AS BIGINT) AS dau,
    CAST(COALESCE(ra.wau, 0) AS BIGINT) AS wau,
    CAST(COALESCE(ra.mau, 0) AS BIGINT) AS mau,
    CASE
        WHEN COALESCE(ra.mau, 0) = 0 THEN NULL
        ELSE COALESCE(dr.dau, 0) * 1.0 / ra.mau
    END AS dau_mau_stickiness,
    CAST(COALESCE(dr.total_observations, 0) AS BIGINT) AS total_observations,
    CAST(COALESCE(dr.active_guild_members, 0) AS BIGINT) AS active_guild_members,
    CASE
        WHEN COALESCE(dr.dau, 0) = 0 THEN NULL
        ELSE COALESCE(dr.active_guild_members, 0) * 1.0 / dr.dau
    END AS guild_member_share,
    CASE
        WHEN COALESCE(dr.dau, 0) = 0 THEN NULL
        ELSE COALESCE(dr.total_observations, 0) * 1.0 / dr.dau
    END AS avg_observations_per_avatar,
    dr.avg_level,
    dr.avg_level_gain_day,
    CAST(COALESCE(dr.total_level_gain_day, 0) AS BIGINT) AS total_level_gain_day,
    CAST(COALESCE(lr.new_avatars, 0) AS BIGINT) AS new_avatars,
    CAST(COALESCE(lr.returning_avatars, 0) AS BIGINT) AS returning_avatars,
    CAST(COALESCE(lr.reactivated_avatars_30d, 0) AS BIGINT) AS reactivated_avatars_30d
FROM date_spine ds
LEFT JOIN daily_rollup dr
    USING (activity_date)
LEFT JOIN rolling_activity ra
    USING (activity_date)
LEFT JOIN lifecycle_rollup lr
    USING (activity_date)
ORDER BY 1
;
