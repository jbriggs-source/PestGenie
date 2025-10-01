package app

import (
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"

	"github.com/your-org/pestgenie-sdui/internal/middleware"
	"github.com/your-org/pestgenie-sdui/internal/sdui"
	syncapi "github.com/your-org/pestgenie-sdui/internal/sync"
)

// Server wraps the HTTP router so main can expose it cleanly.
type Server struct {
	Router chi.Router
}

// NewServer wires routing, middleware, and feature handlers.
func NewServer() *Server {
	router := chi.NewRouter()

	router.Use(chimw.RequestID)
	router.Use(chimw.RealIP)
	router.Use(chimw.Logger)
	router.Use(chimw.Recoverer)
	router.Use(chimw.Timeout(30 * time.Second))
	router.Use(middleware.Correlation())

	staticDir := os.Getenv("SCREEN_TEMPLATE_DIR")
	if staticDir == "" {
		staticDir = filepath.Join("static", "screens")
	}

	sduiService := sdui.NewService(staticDir)
	sduiHandler := sdui.NewHandler(sduiService)
	syncHandler := syncapi.NewHandler()

	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	router.Route("/v1", func(r chi.Router) {
		r.Route("/screens", func(sr chi.Router) {
			sr.Get("/{screenId}", sduiHandler.GetScreen)
		})

		r.Route("/jobs", func(jr chi.Router) {
			jr.Post("/", syncHandler.CreateJob)
		})
		r.Route("/chemicals", func(cr chi.Router) {
			cr.Post("/", syncHandler.CreateChemical)
		})
		r.Route("/chemical-treatments", func(tr chi.Router) {
			tr.Post("/", syncHandler.CreateChemicalTreatment)
		})
		r.Route("/devices", func(dr chi.Router) {
			dr.Post("/register", syncHandler.RegisterDevice)
		})
		r.Get("/updates", syncHandler.GetUpdates)
	})

	return &Server{Router: router}
}
