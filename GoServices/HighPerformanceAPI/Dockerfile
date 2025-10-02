# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install git for fetching dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod tidy && go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Runtime stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/main .

# Create non-root user and set permissions
RUN addgroup -g 1001 -S appuser && \
    adduser -S -D -H -u 1001 -h /root -s /sbin/nologin -G appuser -g appuser appuser && \
    chown appuser:appuser /root/main && \
    chmod +x /root/main

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Environment variables
ENV GIN_MODE=release
ENV GO_API_PORT=8080

# Expose port
EXPOSE 8080

CMD ["./main"]