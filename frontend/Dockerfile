# syntax=docker/dockerfile:1.7

FROM ghcr.io/cirruslabs/flutter:3.35.2 AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG API_BASE_URL=
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
USER 0
RUN chgrp -R 0 /etc/nginx /usr/share/nginx/html /var/cache/nginx \
 && chmod -R g+rwX /etc/nginx /usr/share/nginx/html /var/cache/nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
USER 101
EXPOSE 8080
