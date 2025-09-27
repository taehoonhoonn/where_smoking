# 흡연구역 찾기 앱 - 개발 현황 및 향후 계획

## 📋 프로젝트 개요
- **프로젝트명**: 흡연구역 찾기 앱 (흡연구역 지도 서비스)
- **개발 기간**: 2025년 9월 20일 ~ 진행 중
- **개발 환경**: WSL2 + PostgreSQL 15 + Node.js + Flutter Web
- **목표**: 현위치 기반 주변 흡연구역 검색 및 신규 등록 모바일 앱

## ✅ 완료된 기능

### 1. 데이터 파이프라인
- ✅ **CSV 데이터 수집**: 51개 지자체 데이터 → 1,715개 주소 추출
- ✅ **주소 검증**: Postcodify API로 76.1% 성공률
- ✅ **좌표 변환**: 카카오 Local API로 정확한 위도/경도 획득
- ✅ **최종 데이터**: 30개 완전한 흡연구역 정보 (28개 기존 + 2개 신규 승인)

### 2. 백엔드 API 시스템
- ✅ **PostgreSQL 데이터베이스**: 완전한 스키마 및 인덱싱
- ✅ **RESTful API**: Express.js 기반 완전한 CRUD
- ✅ **실시간 로깅**: Winston으로 모든 요청/응답/SQL 추적
- ✅ **거리 계산**: 하버사인 공식으로 정확한 근처 검색
- ✅ **데이터 검증**: Joi를 통한 엄격한 입력 검증

#### API 엔드포인트
```
GET  /api/v1/health                     - 서버 상태 확인
GET  /api/v1/smoking-areas              - 모든 흡연구역 조회
GET  /api/v1/smoking-areas/nearby       - 주변 검색 (하버사인 공식)
GET  /api/v1/smoking-areas/statistics   - 통계 정보
GET  /api/v1/smoking-areas/:id          - 특정 흡연구역 조회
POST /api/v1/smoking-areas/pending      - 신규 등록 신청
GET  /api/v1/smoking-areas/pending      - 대기 중인 신청 목록 (관리자)
PATCH /api/v1/smoking-areas/:id/approve - 신청 승인 (관리자)
DELETE /api/v1/smoking-areas/:id/reject - 신청 거부 (관리자)
```

### 3. Flutter 웹 앱
- ✅ **4개 탭 구조**: 흡연구역 목록 / 지도 / 관리자 / API 테스트
- ✅ **흡연구역 목록**: 실시간 검색, 카드형 UI, 카테고리별 색상 구분
- ✅ **네이버 지도 연동**: 마커 표시, 정보창, 범위 자동 조정
- ✅ **관리자 페이지**: 대기 신청 목록, 승인/거부 처리
- ✅ **API 테스트 도구**: 개발자용 실시간 디버깅

### 4. 신규 장소 등록 시스템
- ✅ **사용자 등록**: 지도 길게 누르기 → 상세 정보 입력 → 대기 상태
- ✅ **관리자 승인**: 관리자 페이지에서 승인/거부 처리
- ✅ **워크플로우**: 등록 → 검토 → 승인 → 지도 표시

### 5. 기술적 구현
- ✅ **CORS 설정**: 웹앱-API 간 원활한 통신
- ✅ **상태 관리**: pending/active/rejected 상태 체계
- ✅ **오류 처리**: 완전한 예외 처리 및 사용자 피드백
- ✅ **성능 최적화**: 연결 풀링, 쿼리 최적화

## 🔄 현재 진행 중인 문제

### 1. 승인 기능 오류
- **문제**: Flutter에서 PATCH 요청 시 "Failed to fetch" 오류
- **상태**: 디버깅 중 (API 서버는 정상, 클라이언트 문제 추정)
- **해결 방안**: 브라우저 개발자 도구로 네트워크 요청 분석 필요

### 2. 지도 중복 팝업
- **문제**: 길게 누르기 시 등록 다이얼로그가 2번 표시
- **상태**: 부분 해결 시도 (longPressExecuted 플래그 추가)
- **해결 방안**: 이벤트 디바운싱 추가 구현 필요

## 🚀 향후 개발 계획

### Phase 1: 현재 문제 해결 (우선순위 높음)
- [ ] **승인 기능 디버깅**: PATCH 요청 오류 해결
- [ ] **중복 팝업 방지**: 지도 이벤트 처리 개선
- [ ] **모바일 최적화**: 터치 이벤트 및 반응형 UI 개선

### Phase 2: 사용자 관리 시스템
- [ ] **회원가입/로그인**: Firebase Auth 또는 JWT 기반 인증
- [ ] **사용자 프로필**: 개인정보, 선호도 설정
- [ ] **즐겨찾기**: 자주 가는 흡연구역 저장
- [ ] **사용 이력**: 방문한 흡연구역 기록

### Phase 3: 소셜 기능
- [ ] **리뷰 시스템**: 흡연구역별 평점 및 후기
- [ ] **사진 업로드**: 실제 흡연구역 사진 공유
- [ ] **신고 시스템**: 부정확한 정보 신고 및 수정
- [ ] **커뮤니티**: 사용자 간 정보 공유

### Phase 4: 고급 기능
- [ ] **GPS 연동**: 실제 현재 위치 기반 검색
- [ ] **길찾기**: 외부 지도앱 연동
- [ ] **알림 시스템**: 새로운 흡연구역 알림
- [ ] **오프라인 모드**: 주요 데이터 로컬 캐싱

### Phase 5: 모바일 앱 전환
- [ ] **웹뷰 앱**: 현재 Flutter Web을 웹뷰로 래핑
- [ ] **네이티브 앱**: Android/iOS 네이티브 기능 활용
- [ ] **푸시 알림**: 실시간 알림 시스템
- [ ] **앱스토어 배포**: 구글플레이/앱스토어 출시

### Phase 6: 데이터 확장
- [ ] **전국 데이터**: 서울 외 지역 흡연구역 수집
- [ ] **실시간 업데이트**: 지자체 API 연동으로 자동 업데이트
- [ ] **크라우드소싱**: 사용자 참여형 데이터 수집
- [ ] **AI 검증**: 머신러닝으로 데이터 품질 관리

## 🎯 기술 스택 및 아키텍처

### 현재 기술 스택
```
Frontend: Flutter Web
Backend: Node.js + Express.js
Database: PostgreSQL 15
External APIs: 네이버 Maps, 카카오 Local API
Logging: Winston
Validation: Joi
HTTP Client: curl (테스트)
```

### 향후 추가 예정 기술
```
Authentication: Firebase Auth / JWT
Image Storage: AWS S3 / Firebase Storage
Push Notifications: Firebase Cloud Messaging
Analytics: Google Analytics / Firebase Analytics
Monitoring: Sentry / DataDog
CI/CD: GitHub Actions
Deployment: Docker + AWS / Vercel
```

## 📊 데이터 현황

### 현재 데이터
- **총 흡연구역**: 30개 (활성화 상태)
- **지역 분포**: 주로 서울 중심가 (성동구, 중구, 용산구, 노원구)
- **카테고리**: 부분 개방형 / 완전 폐쇄형
- **좌표 정확도**: 100% (카카오 API 검증 완료)

### 데이터 확장 계획
- **1차 목표**: 서울 전체 500개 흡연구역
- **2차 목표**: 수도권 1,000개 흡연구역
- **3차 목표**: 전국 주요 도시 5,000개 흡연구역

## 🔧 개발 환경 설정

### 현재 실행 명령어
```bash
# PostgreSQL 시작
sudo service postgresql start

# API 서버 시작 (포트 3001)
cd api_server && PORT=3001 node server.js

# Flutter 웹 앱 시작 (포트 8080)
cd app && ~/flutter/bin/flutter run -d web-server --web-port=8080
```

### 개발 도구
- **데이터베이스 관리**: `python3 scripts/database_manager.py`
- **API 테스트**: curl + 내장 API 테스트 화면
- **로그 모니터링**: Winston 실시간 로깅
- **디버깅**: 브라우저 개발자 도구

## 📝 개발 참고사항

### 중요 제약사항
- 네이버 지도 API 키 설정 시 즉시 활성화 가능한 구조
- 웹뷰 앱 전환을 고려한 아키텍처 설계
- 관리자 승인 시스템으로 데이터 품질 관리

### 성능 고려사항
- PostgreSQL 인덱싱으로 위치 기반 검색 최적화
- 연결 풀링으로 데이터베이스 성능 향상
- 캐싱 전략 구현 예정

### 보안 고려사항
- API 입력 검증 (Joi)
- SQL 인젝션 방지 (Parameterized Query)
- 향후 인증/인가 시스템 구현 예정

---

**마지막 업데이트**: 2025년 9월 22일 21:18 (KST)
**다음 마일스톤**: 승인 기능 오류 해결 및 사용자 인증 시스템 구현