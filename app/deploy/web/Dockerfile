FROM nginx:1.27-alpine

# Remove default assets shipped with the base image.
RUN rm -rf /usr/share/nginx/html/*

# Copy Flutter web build output into the image.
COPY build/web /usr/share/nginx/html

# Replace the default site configuration to support SPA routing.
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
