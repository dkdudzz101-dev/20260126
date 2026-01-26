-- Supabase 로그인/회원가입 문제 해결 SQL
-- 이 스크립트를 Supabase SQL Editor에서 실행하세요

-- ================================
-- 1. users 테이블 RLS 정책 설정
-- ================================

-- 기존 정책 삭제 (존재하는 경우)
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable update for users based on id" ON users;

-- RLS 활성화
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 사용자가 자신의 프로필을 조회할 수 있음
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- 사용자가 자신의 프로필을 생성할 수 있음
CREATE POLICY "Users can insert own profile"
ON users FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 사용자가 자신의 프로필을 수정할 수 있음
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ================================
-- 2. stamps 테이블 RLS 정책 설정
-- ================================

DROP POLICY IF EXISTS "Users can view own stamps" ON stamps;
DROP POLICY IF EXISTS "Users can insert own stamps" ON stamps;
DROP POLICY IF EXISTS "Users can delete own stamps" ON stamps;

ALTER TABLE stamps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own stamps"
ON stamps FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stamps"
ON stamps FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own stamps"
ON stamps FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ================================
-- 3. posts 테이블 RLS 정책 설정
-- ================================

DROP POLICY IF EXISTS "Anyone can view posts" ON posts;
DROP POLICY IF EXISTS "Users can create posts" ON posts;
DROP POLICY IF EXISTS "Users can update own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON posts;

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- 모든 사용자가 게시글 조회 가능
CREATE POLICY "Anyone can view posts"
ON posts FOR SELECT
TO authenticated
USING (true);

-- 인증된 사용자가 게시글 작성 가능
CREATE POLICY "Users can create posts"
ON posts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 자신의 게시글만 수정 가능
CREATE POLICY "Users can update own posts"
ON posts FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- 자신의 게시글만 삭제 가능
CREATE POLICY "Users can delete own posts"
ON posts FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ================================
-- 4. comments 테이블 RLS 정책 설정
-- ================================

DROP POLICY IF EXISTS "Anyone can view comments" ON comments;
DROP POLICY IF EXISTS "Users can create comments" ON comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON comments;

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view comments"
ON comments FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can create comments"
ON comments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments"
ON comments FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ================================
-- 5. likes 테이블 RLS 정책 설정
-- ================================

DROP POLICY IF EXISTS "Anyone can view likes" ON likes;
DROP POLICY IF EXISTS "Users can create likes" ON likes;
DROP POLICY IF EXISTS "Users can delete own likes" ON likes;

ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view likes"
ON likes FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can create likes"
ON likes FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own likes"
ON likes FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ================================
-- 6. bookmarks 테이블 RLS 정책 설정
-- ================================

DROP POLICY IF EXISTS "Users can view own bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can create bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can delete own bookmarks" ON bookmarks;

ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookmarks"
ON bookmarks FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can create bookmarks"
ON bookmarks FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own bookmarks"
ON bookmarks FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ================================
-- 7. Storage 버킷 RLS 설정
-- ================================

-- posts 버킷 정책 (이미지 업로드용)
INSERT INTO storage.buckets (id, name, public)
VALUES ('posts', 'posts', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 버킷 정책 설정
DROP POLICY IF EXISTS "Anyone can view post images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload post images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own post images" ON storage.objects;

CREATE POLICY "Anyone can view post images"
ON storage.objects FOR SELECT
USING (bucket_id = 'posts');

CREATE POLICY "Authenticated users can upload post images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'posts');

CREATE POLICY "Users can delete own post images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'posts' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ================================
-- 완료 메시지
-- ================================
SELECT 'RLS 정책이 성공적으로 설정되었습니다!' AS result;
