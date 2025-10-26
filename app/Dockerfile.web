FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /workspace/app

ARG NAVER_MAP_KEY=""
ARG ADMIN_ACCESS_TOKEN=""
ARG API_BASE_URL=""

ENV NAVER_MAP_KEY=${NAVER_MAP_KEY}
ENV ADMIN_ACCESS_TOKEN=${ADMIN_ACCESS_TOKEN}
ENV API_BASE_URL=${API_BASE_URL}

# Cache dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source
COPY . ./

# Generate runtime configuration using build-time secrets or defaults.
RUN set -eu; \
    API_BASE_URL_DEFAULT="${API_BASE_URL:-https://api.wheresmoking.kr/api/v1}"; \
    NAVER_MAP_KEY_DEFAULT="${NAVER_MAP_KEY:-jdlowyicuj}"; \
    printf 'window.NAVER_MAP_KEY = "%s";\n' "${NAVER_MAP_KEY_DEFAULT}" > web/config.js; \
    printf 'window.ADMIN_ACCESS_TOKEN = "%s";\n' "${ADMIN_ACCESS_TOKEN}" >> web/config.js; \
    printf 'window.API_BASE_URL = "%s";\n' "${API_BASE_URL_DEFAULT}" >> web/config.js

# Build Flutter web bundle
RUN flutter build web --release

FROM nginx:1.27-alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /workspace/app/build/web /usr/share/nginx/html
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
