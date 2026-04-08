-- =============================================================================
-- Supabase Optimization: RPC Functions and Views
-- =============================================================================

-- =============================================================================
-- Task 1: Ranking RPCs
-- =============================================================================

-- 1a. get_user_ranking: Returns top users ranked by stamp count
CREATE OR REPLACE FUNCTION get_user_ranking(p_limit INT DEFAULT 100)
RETURNS TABLE(
  user_id UUID,
  nickname TEXT,
  profile_image TEXT,
  stamp_count BIGINT,
  rank BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    u.id AS user_id,
    COALESCE(u.nickname, '탐험가') AS nickname,
    u.profile_image,
    COUNT(s.id) AS stamp_count,
    DENSE_RANK() OVER (ORDER BY COUNT(s.id) DESC) AS rank
  FROM stamps s
  JOIN users u ON u.id = s.user_id
  GROUP BY u.id, u.nickname, u.profile_image
  ORDER BY stamp_count DESC, u.nickname
  LIMIT p_limit;
$$;

-- 1b. get_oreum_ranking: Returns top oreums ranked by stamp count
CREATE OR REPLACE FUNCTION get_oreum_ranking(p_limit INT DEFAULT 100)
RETURNS TABLE(
  oreum_id TEXT,
  name TEXT,
  stamp_count BIGINT,
  rank BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    o.id::TEXT AS oreum_id,
    COALESCE(o.name, '알 수 없는 오름') AS name,
    COUNT(s.id) AS stamp_count,
    DENSE_RANK() OVER (ORDER BY COUNT(s.id) DESC) AS rank
  FROM stamps s
  JOIN oreums o ON o.id = s.oreum_id
  GROUP BY o.id, o.name
  ORDER BY stamp_count DESC, o.name
  LIMIT p_limit;
$$;

-- 1c. get_my_rank: Returns the calling user's rank among all users
CREATE OR REPLACE FUNCTION get_my_rank(p_user_id UUID)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
  SELECT r.rank::INT
  FROM (
    SELECT
      user_id,
      DENSE_RANK() OVER (ORDER BY COUNT(id) DESC) AS rank
    FROM stamps
    GROUP BY user_id
  ) r
  WHERE r.user_id = p_user_id;
$$;

-- =============================================================================
-- Task 2: User Stamp Summary RPC
-- =============================================================================

-- get_user_stamp_summary: Returns stamps, hiking logs, certified oreum IDs,
-- total distance, and total steps in a single call
CREATE OR REPLACE FUNCTION get_user_stamp_summary(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_stamps JSON;
  v_hiking_logs JSON;
  v_certified_oreum_ids JSON;
  v_total_distance DOUBLE PRECISION;
  v_total_steps BIGINT;
  v_oreum_map JSON;
BEGIN
  -- Get all stamps for this user with oreum data
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_stamps
  FROM (
    SELECT
      s.*,
      'stamp' AS record_type,
      s.completed_at AS record_date,
      json_build_object('id', o.id, 'name', o.name, 'stamp_url', o.stamp_url) AS oreums
    FROM stamps s
    LEFT JOIN oreums o ON o.id = s.oreum_id
    WHERE s.user_id = p_user_id
    ORDER BY s.completed_at DESC
  ) t;

  -- Get all hiking logs for this user with oreum data
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_hiking_logs
  FROM (
    SELECT
      h.*,
      'hiking_log' AS record_type,
      h.hiked_at AS record_date,
      CASE
        WHEN h.oreum_id IS NOT NULL THEN
          json_build_object('id', o.id, 'name', o.name, 'stamp_url', o.stamp_url)
        ELSE NULL
      END AS oreums
    FROM hiking_logs h
    LEFT JOIN oreums o ON o.id = h.oreum_id
    WHERE h.user_id = p_user_id
    ORDER BY h.hiked_at DESC
  ) t;

  -- Get all certified oreum IDs (from ALL users)
  SELECT COALESCE(json_agg(DISTINCT s.oreum_id::TEXT), '[]'::json)
  INTO v_certified_oreum_ids
  FROM stamps s
  WHERE s.oreum_id IS NOT NULL;

  -- Calculate total distance (stamps + hiking_logs, ascent + descent)
  SELECT COALESCE(SUM(
    COALESCE(distance_walked, 0) + COALESCE(descent_distance, 0)
  ), 0)
  INTO v_total_distance
  FROM (
    SELECT distance_walked, descent_distance FROM stamps WHERE user_id = p_user_id
    UNION ALL
    SELECT distance_walked, descent_distance FROM hiking_logs WHERE user_id = p_user_id
  ) combined;

  -- Calculate total steps (stamps + hiking_logs, ascent + descent)
  SELECT COALESCE(SUM(
    COALESCE(steps, 0) + COALESCE(descent_steps, 0)
  ), 0)
  INTO v_total_steps
  FROM (
    SELECT steps, descent_steps FROM stamps WHERE user_id = p_user_id
    UNION ALL
    SELECT steps, descent_steps FROM hiking_logs WHERE user_id = p_user_id
  ) combined;

  RETURN json_build_object(
    'stamps', v_stamps,
    'hiking_logs', v_hiking_logs,
    'certified_oreum_ids', v_certified_oreum_ids,
    'total_distance', v_total_distance,
    'total_steps', v_total_steps
  );
END;
$$;

-- =============================================================================
-- Task 3: Oreum Themes View
-- =============================================================================

CREATE OR REPLACE VIEW v_oreum_themes AS
SELECT
  t.id AS theme_id,
  t.key AS theme_key,
  t.name AS theme_name,
  o.*
FROM themes t
JOIN oreum_themes ot ON ot.theme_id = t.id
JOIN oreums o ON o.id = ot.oreum_id::TEXT
ORDER BY t.key, o.name;
