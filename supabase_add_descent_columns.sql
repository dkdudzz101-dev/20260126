-- 하산 데이터 컬럼 추가

-- stamps 테이블
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS descent_distance double precision;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS descent_time integer;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS descent_steps integer;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS descent_calories integer;

-- hiking_logs 테이블
ALTER TABLE hiking_logs ADD COLUMN IF NOT EXISTS descent_distance double precision;
ALTER TABLE hiking_logs ADD COLUMN IF NOT EXISTS descent_time integer;
ALTER TABLE hiking_logs ADD COLUMN IF NOT EXISTS descent_steps integer;
ALTER TABLE hiking_logs ADD COLUMN IF NOT EXISTS descent_calories integer;
