# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install dependencies for image processing
RUN apk add --no-cache git gcc musl-dev

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o skins-capes-service .

# Final stage
FROM alpine:latest

WORKDIR /app

# Install ca-certificates for HTTPS requests and image processing libs
RUN apk --no-cache add ca-certificates tzdata curl wget

# Create non-root user
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser

# Create storage directories
RUN mkdir -p /app/storage/skins /app/storage/capes /app/storage/avatars && \
    chown -R appuser:appgroup /app

# Copy binary from builder stage
COPY --from=builder /app/skins-capes-service .

# Set ownership and permissions
RUN chown appuser:appgroup skins-capes-service && \
    chmod +x skins-capes-service

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# Expose port
EXPOSE 8081

# Run the application
CMD ["./skins-capes-service"]