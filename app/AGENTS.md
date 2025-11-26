# Flutter Web 앱 작업 지침

이 디렉터리(`app/`)의 코드 작업 시 다음 사항을 지켜주세요.

- 하단 탭 구조를 수정할 때는 `IndexedStack`을 사용해 각 탭의 위젯 상태를 유지합니다.
- 내비게이션 탭 위젯 리스트는 `const` 리스트로 선언해 재생성 비용을 줄입니다.
- 지도 관련 수정 시 탭 전환 후에도 마커가 다시 렌더링되는지 직접 확인합니다.
- 네이버 지도는 `markerclusterer` 서브모듈( `naver.maps.MarkerClustering`)을 사용합니다. 클러스터 관련 전역 핸들(`window.naverMapClusterer_<id>`)과 스타일 주입 플래그는 삭제하지 마세요.
- `HtmlElementView('naver-map')` + `web/flutter_marker_renderer.js` 브리지를 통해 마커를 그립니다. `flutterRenderSmokingMarkers`, `flutterMapViewportChanged`, `flutter_map_longpress`, `flutterDeleteSmokingArea` 등 전역 함수/플래그 이름을 임의로 바꾸지 말고, 필요 시 Dart·JS 양쪽을 동시에 수정하세요.
- 배포 전 `web/config.sample.js`를 복사해 `web/config.js`를 만들고, `window.NAVER_MAP_KEY`에 로컬/테스트 키만 입력합니다. (API 서버에서는 카카오 키를 요구하지 않으며, 데이터 파이프라인 키는 `scripts/.env`에 별도로 설정하세요.)
- 모바일 WebView 래퍼(`mobile_app.dart`)는 `mobile_config.dart`의 `WEB_APP_URL`을 디폴트로 사용하고, `USE_LOCAL_WEB_APP` + `LOCAL_WEB_APP_URL` `dart-define`을 주면 로컬 웹 서버(`http://localhost:8080`)로 전환합니다. `localhost`는 자동으로 `10.0.2.2`(Android 에뮬레이터) / `127.0.0.1`(iOS 시뮬레이터)로 치환됩니다.
- 새로운 JavaScript 브리지 함수를 추가할 경우, 기존 전역 콜백과 충돌하지 않도록 네이밍을 명확히 합니다.
- 관리자 전용 기능(마커 삭제/승인 등)을 사용하려면 `window.ADMIN_ACCESS_TOKEN`을 `web/config.js`에 설정하고, API 서버 `.env`의 `ADMIN_ACCESS_TOKEN`과 일치시키세요.
- 관리자 토큰이 감지되면 `API 테스트` 탭이 노출되어 `/api/v1` 헬스/목록/주변/통계 호출을 즉시 재검증할 수 있습니다. 엔드포인트 구조를 바꿀 경우 해당 화면의 요청 URL도 함께 갱신하세요.
- 시민 제보 다이얼로그는 등록 유형(공식/비공식 흡연장소) 선택이 필수이며 값은 API의 `submitted_category`로 전달됩니다. 라디오 옵션을 변경할 때는 서버 검증 목록(`official`/`unofficial`)과 동기화하세요.
