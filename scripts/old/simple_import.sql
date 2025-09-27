-- 단순화된 CSV 데이터 임포트
-- smoking_areas_db 데이터베이스에 연결된 상태에서 실행

-- 1. 임시 테이블 생성
CREATE TEMP TABLE temp_smoking_data (
    category VARCHAR(20),
    address TEXT,
    detail TEXT,
    postal_code VARCHAR(10),
    latitude_old DECIMAL,
    longitude_old DECIMAL,
    standardized_address TEXT,
    jibun_address TEXT,
    verification_status VARCHAR(10),
    verification_date VARCHAR(50),
    kakao_longitude DECIMAL(10, 7),
    kakao_latitude DECIMAL(10, 7),
    coordinate_status VARCHAR(10),
    coordinate_date VARCHAR(50)
);

-- 2. CSV 파일 임포트
COPY temp_smoking_data FROM '/mnt/c/Users/admin/where_smoking/where_smoking/scripts/final_smoking_places_with_coordinates_20250920_192227.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- 3. 성공한 데이터만 메인 테이블로 이관
INSERT INTO smoking_areas (
    category,
    address,
    detail,
    postal_code,
    longitude,
    latitude,
    status
)
SELECT
    category,
    address,
    detail,
    postal_code,
    kakao_longitude,
    kakao_latitude,
    'active'
FROM temp_smoking_data
WHERE coordinate_status = '성공'
  AND kakao_longitude IS NOT NULL
  AND kakao_latitude IS NOT NULL
  AND category IS NOT NULL;

-- 4. 결과 확인
SELECT
    COUNT(*) as total_count,
    COUNT(CASE WHEN category = '부분 개방형' THEN 1 END) as partial_open,
    COUNT(CASE WHEN category = '완전 폐쇄형' THEN 1 END) as fully_closed
FROM smoking_areas;

-- 5. 샘플 데이터 조회
SELECT * FROM active_smoking_areas LIMIT 5;