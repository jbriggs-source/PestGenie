package sdui

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"log/slog"

	"github.com/your-org/pestgenie-sdui/internal/http/respond"
	"github.com/your-org/pestgenie-sdui/internal/middleware"
	"github.com/your-org/pestgenie-sdui/internal/models"
)

// Handler exposes HTTP endpoints for SDUI screens.
type Handler struct {
	service *Service
}

// NewHandler wires a Service into a HTTP presenter.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// GetScreen resolves a personalised screen for a technician.
func (h *Handler) GetScreen(w http.ResponseWriter, r *http.Request) {
	screenID := chi.URLParam(r, "screenId")
	if screenID == "" {
		respond.Error(w, http.StatusBadRequest, "missing screenId", "screenId path parameter is required")
		return
	}

	q := r.URL.Query()

	serviceDate := time.Time{}
	if dateStr := q.Get("serviceDate"); dateStr != "" {
		if parsed, err := time.Parse(time.RFC3339, dateStr); err == nil {
			serviceDate = parsed
		}
	}

	req := models.ScreenRequest{
		ScreenID:    screenID,
		UserID:      q.Get("userId"),
		RouteID:     q.Get("routeId"),
		ServiceDate: serviceDate,
		DeviceModel: q.Get("deviceModel"),
		AppVersion:  q.Get("appVersion"),
		Locale:      q.Get("locale"),
	}

	screen, err := h.service.GetScreen(r.Context(), req)
	if err != nil {
		logger := middleware.LoggerFrom(r.Context())
		logger.Error("failed to resolve screen", slog.String("screen", screenID), slog.String("user", req.UserID), slog.Any("error", err))
		respond.Error(w, http.StatusInternalServerError, "failed to resolve screen", "temporary error, please retry")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(screen); err != nil {
		logger := middleware.LoggerFrom(r.Context())
		logger.Error("failed to encode screen", slog.Any("error", err))
	}
}
