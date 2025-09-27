# 흡연구역 찾기 API 서버

디버깅과 로깅을 고려한 프로덕션 레디 Node.js API 서버입니다.

## 🚀 빠른 시작

### 1. 의존성 설치
```bash
cd api_server
npm install
```

### 2. 환경 변수 설정
`.env` 파일에서 데이터베이스 연결 정보를 확인하세요:
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=smoking_areas_db
DB_USER=postgres
DB_PASSWORD=postgres
```

### 3. 서버 실행

**개발 모드 (auto-reload)**
```bash
npm run dev
```

**디버그 모드 (Chrome DevTools)**
```bash
npm run debug
# 그후 Chrome에서 chrome://inspect 접속
```

**프로덕션 모드**
```bash
npm start
```

## 📊 API 엔드포인트

### 헬스체크
```bash
GET /api/v1/health
GET /api/v1/health/database
```

### 흡연구역 조회
```bash
# 모든 흡연구역
GET /api/v1/smoking-areas

# 주변 검색 (필수: lat, lng)
GET /api/v1/smoking-areas/nearby?lat=37.5547&lng=126.9707&radius=1000&limit=10

# 특정 흡연구역
GET /api/v1/smoking-areas/123

# 카테고리별 조회
GET /api/v1/smoking-areas/category/부분%20개방형

# 통계 정보
GET /api/v1/smoking-areas/statistics
```

## 🔍 디버깅 기능

### 1. 로그 파일
- `logs/combined.log` - 모든 로그
- `logs/error.log` - 에러만
- 콘솔 출력 (개발 모드)

### 2. 디버그 옵션
`.env` 파일에서 설정:
```bash
DEBUG_SQL=true      # SQL 쿼리 로그
DEBUG_API=true      # API 요청 디버그
LOG_LEVEL=debug     # 로그 레벨
```

### 3. 요청 추적
모든 API 요청에 고유 ID가 부여되어 로그에서 추적 가능:
```json
{
  "requestId": "abc123def",
  "method": "GET",
  "url": "/api/v1/smoking-areas/nearby",
  "duration": "45ms"
}
```

## 🛡️ 보안 기능

- **Rate Limiting**: 15분에 100회 요청 제한
- **Helmet**: 보안 헤더 자동 설정
- **CORS**: 크로스 오리진 요청 제어
- **Input Validation**: Joi를 사용한 엄격한 검증

## 📈 모니터링

### 실시간 로그 확인
```bash
# 모든 로그
tail -f logs/combined.log

# 에러만
tail -f logs/error.log

# 실시간 필터링
tail -f logs/combined.log | grep "ERROR"
```

### 헬스체크 모니터링
```bash
# 기본 헬스체크
curl http://localhost:3000/api/v1/health

# 데이터베이스 상세 체크
curl http://localhost:3000/api/v1/health/database
```

## 🧪 테스트

### API 테스트 예제
```bash
# 서버 실행 후
curl "http://localhost:3000/api/v1/smoking-areas/nearby?lat=37.5547&lng=126.9707&radius=1000"
```

### 예상 응답
```json
{
  "success": true,
  "query": {
    "latitude": 37.5547,
    "longitude": 126.9707,
    "radius_meters": 1000
  },
  "count": 5,
  "smoking_areas": [
    {
      "id": 1,
      "category": "부분 개방형",
      "address": "서울특별시 중구 을지로 30",
      "detail": "롯데백화점 측면부",
      "coordinates": {
        "longitude": 126.9810075639,
        "latitude": 37.5653458904198
      },
      "distance_meters": 245
    }
  ]
}
```

## 🚨 문제 해결

### 1. 데이터베이스 연결 실패
```bash
# PostgreSQL 서비스 확인
sudo service postgresql status

# 연결 테스트
psql -h localhost -p 5432 -U postgres -d smoking_areas_db
```

### 2. 로그에서 에러 확인
```bash
grep "ERROR" logs/combined.log | tail -10
```

### 3. 디버그 모드로 실행
```bash
npm run debug
```
Chrome에서 `chrome://inspect` → **Open dedicated DevTools for Node** 클릭