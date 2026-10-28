# ---------- Build ----------
FROM rust:1.89-alpine AS builder

RUN apk add --no-cache musl-dev

WORKDIR /app
ENV CARGO_PROFILE_RELEASE_STRIP=symbols

# Compila só as dependências primeiro (os modelos do lingua demoram bastante),
# assim mudanças no src/ não invalidam esse cache.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release --locked \
    && rm -rf src

COPY src ./src
# touch força o cargo a recompilar o main.rs real em vez de reaproveitar o dummy
RUN touch src/main.rs && cargo build --release --locked

# ---------- Runtime ----------
FROM alpine:3.22

RUN apk add --no-cache nginx tini su-exec \
    && addgroup -S app && adduser -S -G app app \
    && mkdir -p /run/nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=builder /app/target/release/lang-detector /usr/local/bin/lang-detector
COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/entrypoint.sh /entrypoint.sh

EXPOSE 80

# A primeira detecção carrega os modelos de todos os idiomas, por isso o timeout folgado
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget -q -O /dev/null --header 'Content-Type: application/json' \
        --post-data '{"text":"hello world"}' http://127.0.0.1/api/v1/detect || exit 1

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
