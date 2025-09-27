-- 단순화된 흡연구역 데이터베이스 스키마
-- 네이버 Maps API 활용을 고려한 최소 구조

-- 1. 데이터베이스 생성
CREATE DATABASE smoking_areas_db;

-- 2. 데이터베이스 연결 후 실행
\c smoking_areas_db;

-- 3. 흡연구역 테이블 생성 (단순화)
CREATE TABLE smoking_areas (
    id SERIAL PRIMARY KEY,
    category VARCHAR(20) NOT NULL,           -- 카테고리 (부분 개방형, 완전 폐쇄형)
    address TEXT NOT NULL,                   -- 주소
    detail TEXT,                            -- 상세 위치 설명
    postal_code VARCHAR(10),                -- 우편번호
    longitude DECIMAL(10, 7) NOT NULL,      -- 경도
    latitude DECIMAL(10, 7) NOT NULL,       -- 위도
    status VARCHAR(10) DEFAULT 'active',    -- 상태 (active, inactive)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. 기본 인덱스만 생성
CREATE INDEX idx_smoking_areas_location ON smoking_areas(latitude, longitude);
CREATE INDEX idx_smoking_areas_category ON smoking_areas(category);
CREATE INDEX idx_smoking_areas_status ON smoking_areas(status);

-- 5. 업데이트 트리거
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_smoking_areas_updated_at
    BEFORE UPDATE ON smoking_areas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6. 활성 흡연구역 조회 뷰
CREATE VIEW active_smoking_areas AS
SELECT
    id,
    category,
    address,
    detail,
    postal_code,
    longitude,
    latitude
FROM smoking_areas
WHERE status = 'active';

-- 테이블 구조 확인
\d smoking_areas;