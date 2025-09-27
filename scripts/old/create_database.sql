-- 흡연구역 찾기 앱 데이터베이스 스키마
-- PostgreSQL 생성 쿼리

-- 1. 데이터베이스 생성
CREATE DATABASE smoking_areas_db;

-- 2. 데이터베이스 연결 후 실행
\c smoking_areas_db;

-- 3. 흡연구역 테이블 생성
CREATE TABLE smoking_areas (
    id SERIAL PRIMARY KEY,
    category VARCHAR(20) NOT NULL,                    -- 카테고리 (부분 개방형, 완전 폐쇄형)
    address TEXT NOT NULL,                            -- 주소 (원본)
    detail TEXT,                                      -- 상세 위치 설명
    postal_code VARCHAR(10),                          -- 우편번호
    standardized_address TEXT,                        -- 표준화주소
    jibun_address TEXT,                              -- 지번주소
    longitude DECIMAL(10, 7),                        -- 경도 (카카오 API)
    latitude DECIMAL(10, 7),                         -- 위도 (카카오 API)
    verification_status VARCHAR(10) DEFAULT 'pending', -- 검증상태 (성공, 실패, pending)
    coordinate_status VARCHAR(10) DEFAULT 'pending',   -- 좌표변환상태 (성공, 실패, pending)
    verification_date TIMESTAMP,                      -- 검증일시
    coordinate_date TIMESTAMP,                        -- 좌표변환일시
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,   -- 생성일시
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP    -- 수정일시
);

-- 4. 인덱스 생성 (검색 성능 최적화)
CREATE INDEX idx_smoking_areas_location ON smoking_areas(latitude, longitude);
CREATE INDEX idx_smoking_areas_category ON smoking_areas(category);
CREATE INDEX idx_smoking_areas_postal_code ON smoking_areas(postal_code);
CREATE INDEX idx_smoking_areas_verification ON smoking_areas(verification_status);

-- 5. 업데이트 트리거 함수 생성 (updated_at 자동 갱신)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 6. 트리거 연결
CREATE TRIGGER update_smoking_areas_updated_at
    BEFORE UPDATE ON smoking_areas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. 샘플 데이터 조회용 뷰 생성
CREATE VIEW complete_smoking_areas AS
SELECT
    id,
    category,
    address,
    detail,
    postal_code,
    longitude,
    latitude,
    created_at
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
  AND longitude IS NOT NULL
  AND latitude IS NOT NULL;

-- 8. 거리 계산 함수 (하버사인 공식)
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DECIMAL, lng1 DECIMAL,
    lat2 DECIMAL, lng2 DECIMAL
) RETURNS DECIMAL AS $$
DECLARE
    earth_radius DECIMAL := 6371000; -- 지구 반지름 (미터)
    dlat DECIMAL;
    dlng DECIMAL;
    a DECIMAL;
    c DECIMAL;
BEGIN
    dlat := RADIANS(lat2 - lat1);
    dlng := RADIANS(lng2 - lng1);

    a := SIN(dlat/2) * SIN(dlat/2) +
         COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
         SIN(dlng/2) * SIN(dlng/2);

    c := 2 * ATAN2(SQRT(a), SQRT(1-a));

    RETURN earth_radius * c;
END;
$$ LANGUAGE plpgsql;

-- 9. 주변 흡연구역 검색 함수
CREATE OR REPLACE FUNCTION find_nearby_smoking_areas(
    user_lat DECIMAL,
    user_lng DECIMAL,
    radius_meters INTEGER DEFAULT 1000
) RETURNS TABLE(
    id INTEGER,
    category VARCHAR(20),
    address TEXT,
    detail TEXT,
    distance_meters DECIMAL,
    longitude DECIMAL,
    latitude DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sa.id,
        sa.category,
        sa.address,
        sa.detail,
        calculate_distance(user_lat, user_lng, sa.latitude, sa.longitude) as distance_meters,
        sa.longitude,
        sa.latitude
    FROM smoking_areas sa
    WHERE sa.verification_status = '성공'
      AND sa.coordinate_status = '성공'
      AND sa.longitude IS NOT NULL
      AND sa.latitude IS NOT NULL
      AND calculate_distance(user_lat, user_lng, sa.latitude, sa.longitude) <= radius_meters
    ORDER BY distance_meters ASC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- 테이블 정보 확인
\d smoking_areas;