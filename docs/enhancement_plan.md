# Service Enhancement Implementation Plan

## Overview
사용자로부터 요청된 6개의 고도화 과제를 아래와 같이 분석했습니다. 1~5번은 지도/시민제보 UX 개선 및 관리자 모니터링 강화에 해당하고, 6번은 다국어(영문) 지원을 위한 구조 개편입니다. 본 문서는 각 과제를 어떻게 반영할지와 의존성, 위험 요소, 검증 방법을 정리합니다.

## Requirement Breakdown & Proposed Approach

### 1. 시민제보 다이얼로그에서 좌표 노출 제거
- **현황**: `_showAddLocationDialog`와 `_showLocationDetailDialog`에 위/경도 텍스트가 그대로 표시됩니다.
- **변경안**: 사용자에게는 "선택한 위치" 정도의 안내만 보여주고 좌표는 숨깁니다. 추후 역지오코딩(요구사항 #2)으로 확보한 주소를 노출합니다.
- **작업**:
  1. 첫 번째 확인 AlertDialog에서 좌표 문자열 대신 "지도에서 선택한 위치" 문구로 교체.
  2. 상세 입력 다이얼로그에서도 좌표를 제거하고, 역지오코딩이 완료되면 주소를 띄우도록 UI 업데이트.
- **검증**: 지도 롱프레스 → 다이얼로그에서 좌표가 더 이상 보이지 않는지 확인.

### 2. 시민제보 주소 역지오코딩
- **현황**: `createPendingArea`가 주소를 `서울특별시 (lat, lng)`로 저장합니다.
- **라이브러리 검토**: Naver Maps JS 튜토리얼(Geocoder)과 Kakao Local `coord2address` REST API가 공식적으로 역지오코딩을 지원합니다. 현재 작업 환경은 외부 도큐먼트 접근이 제한되어 있어 링크를 직접 열람하진 못했으나, 제공해 주신 문서를 기준으로 `naver.maps.Service.reverseGeocode`를 활용하겠습니다. 필요 시 Kakao API를 백엔드 fallback으로 사용할 수 있도록 설계합니다.
- **선택안**: 프런트엔드(지도)에서 `naver.maps.Service.reverseGeocode`를 호출해 주소를 resolve한 뒤 API에 `resolved_address`를 함께 전송합니다. 실패 시 기존 포맷으로 폴백, 추후 서버에서 필요 시 Kakao API로 이중 확인 가능.
- **작업**:
  1. 지도 long-press 처리기에 역지오코딩 로직 추가 (성공 시 주소 상태 저장).
  2. `POST /smoking-areas/pending` 요청 body에 `address` 필드를 추가하고, 서버는 전달된 주소를 우선 저장하되 미제공 시 기존 포맷으로 대체.
  3. (선택) 백엔드에서 Kakao API를 호출해 주소를 검증/갱신하는 fallback 함수를 준비.
- **검증**: 시민제보 제출 후 `/smoking-areas` 응답에서 `address`가 실제 지번/도로명으로 기록되는지 확인.

### 3. 허위 신고 다건 리스트 (관리자용)
- **현황**: `reportFalseArea`가 `report_count`를 증가시키지만, 관리자 UI에 해당 목록이나 정렬 옵션이 없습니다.
- **변경안**:
  - API: `/api/v1/smoking-areas/reported`(가칭) 관리자 전용 GET 엔드포인트 신설. `report_count > 0` 인 항목을 `report_count DESC, updated_at DESC`로 반환.
  - Flutter: `AdminScreen`에 신규 탭/섹션을 추가해 신고 많은 순으로 리스트(배지, 미리보기 지도 이동 버튼 등) 표시.
- **검증**: 허위 신고 버튼 여러 번 클릭 후 관리자 화면에서 상단에 노출되는지 확인.

### 4. InfoWindow에 허위 신고 수 노출
- **현황**: InfoWindow 버튼은 "허위 장소 신고하기"만 노출되고, 신고 횟수는 UI에 나오지 않습니다.
- **변경안**: `_buildInfoWindowContent`에서 `report_count`를 포함해 "허위 신고 N회" 텍스트를 버튼 옆/아래에 표시. 신고 수가 0이면 숨김.
- **작업**:
  1. Dart 쪽에서 `report_count`를 InfoWindow payload에 포함.
  2. `web/flutter_marker_renderer.js`에서 전달받은 HTML을 그대로 사용하도록 업데이트.
- **검증**: 신고 수가 있는 마커를 클릭했을 때 InfoWindow에 숫자가 보이는지 확인.

### 5. 시민제보 핀 색상 분리 + 범례 업데이트
- **현황**: 시민제보 전용 마커 SVG가 하나뿐이며, `submitted_category`(공식/비공식)가 시각적으로 구분되지 않습니다. 범례에도 해당 정보가 없음.
- **컬러 팔레트**: 공공데이터가 파란색, 기존 시민제보가 노란색과 겹치지 않도록 `공식 시민제보`는 진한 초록(예: `#16A34A`), `비공식`은 기존 노랑(`'#FACC15'`)을 유지합니다. 범례에도 두 색상을 명시합니다.
  - `flutter_marker_renderer.js`에 SVG 2종을 주입하거나 CSS 클래스 기반으로 색상 분기.
  - `MapScreen._buildLegendChips`에 두 종류의 시민제보 범례 추가.
- **검증**: 제보 시 선택한 유형별로 다른 색상이 지도/범례에 일관되게 반영되는지 확인.

### 6. 영어 모드
- **범위**: 전체 Flutter UI(지도 안내, 시민제보 다이얼로그, 관리자 화면, API 테스트 탭 등)와 InfoWindow/Toast 문구. 백엔드 응답 메시지는 우선순위 밖.
- **아키텍처 제안**:
  1. Flutter의 `MaterialApp`에 `locale`, `supportedLocales`, `localizationsDelegates`를 설정. `flutter_localizations` + `intl` 패키지 사용.
  2. `l10n/` 디렉터리에 `arb` 파일(`app_ko.arb`, `app_en.arb`)을 추가하고 `flutter gen-l10n`으로 `AppLocalizations` 생성.
  3. 앱 내 문자열을 전부 `AppLocalizations.of(context)` 참조로 치환.
  4. 메인 화면에 언어 토글 UX(예: AppBar IconButton 혹은 설정 드로워) 추가하고, 선택값을 `SharedPreferences` 또는 `localStorage`에 저장해 다음 진입 시 유지.
  5. InfoWindow/JS 문자열(허위 신고 버튼 등)은 JS 템플릿을 두 언어로 제공하거나 Dart에서 전달될 텍스트를 인자로 넘기도록 구조 변경 필요.
- **검증 전략**: QA 동안 언어 토글 → 모든 화면 전환마다 문자열 반영 여부 확인, 영어 모드에서 시민제보/관리자 흐름 정상 동작 확인.
- **리스크**: 문자열 분리 작업량이 큼, InfoWindow(순수 HTML 문자열) 번역 동기화 필요, JS-Dart간 다국어 전달 로직 추가. 네이버 지도 JS에서 자체 언어 모드를 설정하려면 공식 튜토리얼(Map Language)을 따라야 하므로, `map.setOptions({ language: 'en' })`(예시) 등 문서 기반 설정을 적용할 계획입니다. 현재 네트워크 제한으로 문서를 직접 확인할 수 없어, 실제 구현 시 제공해주신 링크를 기반으로 옵션을 반영하겠습니다.

## Work Plan & Dependencies

### Phase 1 – UX & Data Quality (요구사항 1~5)
1. **Reverse Geocoding Helper 작성**: Naver JS `reverseGeocode` 래퍼 + fallback HTTP 호출 설계.
2. **시민제보 다이얼로그 개선**: 좌표 제거, 역지오코딩 주소 표시, POST payload 확장.
3. **API 업데이트**:
   - `POST /smoking-areas/pending`에서 `address` 파라미터 허용/검증.
   - 새 관리자용 라우트 `/smoking-areas/reported` 추가.
   - `GET /smoking-areas` / `nearby` 응답에 `submitted_category`와 `report_count`가 항상 포함되도록 재확인.
4. **Flutter 지도/관리자 UI 수정**:
   - 시민제보 마커 색상 분기, 범례 갱신.
   - InfoWindow HTML에 신고 횟수 표기.
   - 관리자 화면에 신고순 리스트.
5. **테스트**: 수동으로 시민제보 → 승인/신고 → 관리자 뷰 확인.

### Phase 2 – English Mode (요구사항 6)
1. `l10n` 셋업 및 문자열 분리 계획 수립.
2. 핵심 화면별 텍스트 치환 및 언어 토글 UX 구현.
3. JS 인터롭/InfoWindow 텍스트를 다국어화하기 위한 데이터 포맷 정리.
4. QA: 언어 전환 시 지도/다이얼로그/관리자/API 테스트 화면이 모두 번역되는지 확인.

## Open Questions / Approvals Needed
- 역지오코딩: Naver JS API 활용 (브라우저 내) 방식 사용해도 되는지? Kakao REST API를 서버에서 호출하는 백업 플로우가 필요하면 알려주세요.
- 시민제보 핀 색상 팔레트: 공식/비공식 각각 원하는 컬러 값 공유 요청.
- 신고순 리스트 UI: 관리자 화면의 어떤 탭/레이아웃에 배치할지 추가 지침이 필요하면 알려주세요.
- 영어 모드: 한국어/영어 2개 언어만 우선 대상이면 충분한지, 혹은 향후 추가 가능성을 고려해야 하는지.

---
위 계획이 승인되면 Phase 1 작업부터 순차적으로 착수하겠습니다.
