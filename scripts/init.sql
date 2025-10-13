-- 흡연구역 데이터베이스 초기화 스크립트
-- Docker PostgreSQL 컨테이너 시작 시 자동 실행

-- 흡연구역 테이블 생성
CREATE TABLE IF NOT EXISTS smoking_areas (
    id SERIAL PRIMARY KEY,
    category VARCHAR(20) NOT NULL,
    submitted_category VARCHAR(20),
    address TEXT NOT NULL,
    detail TEXT,
    postal_code VARCHAR(10),
    longitude DECIMAL(10, 7) NOT NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    status VARCHAR(10) DEFAULT 'active',
    report_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_smoking_areas_location ON smoking_areas(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_smoking_areas_category ON smoking_areas(category);
CREATE INDEX IF NOT EXISTS idx_smoking_areas_status ON smoking_areas(status);

-- 업데이트 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 트리거 생성
DROP TRIGGER IF EXISTS update_smoking_areas_updated_at ON smoking_areas;
CREATE TRIGGER update_smoking_areas_updated_at
    BEFORE UPDATE ON smoking_areas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 뷰 생성
CREATE OR REPLACE VIEW active_smoking_areas AS
SELECT
    id,
    category,
    submitted_category,
    address,
    detail,
    postal_code,
    longitude,
    latitude,
    report_count,
    created_at
FROM smoking_areas
WHERE status = 'active';

-- 초기 데이터 확인
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM smoking_areas LIMIT 1) THEN
        RAISE NOTICE '흡연구역 테이블이 비어있습니다. scripts/database_manager.py를 실행해서 데이터를 가져오세요.';
    END IF;
END $$;
