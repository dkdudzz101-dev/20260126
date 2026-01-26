-- =============================================
-- 제주오름 앱 Supabase 테이블 생성 SQL
-- =============================================

-- 1. users (사용자)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  nickname TEXT,
  profile_image TEXT,
  bio TEXT,
  provider TEXT,
  total_distance REAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. oreums (오름 정보)
CREATE TABLE IF NOT EXISTS oreums (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  trail_name TEXT,
  distance REAL,
  difficulty TEXT,
  time_up INTEGER,
  time_down INTEGER,
  surface TEXT,
  description TEXT,
  image_url TEXT,
  start_lat REAL,
  start_lng REAL,
  summit_lat REAL,
  summit_lng REAL,
  category TEXT[],
  geojson_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. stamps (완등 기록)
CREATE TABLE IF NOT EXISTS stamps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  oreum_id TEXT REFERENCES oreums(id),
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  distance_walked REAL,
  time_taken INTEGER,
  UNIQUE(user_id, oreum_id)
);

-- 4. badges (뱃지 정의)
CREATE TABLE IF NOT EXISTS badges (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  category TEXT,
  condition_type TEXT,
  condition_value INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. user_badges (획득한 뱃지)
CREATE TABLE IF NOT EXISTS user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  badge_id TEXT REFERENCES badges(id),
  earned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);

-- 6. posts (커뮤니티 게시글)
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  oreum_id TEXT REFERENCES oreums(id),
  content TEXT NOT NULL,
  images TEXT[],
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. comments (댓글)
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. likes (좋아요)
CREATE TABLE IF NOT EXISTS likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- 9. bookmarks (찜)
CREATE TABLE IF NOT EXISTS bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  oreum_id TEXT REFERENCES oreums(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, oreum_id)
);

-- 10. reviews (오름 리뷰)
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  oreum_id TEXT REFERENCES oreums(id),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  content TEXT,
  images TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, oreum_id)
);

-- 11. reports (신고)
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id),
  target_type TEXT NOT NULL,
  target_id UUID NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. notices (공지사항)
CREATE TABLE IF NOT EXISTS notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  image_url TEXT,
  is_pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. notifications (알림)
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. offline_downloads (오프라인 다운로드 기록)
CREATE TABLE IF NOT EXISTS offline_downloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  oreum_id TEXT REFERENCES oreums(id),
  downloaded_at DATE DEFAULT CURRENT_DATE,
  UNIQUE(user_id, oreum_id, downloaded_at)
);

-- 15. inquiries (문의하기)
CREATE TABLE IF NOT EXISTS inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  category TEXT NOT NULL,
  email TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  admin_reply TEXT,
  replied_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- 인덱스 생성
-- =============================================

CREATE INDEX IF NOT EXISTS idx_stamps_user_id ON stamps(user_id);
CREATE INDEX IF NOT EXISTS idx_stamps_oreum_id ON stamps(oreum_id);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_oreum_id ON reviews(oreum_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- =============================================
-- RLS (Row Level Security) 정책
-- =============================================

-- users 테이블 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- oreums 테이블 RLS (모두 읽기 가능)
ALTER TABLE oreums ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view oreums" ON oreums
  FOR SELECT USING (true);

-- stamps 테이블 RLS
ALTER TABLE stamps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own stamps" ON stamps
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stamps" ON stamps
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- badges 테이블 RLS (모두 읽기 가능)
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view badges" ON badges
  FOR SELECT USING (true);

-- user_badges 테이블 RLS
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own badges" ON user_badges
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own badges" ON user_badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- posts 테이블 RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view posts" ON posts
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own posts" ON posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts" ON posts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts" ON posts
  FOR DELETE USING (auth.uid() = user_id);

-- comments 테이블 RLS
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view comments" ON comments
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own comments" ON comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments" ON comments
  FOR DELETE USING (auth.uid() = user_id);

-- likes 테이블 RLS
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view likes" ON likes
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own likes" ON likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own likes" ON likes
  FOR DELETE USING (auth.uid() = user_id);

-- bookmarks 테이블 RLS
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookmarks" ON bookmarks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bookmarks" ON bookmarks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own bookmarks" ON bookmarks
  FOR DELETE USING (auth.uid() = user_id);

-- reviews 테이블 RLS
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reviews" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own reviews" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reviews" ON reviews
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own reviews" ON reviews
  FOR DELETE USING (auth.uid() = user_id);

-- reports 테이블 RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert reports" ON reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- notices 테이블 RLS (모두 읽기 가능)
ALTER TABLE notices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view notices" ON notices
  FOR SELECT USING (true);

-- notifications 테이블 RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- offline_downloads 테이블 RLS
ALTER TABLE offline_downloads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own downloads" ON offline_downloads
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own downloads" ON offline_downloads
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- inquiries 테이블 RLS
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own inquiries" ON inquiries
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can insert inquiries" ON inquiries
  FOR INSERT WITH CHECK (true);

-- =============================================
-- 기본 뱃지 데이터 삽입
-- =============================================

INSERT INTO badges (id, name, description, icon, category, condition_type, condition_value) VALUES
  ('first_oreum', '첫 발걸음', '첫 오름 완등!', '🌱', 'completion', 'oreum_count', 1),
  ('oreum_5', '오름 입문자', '5개 오름 완등', '🥉', 'completion', 'oreum_count', 5),
  ('oreum_10', '오름 탐험가', '10개 오름 완등', '🥈', 'completion', 'oreum_count', 10),
  ('oreum_30', '오름 마스터', '30개 오름 완등', '🥇', 'completion', 'oreum_count', 30),
  ('oreum_100', '오름 정복자', '100개 오름 완등', '👑', 'completion', 'oreum_count', 100),
  ('oreum_all', '제주 오름왕', '전체 오름 완등', '🏆', 'completion', 'oreum_count', 368),
  ('walker_10', '워커', '총 10km 달성', '👟', 'distance', 'total_distance', 10),
  ('walker_50', '트레커', '총 50km 달성', '🏃', 'distance', 'total_distance', 50),
  ('walker_100', '마라토너', '총 100km 달성', '🦶', 'distance', 'total_distance', 100),
  ('walker_500', '지구탐험가', '총 500km 달성', '🌏', 'distance', 'total_distance', 500),
  ('streak_3', '3일 연속', '3일 연속 등반', '⚡', 'streak', 'streak_days', 3),
  ('streak_7', '일주일 도전', '7일 연속 등반', '🔥', 'streak', 'streak_days', 7),
  ('streak_30', '한달의 기적', '30일 연속 등반', '💪', 'streak', 'streak_days', 30),
  ('first_post', '첫 후기', '첫 글 작성', '✍️', 'community', 'post_count', 1),
  ('reviewer', '리뷰어', '10개 글 작성', '📝', 'community', 'post_count', 10),
  ('popular', '인기인', '좋아요 100개 받기', '❤️', 'community', 'like_received', 100),
  ('early_bird', '얼리버드', '오전 6시 이전 등반', '🌅', 'time', 'early_morning', 1),
  ('night_hiker', '야간 탐험가', '오후 8시 이후 등반', '🌙', 'time', 'night_hiking', 1),
  ('sunrise_lover', '일출 러버', '일출 시간대 5회 등반', '🌄', 'time', 'sunrise_count', 5),
  ('easy_master', '쉬운 오름 마스터', '쉬운 오름 전부 완등', '😊', 'category', 'easy_complete', 1),
  ('view_collector', '경치 수집가', '경치 좋은 오름 전부 완등', '📸', 'category', 'view_complete', 1),
  ('autumn_explorer', '억새 탐험가', '억새 오름 전부 완등', '🍂', 'category', 'autumn_complete', 1),
  ('sunrise_hunter', '일출 헌터', '일출 명소 오름 전부 완등', '🌅', 'category', 'sunrise_complete', 1)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- 등산 기록 확장 (2024-01 추가)
-- =============================================

-- stamps 테이블 컬럼 추가
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS steps INTEGER;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS avg_speed REAL;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS calories INTEGER;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS elevation_gain REAL;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS elevation_loss REAL;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS max_altitude REAL;
ALTER TABLE stamps ADD COLUMN IF NOT EXISTS min_altitude REAL;

-- users 테이블에 체중 컬럼 추가 (칼로리 계산용)
ALTER TABLE users ADD COLUMN IF NOT EXISTS weight REAL DEFAULT 70;

-- hiking_routes 테이블 생성 (GPS 경로 저장)
CREATE TABLE IF NOT EXISTS hiking_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stamp_id UUID REFERENCES stamps(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  oreum_id TEXT,
  route_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- hiking_routes 인덱스
CREATE INDEX IF NOT EXISTS idx_hiking_routes_stamp_id ON hiking_routes(stamp_id);
CREATE INDEX IF NOT EXISTS idx_hiking_routes_user_id ON hiking_routes(user_id);

-- hiking_routes RLS
ALTER TABLE hiking_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own routes" ON hiking_routes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own routes" ON hiking_routes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own routes" ON hiking_routes
  FOR DELETE USING (auth.uid() = user_id);
