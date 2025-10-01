package sdui

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

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
		http.Error(w, "missing screenId", http.StatusBadRequest)
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
		log.Printf("get screen failed (corr=%s, screen=%s, user=%s): %v", middleware.FromContext(r.Context()), screenID, req.UserID, err)
		http.Error(w, "failed to resolve screen", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(screen); err != nil {
		log.Printf("encode screen failed (corr=%s): %v", middleware.FromContext(r.Context()), err)
	}
}
