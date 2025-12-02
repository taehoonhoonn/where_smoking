# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

흡연구역 찾기 앱 - 네이버 지도 API를 활용하여 사용자 주변 흡연구역을 찾아주는 웹 애플리케이션. PostgreSQL 데이터베이스, Node.js REST API 서버, Flutter 웹 클라이언트로 구성되며 시민제보 기능과 관리자 승인 시스템을 포함합니다.

## 시스템 아키텍처

### 3계층 구조
- **데이터베이스**: PostgreSQL 15 (서울시 공공데이터 + 시민제보 440+개 흡연구역)
- **API 서버**: Node.js/Express (Winston 로깅, Joi 검증, 완전한 CRUD)
- **프론트엔드**: Flutter 웹앱 (네이버 지도 연동, 시민제보, 관리자 기능)

### 핵심 컴포넌트
- `api_server/`: Express REST API (속도 제한, CORS, helmet 보안)
- `app/`: Flutter 웹 클라이언트 (지도, 멀티탭 UI: 목록/지도/관리자/테스트)
- `scripts/`: Python 데이터 파이프라인 (CSV 임포트, 지오코딩, 데이터베이스 관리)
- `docs/`: 개발 계획 및 문서

## 개발 명령어

### 데이터베이스 설정
```bash
# PostgreSQL 서비스 시작
sudo service postgresql start

# 데이터베이스 초기화 및 데이터 임포트
cd scripts
python3 database_manager.py setup

# 데이터베이스 통계 확인
python3 database_manager.py stats

# 원시 CSV에서 지오코딩과 함께 재임포트
python3 reseed_from_raw.py
```

### API 서버
```bash
cd api_server
npm install
npm start          # 프로덕션 서버 (포트 3000)
npm run dev        # nodemon 개발 모드
npm run debug      # 디버그 모드 (inspector)
npm test           # Jest 테스트 실행
```

### Flutter 웹앱
```bash
cd app
flutter pub get
flutter run -d web-server --web-port=8080

# 모바일 WebView 개발
flutter run --dart-define=USE_LOCAL_WEB_APP=true \
           --dart-define=LOCAL_WEB_APP_URL=http://localhost:8080 \
           -d android
```

### 설정 파일 준비
```bash
# API 서버 환경설정
cp api_server/.env.example api_server/.env
# 데이터베이스 인증정보 및 CORS 설정 편집

# 스크립트 환경설정 (데이터 파이프라인용)
cp scripts/.env.example scripts/.env
# 지오코딩용 Kakao API 키 추가

# 웹 클라이언트 설정
cp app/web/config.sample.js app/web/config.js
# NAVER_MAP_KEY와 API_BASE_URL 설정
```

## 주요 개발 워크플로우

### 시민제보 플로우
1. 사용자가 지도에서 길게 누름 (모바일: `longtap`, 데스크톱: `mousedown` 타이머)
2. 좌표 없이 확인 다이얼로그 표시 (개인정보 보호)
3. 상세 입력 폼에서 카테고리 선택 (공식/비공식 흡연장소)
4. 제출 시 `submitted_category`와 함께 `pending` 상태로 저장
5. 관리자가 승인/거부 처리

### 관리자 시스템
- **2개 탭 인터페이스**: 대기 신청 / 신고된 장소
- **승인 워크플로우**: `pending` → `active` (승인) 또는 `rejected` (거부)
- **허위신고**: 사용자가 신고 가능, 관리자는 신고 횟수순으로 확인
- **지도 네비게이션**: "지도에서 보기" 버튼으로 관리자 → 지도 탭 자동 전환 및 해당 위치 이동
- **색상별 마커**: 공식 시민제보 (초록), 비공식 (노랑), 공공데이터 (파랑)

### 사용자 필터링 시스템
- **클릭 가능한 필터 범례**: 좌측 하단 범례가 인터랙티브 필터 버튼으로 동작
- **실시간 마커 토글**: 각 카테고리별로 마커 표시/숨김 즉시 반영
- **필터 지속성**: 지도 이동, 앱 복귀, 뷰포트 변경 시에도 사용자가 설정한 필터 상태 유지
- **시각적 피드백**: 활성화된 필터는 색상 테두리+체크 아이콘, 비활성화는 반투명 처리

### 데이터 파이프라인 구조
- 원시 CSV → Kakao API 지오코딩 → PostgreSQL 좌표 저장
- 지오코딩 실패 건은 `failed_geocoding_*.json` 파일로 기록
- 데이터베이스 스키마는 상태 추적, 신고 횟수, 카테고리 관리 지원

## API 아키텍처

### 핵심 엔드포인트
- `GET /api/v1/smoking-areas` - 모든 활성 흡연구역 목록 (페이징)
- `GET /api/v1/smoking-areas/nearby?lat=37.5&lng=126.9` - 근접 검색 (하버사인 공식)
- `GET /api/v1/smoking-areas/statistics` - 카테고리 및 지역별 통계
- `POST /api/v1/smoking-areas/pending` - 시민제보 제출
- `GET /api/v1/smoking-areas/pending` - 관리자: 대기 신청 목록
- `GET /api/v1/smoking-areas/reported` - 관리자: 신고된 장소 목록 (신고 횟수순)

### 요청/응답 패턴
- 모든 응답은 `{ success: boolean, data: any, error?: string }` 형식 사용
- 디버깅과 모니터링을 위한 Winston 종합 로깅
- 상세한 오류 메시지와 함께 모든 입력 매개변수 Joi 검증
- 속도 제한 및 보안 헤더 (helmet, CORS) 설정

## 네이버 지도 연동

### JavaScript 상호작용
- `app/web/index.html`에서 네이버 지도 스크립트와 함께 지도 초기화
- `flutter_marker_renderer.js`를 통한 커스텀 마커 렌더링
- `js.context` 콜백을 통한 Dart-JavaScript 통신
- 신고 횟수와 액션 버튼이 있는 InfoWindow HTML 생성

### 지도 기능
- **동적 마커**: 카테고리별 색상 구분 (공공/공식 시민제보/비공식 시민제보)
- **길게 누르기 감지**: 위치 제출을 위한 크로스플랫폼 이벤트 처리
- **정보 창**: 상세정보, 신고 횟수, 허위신고 버튼 표시
- **실시간 필터링**: 카테고리별 마커 표시/숨김 토글, 지도 이동/앱 복귀 시에도 필터 상태 유지

## 테스트 및 품질관리

### 자동화 테스트
- API 컨트롤러, 미들웨어, 라우트를 위한 Jest 테스트
- UI 컴포넌트를 위한 Flutter 위젯 테스트
- `api_server/test-connection.js`를 통한 데이터베이스 통합 테스트

### 수동 테스트 워크플로우
- 서비스 모니터링을 위한 헬스체크 API 엔드포인트
- 엔드포인트 검증을 위한 Flutter 앱 내장 API 테스트 탭
- 승인 워크플로우 테스트를 위한 관리자 인터페이스
- 요청/응답 디버깅을 위한 실시간 로깅

## 설정 관리

### 환경변수
- **API 서버**: 데이터베이스 인증정보, CORS 도메인, 로깅 레벨
- **스크립트**: 지오코딩용 Kakao API 키, 데이터베이스 연결정보
- **웹 클라이언트**: 네이버 지도 API 키, 관리자 액세스 토큰

### 보안 고려사항
- 관리자 기능은 서버 `.env`와 클라이언트 `config.js` 모두에 `ADMIN_ACCESS_TOKEN` 필요
- 데이터베이스 인증정보와 API 키는 `.gitignore`로 git에서 제외
- API 남용 방지를 위한 속도 제한
- SQL 인젝션과 XSS 방지를 위한 입력 검증

## 데이터 모델

### 핵심 엔티티: smoking_areas
```sql
- id (serial primary key)
- category (varchar): 'public_data' | 'citizen_report'
- submitted_category (varchar): 시민제보 시 사용자가 선택한 유형
- address, detail (text): 위치 정보
- latitude, longitude (decimal): 근접 검색용 좌표
- status (varchar): 'pending' | 'active' | 'rejected'
- report_count (integer): 허위신고 카운터
- created_at, updated_at (timestamps)
```

### 데이터 흐름
1. **공공데이터**: `reseed_from_raw.py`로 status='active'로 임포트
2. **시민제보**: status='pending'으로 제출, 관리자가 'active'/'rejected'로 변경
3. **허위신고**: report_count 증가, 관리자가 높은 신고 횟수 장소 검토

## 성능 및 확장성

### 데이터베이스 최적화
- 근접 쿼리를 위한 위도/경도 공간 인덱스
- 설정 가능한 타임아웃과 함께 Node.js 커넥션 풀링
- SQL 인젝션 방지를 위한 prepared statement

### 클라이언트 성능
- Flutter 웹 컴파일로 번들 크기 최적화
- 커스텀 JavaScript를 통한 효율적인 지도 마커 렌더링
- 적절한 API 응답 캐싱 (헬스체크, 통계)

### 모니터링 및 디버깅
- 요청 ID와 함께 Winston 구조화 로깅
- 실시간 API 요청/응답 로깅
- 데이터베이스 쿼리 타이밍 및 결과 수 로깅
- 스택 추적 및 컨텍스트와 함께 오류 추적