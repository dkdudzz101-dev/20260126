-- =============================================
-- 등산 기능 수정 SQL
-- Supabase SQL Editor에서 실행하세요
-- =============================================

-- 1. stamps 테이블에 memo 컬럼 추가
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS memo TEXT;

-- 2. hiking_logs 테이블에 memo 컬럼 추가
ALTER TABLE hiking_logs ADD COLUMN IF NOT EXISTS memo TEXT;

-- 3. users 테이블에 total_steps 컬럼 추가
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_steps BIGINT DEFAULT 0;

-- 4. hiking_logs UPDATE 정책 추가
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'hiking_logs' AND policyname = 'Users can update own hiking logs') THEN
    CREATE POLICY "Users can update own hiking logs" ON hiking_logs
      FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;
