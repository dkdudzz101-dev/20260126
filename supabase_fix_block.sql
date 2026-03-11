-- ============================================
-- blocked_users 테이블 RLS 정책 수정
-- Supabase SQL Editor에서 실행하세요
-- ============================================

-- 1. 기존 정책 삭제 (없으면 무시됨)
DROP POLICY IF EXISTS "Users can view own blocks" ON blocked_users;
DROP POLICY IF EXISTS "Users can insert own blocks" ON blocked_users;
DROP POLICY IF EXISTS "Users can delete own blocks" ON blocked_users;
DROP POLICY IF EXISTS "Users can update own blocks" ON blocked_users;

-- 2. RLS 활성화 확인
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- 3. 정책 재생성
CREATE POLICY "Users can view own blocks" ON blocked_users
  FOR SELECT USING (auth.uid() = blocker_id);

CREATE POLICY "Users can insert own blocks" ON blocked_users
  FOR INSERT WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Users can update own blocks" ON blocked_users
  FOR UPDATE USING (auth.uid() = blocker_id);

CREATE POLICY "Users can delete own blocks" ON blocked_users
  FOR DELETE USING (auth.uid() = blocker_id);

-- 4. reports 테이블도 RLS 정책 확인 (차단 시 자동 신고)
DROP POLICY IF EXISTS "Users can insert reports" ON reports;
DROP POLICY IF EXISTS "Users can view own reports" ON reports;

CREATE POLICY "Users can insert reports" ON reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can view own reports" ON reports
  FOR SELECT USING (auth.uid() = reporter_id);
