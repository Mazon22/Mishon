FROM golang:1.26-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/mishon-go-api ./cmd/mishon-go-api

FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -S app && \
    adduser -S -D -H -G app -u 10001 app && \
    mkdir -p /var/lib/mishon && \
    chown -R app:app /var/lib/mishon

WORKDIR /app

COPY --from=build /out/mishon-go-api /usr/local/bin/mishon-go-api

USER app

EXPOSE 8081

ENTRYPOINT ["/usr/local/bin/mishon-go-api"]
