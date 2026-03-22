-- 좋아요 수 증가 함수
CREATE OR REPLACE FUNCTION increment_like_count(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE posts SET like_count = like_count + 1 WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 좋아요 수 감소 함수 (0 아래로 안 내려감)
CREATE OR REPLACE FUNCTION decrement_like_count(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE posts SET like_count = GREATEST(0, like_count - 1) WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 댓글 수 증가 함수
CREATE OR REPLACE FUNCTION increment_comment_count(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE posts SET comment_count = comment_count + 1 WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 댓글 수 감소 함수 (0 아래로 안 내려감)
CREATE OR REPLACE FUNCTION decrement_comment_count(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE posts SET comment_count = GREATEST(0, comment_count - 1) WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
