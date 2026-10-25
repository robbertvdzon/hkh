# syntax=docker/dockerfile:1.7

FROM ghcr.io/cirruslabs/flutter:3.35.2 AS build
RUN FLUTTER_SDK="$(dirname "$(dirname "$(command -v flutter)")")" \
 && git -C "$FLUTTER_SDK" fetch --depth 1 origin tag 3.44.7 \
 && git -C "$FLUTTER_SDK" checkout --force 3.44.7 \
 && flutter precache --web
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --pwa-strategy=none --dart-define=RUNTIME_CONFIG=true

# Flutter gebruikt standaard een vaste main.dart.js-naam. Geef iedere inhoud een eigen URL,
# zodat browsers en Cloudflare nooit een oude app-bundle onder dezelfde naam kunnen serveren.
RUN bash tool/hash-web-bundle.sh

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
USER 0
RUN chgrp -R 0 /etc/nginx /usr/share/nginx/html /var/cache/nginx \
 && chmod -R g+rwX /etc/nginx /usr/share/nginx/html /var/cache/nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
USER 101
EXPOSE 8080
