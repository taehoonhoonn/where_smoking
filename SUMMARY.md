# 흡연구역 찾기 앱 - 개발 현황

## 프로젝트 개요
- **서비스명**: 흡연구역 찾기 앱 (위치 기반 흡연구역 지도 서비스)
- **개발 환경**: WSL2 · PostgreSQL 15 · Node.js (Express) · Flutter Web
- **목표**: 주변 흡연구역 검색, 신규 제보·승인 워크플로우 구축, 데이터 품질 유지

## 완료된 개발 사항
- **데이터 파이프라인**
  - 원천 CSV(`old/data/smoking_place_raw.csv`) 기반 469건 전수 재처리 → 좌표 보유 188건 재사용 + 카카오 API 281회 호출 → 좌표가 있는 440건만 DB 적재
  - `scripts/reseed_from_raw.py`로 원천 교체 자동화, 좌표 실패 29건은 JSON 리포트에 별도 저장
  - 기존 파이프라인 스크립트는 `scripts/`에 유지, 산출물은 `old/data_exports/`로 관리
- **백엔드 API**
  - Express 기반 REST CRUD, PostgreSQL 커넥션 풀, 하버사인 거리 검색, Joi 입력 검증, Winston 로깅 구현
  - 시민제보는 항상 `category='시민제보'`, 제보자가 고른 유형은 `submitted_category`에 저장해 승인 후에도 출처 구분 가능
  - `GET /health`, `/smoking-areas`, `/smoking-areas/nearby`, `/smoking-areas/statistics`, 승인/거부 엔드포인트 등 전면 동작
  - 환경 변수 템플릿 `api_server/.env.example` 추가
- **Flutter Web 클라이언트**
  - 4탭 구조(흡연구역 목록·지도·관리자·API 테스트) 완성, `IndexedStack`으로 페이지 상태 유지
  - 네이버 지도 long-press 등록, 시민제보는 자동으로 `category='시민제보'`로 제출되도록 단순화
  - 관리자 화면은 소스 분류(공공데이타/시민제보)를 뱃지로 구분, 지도 키는 `web/config.sample.js` → `config.js`로 분리
  - 지도 범례·시민제보 마커를 실제 색상/모양과 일치시켰고, 인포윈도우는 상세 설명을 제목으로 표시하며 신고 버튼만 유지
  - `window.ADMIN_ACCESS_TOKEN`이 존재하면 지도 우측 상단에서 관리자 모드를 토글할 수 있고, 활성화 시 마커 팝업에 “지도에서 삭제” 버튼이 추가되어 즉시 제거 가능
- **보안/구성 정리**
  - `.gitignore` 갱신으로 비밀 파일·캐시·산출물 제외, `scripts/.env.example` 추가
  - 네이버 지도 키 하드코딩 제거, 콘솔 경고 최소화(컨테이너 재시도 로직 조정)
  - `ADMIN_ACCESS_TOKEN` 기반 관리자 인증 미들웨어 도입 (`X-Admin-Token` 헤더), Flutter·API 샘플 설정 및 AGENTS 가이드에 동시 반영
  - 활성화된 흡연구역 삭제용 REST 엔드포인트(`DELETE /api/v1/smoking-areas/:id`) 추가, 삭제 시 DB 상태를 `deleted`로 기록

## 해결된 이슈
- 지도 탭 이동 시 마커 사라짐 → `IndexedStack` 적용으로 상태 유지
- 초기 진입 시 지도 컨테이너 미발견 경고 → 재시도 로직 수정으로 경고 최소화
- 승인 기능 PATCH 오류 → Flutter 측 요청 처리 수정으로 해결
- 시민제보와 공공데이타 분류를 이원화하고 승인 시 자동으로 `시민제보` 카테고리 부여

## 향후 개선 제안
1. Flutter 빌드 파이프라인에서 지도 키 자동 주입(Dart define, 배포 스크립트 등)
2. API/Flutter 기본 스모크 테스트와 CI 연계로 회귀 조기 감지
3. 사용자 참여 기능(리뷰, 즐겨찾기, 신고/요청) 단계적 구현
4. 데이터 파이프라인 스크립트 출력 경로 표준화 및 자동화
