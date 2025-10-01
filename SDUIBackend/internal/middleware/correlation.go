package middleware

import (
	"context"
	"github.com/google/uuid"
	"net/http"
)

// correlationIDKey is private to avoid collisions.
type correlationIDKey struct{}

// Correlation injects a correlation ID into the request context so downstream
// logs can tie together API calls from the mobile client.
func Correlation() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id := r.Header.Get("X-Correlation-ID")
			if id == "" {
				id = uuid.NewString()
			}
			ctx := context.WithValue(r.Context(), correlationIDKey{}, id)
			w.Header().Set("X-Correlation-ID", id)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// FromContext returns the correlation ID if one was set.
func FromContext(ctx context.Context) string {
	if val, ok := ctx.Value(correlationIDKey{}).(string); ok {
		return val
	}
	return ""
}
