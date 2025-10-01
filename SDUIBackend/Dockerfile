# syntax=docker/dockerfile:1.6

# Stage 1: build the Go binary
FROM golang:1.22 AS builder

WORKDIR /src

# Cache modules separately
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy source and build
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build -o /app/pestgenie-sdui ./cmd/server

# Stage 2: minimal runtime image
FROM gcr.io/distroless/base-debian12

# Copy binary
COPY --from=builder /app/pestgenie-sdui /app/pestgenie-sdui

# Cloud Run listens on $PORT; default to 8080 for local use
ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["/app/pestgenie-sdui"]
