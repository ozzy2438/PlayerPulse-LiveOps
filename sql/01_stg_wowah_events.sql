-- Staging table for Wowah events
-- Bu betik, ham olay verisini staging katmanına hazırlamak için temel yapı sunar.

SELECT
    event_timestamp,
    player_id,
    event_type,
    session_id,
    region,
    device_type,
    event_value
FROM raw_wowah_events;
