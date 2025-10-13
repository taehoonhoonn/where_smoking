# Flutter Web 앱 작업 지침

이 디렉터리(`app/`)의 코드 작업 시 다음 사항을 지켜주세요.

- 하단 탭 구조를 수정할 때는 `IndexedStack`을 사용해 각 탭의 위젯 상태를 유지합니다.
- 내비게이션 탭 위젯 리스트는 `const` 리스트로 선언해 재생성 비용을 줄입니다.
- 지도 관련 수정 시 탭 전환 후에도 마커가 다시 렌더링되는지 직접 확인합니다.
- 배포 전 `web/config.sample.js`를 복사해 `web/config.js`를 만들고, `window.NAVER_MAP_KEY`에 로컬/테스트 키만 입력합니다. (API 서버에서는 카카오 키를 요구하지 않으며, 데이터 파이프라인 키는 `scripts/.env`에 별도로 설정하세요.)
- 새로운 JavaScript 브리지 함수를 추가할 경우, 기존 전역 콜백과 충돌하지 않도록 네이밍을 명확히 합니다.
- 관리자 전용 기능(마커 삭제/승인 등)을 사용하려면 `window.ADMIN_ACCESS_TOKEN`을 `web/config.js`에 설정하고, API 서버 `.env`의 `ADMIN_ACCESS_TOKEN`과 일치시키세요.
