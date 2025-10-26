# Cloud Run Static Web Deployment

This folder contains the assets needed to containerise the Flutter web build
for hosting on Cloud Run.

## Build steps

1. Build the container image (run from the repository 루트. Dockerfile은
   `app/Dockerfile.web`에 있으므로 컨텍스트는 `app/` 디렉터리로 지정합니다.):
   ```bash
   gcloud builds submit app \
     --tag gcr.io/project-371e286b-0a83-429a-930/wheresmoking-web \
     --file Dockerfile.web \
     --build-arg NAVER_MAP_KEY="$NAVER_MAP_KEY" \
     --build-arg ADMIN_ACCESS_TOKEN="$ADMIN_ACCESS_TOKEN" \
     --build-arg API_BASE_URL="$API_BASE_URL"
   ```

   The Dockerfile runs `flutter build web --release` inside the build stage so
   no local build artefacts are required beforehand.

   > **Tip:** When using Cloud Build triggers or GitHub Actions, source these
   > build args from Secret Manager / repository secrets instead of committing
   > them to the repo.

2. Deploy to Cloud Run (서비스 이름이 `where-smoking-w`인 경우):
   ```bash
   gcloud run deploy where-smoking-w \
      --image gcr.io/project-371e286b-0a83-429a-930/wheresmoking-web \
      --region asia-northeast1 \
      --allow-unauthenticated
   ```

3. (Optional) Map `wheresmoking.kr` or a subdomain to the service via the
   Cloud Run console.

The service listens on port 8080 and routes all unknown paths to `index.html`
so that Flutter's client-side routing continues to function.
