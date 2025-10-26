FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /workspace/app

# Pre-download dependencies to leverage Docker layer caching.
COPY app/pubspec.yaml ./pubspec.yaml
COPY app/pubspec.lock ./pubspec.lock
RUN flutter pub get

# Copy the full Flutter project and build the web bundle.
COPY app/ ./

# Ensure a config.js is present even if only the sample file exists.
RUN if [ ! -f web/config.js ] && [ -f web/config.sample.js ]; then \
      cp web/config.sample.js web/config.js; \
    fi

RUN flutter build web --release

FROM nginx:1.27-alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /workspace/app/build/web /usr/share/nginx/html
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
