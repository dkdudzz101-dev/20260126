# Supabase 테이블 & 스토리지 구조

## 프로젝트 정보
- **URL**: https://zsodcfgchbmmvpbwhuyu.supabase.co
- **프로젝트명**: Jejuoreum

---

## 테이블 현황 요약

| 테이블 | 레코드 수 | 설명 |
|--------|----------|------|
| oreums | 368개 | 오름 데이터 (활성 184 / 비활성 184) |
| oreum_themes | 99개 | 오름-테마 매핑 |
| themes | 5개 | 테마 정의 |
| badges | 23개 | 뱃지 정의 |
| users | 1개 | 사용자 |
| stamps | 0개 | 스탬프 기록 |
| bookmarks | 0개 | 북마크 |
| reviews | 0개 | 리뷰 |
| posts | 0개 | 게시글 |
| comments | 0개 | 댓글 |
| likes | 0개 | 좋아요 |
| user_badges | 0개 | 사용자 뱃지 |
| notifications | 0개 | 알림 |
| notices | 0개 | 공지사항 |
| inquiries | 0개 | 문의 |
| reports | 0개 | 신고 |
| offline_downloads | 0개 | 오프라인 다운로드 |

---

## 주요 테이블 상세

### 1. oreums (오름 데이터) - 368개

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| id | text | PK |
| name | text | 오름 이름 |
| trail_name | text | 탐방로 구간명 |
| distance | float | 거리 (km) |
| difficulty | text | 난이도 (쉬움/중간) |
| time_up | int | 상행 시간 (분) |
| time_down | int | 하행 시간 (분) |
| surface | text | 노면 정보 |
| description | text | 설명 |
| image_url | text | 이미지 URL |
| start_lat | float | 시작점 위도 |
| start_lng | float | 시작점 경도 |
| summit_lat | float | 정상 위도 |
| summit_lng | float | 정상 경도 |
| category | text | 카테고리 |
| geojson_path | text | GeoJSON 경로 |
| rating | float | 평점 |
| review_count | int | 리뷰 수 |
| stamp_url | text | 스탬프 이미지 URL |
| forest_code | text | 산림청 코드 |
| elevation | int | 해발고도 (m) |
| parking | text | 주차 정보 |
| restroom | text | 화장실 정보 |
| elevation_url | text | 고도 그래프 URL |
| restriction | text | 출입 제한 유형 |
| restriction_note | text | 제한 상세 설명 |
| origin | text | 이름 유래 |
| is_active | bool | 활성화 여부 |
| created_at | timestamp | 생성일 |

---

### 2. oreum_themes (오름-테마 매핑) - 99개

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| id | int | PK |
| theme_id | int | FK → themes.id |
| oreum_id | int | 오름 ID |

---

### 3. themes (테마 정의) - 5개

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| id | int | PK |
| key | text | 테마 키 |
| name | text | 테마 이름 |
| description | text | 설명 |
| icon | text | 아이콘 |

**테마 목록:**
| id | key | name |
|----|-----|------|
| 1 | famous | 대표명소 |
| 2 | scenic | 전망좋은 |
| 3 | forest | 숲속힐링 |
| 4 | family | 가족추천 |
| 5 | seasonal | 계절명소 |

---

### 4. badges (뱃지 정의) - 23개

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| id | text | PK |
| name | text | 뱃지 이름 |
| description | text | 설명 |
| icon | text | 아이콘 이모지 |
| category | text | 카테고리 |
| condition_type | text | 조건 타입 |
| condition_value | int | 조건 값 |
| created_at | timestamp | 생성일 |

---

### 5. users (사용자) - 1개

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| id | uuid | PK (Supabase Auth UUID) |
| email | text | 이메일 |
| nickname | text | 닉네임 |
| profile_image | text | 프로필 이미지 URL |
| bio | text | 자기소개 |
| provider | text | 로그인 제공자 |
| total_distance | float | 총 이동 거리 |
| created_at | timestamp | 가입일 |
| updated_at | timestamp | 수정일 |

---

## 스토리지 버킷

### oreum-data (PUBLIC) - 369개 폴더
```
oreum-data/
├── 1/
│   ├── map.geojson
│   ├── map.png
│   ├── stamp.png
│   └── elevation.png
├── 2/
│   └── ...
└── 368/
    └── ...
```

### 기타 버킷
- **posts**: 게시글 이미지
- **profiles**: 프로필 이미지
- **reviews**: 리뷰 이미지

---

## 앱 ↔ Supabase 연결 상태

| 모델 | 테이블 | 컬럼 매칭 | 상태 |
|------|--------|----------|------|
| OreumModel | oreums | 29/30 | ✅ |
| - | oreum_themes | 3/3 | ✅ |
| - | themes | 5/5 | ✅ |

**미사용 컬럼**: `created_at` (자동 생성)

---

*최종 업데이트: 2025-01-14*
