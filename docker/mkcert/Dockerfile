FROM golang:alpine AS builder

RUN apk add --no-cache git bash nss-tools && \
    go install filippo.io/mkcert@latest

FROM alpine:latest

RUN apk add --no-cache bash nss-tools ca-certificates
COPY --from=builder /go/bin/mkcert /usr/local/bin/mkcert

ENTRYPOINT ["sh", "-c", "\
  if [ ! -f /certs/${DOMAIN}.pem ]; then \
    mkcert -install 2>/dev/null || true; \
    mkcert -cert-file /certs/${DOMAIN}.pem -key-file /certs/${DOMAIN}-key.pem ${DOMAIN} localhost 127.0.0.1 ::1; \
    echo 'Certificates generated for ${DOMAIN}'; \
  else \
    echo 'Certificates already exist for ${DOMAIN}'; \
  fi"]
