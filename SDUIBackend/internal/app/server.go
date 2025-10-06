package app

import (
    "net/http"
    "os"
    "path/filepath"

    "github.com/go-chi/chi/v5"
    chimw "github.com/go-chi/chi/v5/middleware"

    "log/slog"

    "github.com/your-org/pestgenie-sdui/internal/config"
    domrepo "github.com/your-org/pestgenie-sdui/internal/domain/repository"
    "github.com/your-org/pestgenie-sdui/internal/http/respond"
    "github.com/your-org/pestgenie-sdui/internal/middleware"
    "github.com/your-org/pestgenie-sdui/internal/sdui"
    "github.com/your-org/pestgenie-sdui/internal/swaggerui"
    syncapi "github.com/your-org/pestgenie-sdui/internal/sync"
)

// Server wraps the HTTP router so main can expose it cleanly.
type Server struct {
    Router chi.Router
    cfg    config.Config
    repos  domrepo.Repository
    logger *slog.Logger
}

// NewServer wires routing, middleware, and feature handlers.
func NewServer(cfg config.Config, repos domrepo.Repository, logger *slog.Logger) *Server {
    if err := repos.Validate(); err != nil {
        panic(err)
    }

    router := chi.NewRouter()

    router.Use(chimw.RequestID)
    router.Use(chimw.RealIP)
    router.Use(chimw.Logger)
    router.Use(chimw.Recoverer)
    router.Use(chimw.Timeout(cfg.Server.ReadTimeout))
    router.Use(middleware.Correlation())
    router.Use(middleware.WithLogger(logger))
    router.Use(middleware.RequestLogger(logger))

    staticDir := os.Getenv("SCREEN_TEMPLATE_DIR")
    if staticDir == "" {
        staticDir = filepath.Join("static", "screens")
    }

    sduiService := sdui.NewService(staticDir, repos, logger)
    sduiHandler := sdui.NewHandler(sduiService)
    syncHandler := syncapi.NewHandler(repos, cfg.Sync, logger)

    router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte(`{"status":"ok"}`))
    })

    router.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
        if err := repos.Validate(); err != nil {
            respond.Error(w, http.StatusServiceUnavailable, "service not ready", err.Error())
            return
        }
        respond.JSON(w, http.StatusOK, map[string]string{"status": "ready"})
    })

    if cfg.Server.EnableSwagger {
        router.Get("/swagger", swaggerui.UIHandler)
        router.Get("/swagger/doc.json", swaggerui.SpecHandler)
    }

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

    return &Server{Router: router, cfg: cfg, repos: repos, logger: logger}
}
