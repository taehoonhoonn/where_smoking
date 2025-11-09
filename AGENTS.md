# Repository Guidelines

## Project Structure & Module Organization
- `api_server/`: Node.js + Express REST API, including `server.js`, route/controllers, and PostgreSQL config under `config/`. Tests live in `api_server/tests/`.
- `app/`: Flutter web client. `lib/` holds feature screens (`map_screen.dart`, `admin_screen.dart`), shared services, and models; `web/` contains the bootstrap HTML with the Naver Maps script.
- `scripts/`: Data ingestion, validation, and database utilities (Python). Use these when regenerating source datasets or reseeding PostgreSQL. Refer to `scripts/.env.example` for required API keys.
- `old/`: Archived experiments. Do not rely on this for active development unless explicitly resurrecting legacy work.
- Root-level `AGENTS.md` (this file) and `app/AGENTS.md` capture contributor guardrails—update both when workflows change.

## Data Ingestion Workflow
- 기본 재적재는 `python3 scripts/reseed_from_raw.py` (replace 모드, 테이블을 `TRUNCATE` 후 전량 삽입)로 수행합니다.
- 공공데이터 추가분만 누적하려면 `python3 scripts/reseed_from_raw.py --mode append --csv <새 CSV 경로>`를 사용합니다. `append`는 주소+상세(소문자, 공백 트림) 조합이 이미 존재하면 건너뜁니다.
- 새 CSV는 `scripts/.env`에 설정된 Kakao API 키를 기반으로 지오코딩하며, 실패 건은 `failed_geocoding_*.json`으로 남습니다.

## Build, Test, and Development Commands
- `cd api_server && npm install`: Install API dependencies.
- `cd api_server && npm start`: Launch the REST API on `http://localhost:3000` (requires PostgreSQL running at `localhost:5432`). Export vars via `.env` created from `.env.example` first.
- `cd api_server && npm test`: Run Jest tests for controllers, middleware, and routes.
- `cd app && flutter pub get`: Sync Flutter dependencies.
- `cp app/web/config.sample.js app/web/config.js`: Create a local map-key config (then assign `window.NAVER_MAP_KEY`).
- `cd app && flutter run -d web-server --web-port=8080`: Serve the web client locally; ensure the API is running first.
- `cd app && flutter run --dart-define=USE_LOCAL_WEB_APP=true --dart-define=LOCAL_WEB_APP_URL=http://localhost:8080 -d android`:
  Launch the mobile WebView shell against your local Flutter web server.
  `mobile_config.dart` rewrites `localhost` to `10.0.2.2` (Android) or `127.0.0.1` (iOS) so emulators reach the host machine.

## Coding Style & Naming Conventions
- **Backend (Node.js)**: Use `eslint` default/airbnb-style conventions—2-space indentation, camelCase for variables/functions, PascalCase for classes. Place Express middleware in `middleware/` and controllers in `controllers/`.
- **Frontend (Flutter)**: Follow Dart style (2-space indent, `UpperCamelCase` for classes, `lowerCamelCase` for members). Keep UI logic inside widgets and isolate HTTP calls in services.
- **Scripts**: Prefer snake_case for Python modules and functions. Keep docstrings short and explain side effects.

## Testing Guidelines
- API layer uses Jest + Supertest. Name test files `<module>.spec.js` and place them beside the module under test.
- Flutter tests should live under `app/test/` with `*_test.dart` naming. Use `flutter test` before submitting UI changes.
- Failing tests must be addressed before opening a PR; aim to maintain existing coverage levels (per Jest and Flutter reports).

## Commit & Pull Request Guidelines
- Commit messages follow a concise `type(scope): summary` pattern, e.g., `feat(map): add marker debounce`. Group related changes together and avoid large, unrelated commits.
- Pull requests should include: change summary, testing evidence (`npm test`, `flutter test`, manual steps), screenshots/GIFs for UI updates, and references to issue IDs when available.
- Keep branches up to date with `main` and resolve conflicts locally before requesting review.

## Security & Configuration Tips
- Store environment variables in `.env` files (see `api_server/.env.example`). Never commit credentials.
- PostgreSQL must be reachable at `localhost:5432`; update `.env` overrides when using alternative hosts.
- Never commit `app/web/config.js` or `api_server/.env`; both are ignored and should stay local.
- When touching JS interop for the map, guard new globals to avoid clobbering existing window-level callbacks.
- Admin-only API actions (approve/reject/delete) require matching `ADMIN_ACCESS_TOKEN` in the server `.env` and `window.ADMIN_ACCESS_TOKEN` in `app/web/config.js`; without both, admin controls remain hidden.

## 시민 제보 워크플로우
- 지도 롱프레스 감지는 네이버 지도 `longtap` 이벤트(모바일)와 `mousedown` 타이머(데스크톱) 모두를 유지해 플랫폼별 제보 입력을 보장합니다.
- 시민 제보 다이얼로그에서는 등록 유형을 반드시 선택하도록 하고, 옵션은 `공식 흡연장소`·`비공식 흡연장소` 두 가지입니다. 선택 결과는 API의 `submitted_category`로 전달됩니다.

naver map 기능 수정을 위한 참고 자료는 https://github.com/navermaps/maps.js.ncp 를 참조한다
