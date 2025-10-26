FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Pre-download dependencies to leverage Docker layer caching.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the remaining project files and build the web bundle.
COPY . .
RUN flutter build web --release

FROM nginx:1.27-alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
