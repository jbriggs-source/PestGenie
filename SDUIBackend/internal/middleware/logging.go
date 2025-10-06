package middleware

import (
	"context"
	"net/http"
	"time"

	"log/slog"
)

// loggerKey is the context key for the request logger.
type loggerKey struct{}

// WithLogger injects the shared logger into the request context.
func WithLogger(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), loggerKey{}, logger)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequestLogger writes structured logs for each request/response pair.
func RequestLogger(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(rw, r)

			log := logger
			if log == nil {
				log = slog.Default()
			}
			log.Info("request",
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.Int("status", rw.status),
				slog.String("remote", r.RemoteAddr),
				slog.Duration("duration", time.Since(start)),
			)
		})
	}
}

// LoggerFrom extracts the logger from context.
func LoggerFrom(ctx context.Context) *slog.Logger {
	if logger, ok := ctx.Value(loggerKey{}).(*slog.Logger); ok {
		return logger
	}
	return slog.Default()
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(status int) {
	rw.status = status
	rw.ResponseWriter.WriteHeader(status)
}
