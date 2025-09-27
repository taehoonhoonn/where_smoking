-- 흡연구역 데이터베이스 샘플 쿼리
-- 앱 개발 시 참고할 주요 쿼리들

-- 1. 전체 흡연구역 조회 (완전한 데이터만)
SELECT
    id,
    category,
    address,
    detail,
    postal_code,
    longitude,
    latitude
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
  AND longitude IS NOT NULL
  AND latitude IS NOT NULL
ORDER BY id;

-- 2. 카테고리별 흡연구역 조회
SELECT
    category,
    address,
    detail,
    longitude,
    latitude
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
  AND category = '부분 개방형' -- 또는 '완전 폐쇄형'
ORDER BY address;

-- 3. 특정 위치 주변 1km 내 흡연구역 검색
-- 예시: 서울역 주변 (37.5547, 126.9707)
SELECT * FROM find_nearby_smoking_areas(37.5547, 126.9707, 1000);

-- 4. 특정 위치 주변 500m 내 가장 가까운 5개 흡연구역
SELECT
    category,
    address,
    detail,
    calculate_distance(37.5547, 126.9707, latitude, longitude) as distance_meters,
    longitude,
    latitude
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
  AND calculate_distance(37.5547, 126.9707, latitude, longitude) <= 500
ORDER BY distance_meters ASC
LIMIT 5;

-- 5. 구별 흡연구역 개수 (주소 기반)
SELECT
    CASE
        WHEN address LIKE '%중구%' THEN '중구'
        WHEN address LIKE '%용산구%' THEN '용산구'
        WHEN address LIKE '%성동구%' THEN '성동구'
        WHEN address LIKE '%광진구%' THEN '광진구'
        WHEN address LIKE '%동대문구%' THEN '동대문구'
        WHEN address LIKE '%노원구%' THEN '노원구'
        WHEN address LIKE '%강서구%' THEN '강서구'
        ELSE '기타'
    END as district,
    COUNT(*) as count
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
GROUP BY district
ORDER BY count DESC;

-- 6. 최근 추가된 흡연구역 (최근 7일)
SELECT
    category,
    address,
    detail,
    created_at
FROM smoking_areas
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
  AND verification_status = '성공'
  AND coordinate_status = '성공'
ORDER BY created_at DESC;

-- 7. 특정 우편번호 지역의 흡연구역
SELECT
    address,
    detail,
    category,
    longitude,
    latitude
FROM smoking_areas
WHERE postal_code = '04533' -- 롯데백화점 지역
  AND verification_status = '성공'
  AND coordinate_status = '성공';

-- 8. 좌표 범위로 검색 (바운딩 박스)
-- 예시: 서울 중구 일대
SELECT
    address,
    detail,
    category,
    longitude,
    latitude
FROM smoking_areas
WHERE latitude BETWEEN 37.560 AND 37.570
  AND longitude BETWEEN 126.975 AND 126.985
  AND verification_status = '성공'
  AND coordinate_status = '성공'
ORDER BY latitude, longitude;

-- 9. 흡연구역 타입별 평균 위치 (중심점 계산)
SELECT
    category,
    COUNT(*) as count,
    AVG(latitude) as avg_latitude,
    AVG(longitude) as avg_longitude
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
GROUP BY category;

-- 10. API 응답용 GeoJSON 형태 데이터
SELECT
    json_build_object(
        'type', 'Feature',
        'properties', json_build_object(
            'id', id,
            'category', category,
            'address', address,
            'detail', detail,
            'postal_code', postal_code
        ),
        'geometry', json_build_object(
            'type', 'Point',
            'coordinates', json_build_array(longitude, latitude)
        )
    ) as geojson
FROM smoking_areas
WHERE verification_status = '성공'
  AND coordinate_status = '성공'
LIMIT 5;