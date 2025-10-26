# Cloud Run Static Web Deployment

This folder contains the assets needed to containerise the Flutter web build
for hosting on Cloud Run.

## Build steps

1. Build the container image (run from the repository root so the `app/`
   directory is available to the Docker build context):
   ```bash
   gcloud builds submit \
     --tag gcr.io/project-371e286b-0a83-429a-930/wheresmoking-web \
     --file app/deploy/web/Dockerfile \
     .
   ```

   The Dockerfile runs `flutter build web --release` inside the build stage so
   no local build artefacts are required beforehand.

2. Deploy to Cloud Run:
   ```bash
   gcloud run deploy wheresmoking-web \
     --image gcr.io/project-371e286b-0a83-429a-930/wheresmoking-web \
     --region asia-northeast3 \
     --allow-unauthenticated
   ```

3. (Optional) Map `wheresmoking.kr` or a subdomain to the service via the
   Cloud Run console.

The service listens on port 8080 and routes all unknown paths to `index.html`
so that Flutter's client-side routing continues to function.
