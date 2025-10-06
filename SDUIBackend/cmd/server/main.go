package main

import (
	"context"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/your-org/pestgenie-sdui/internal/app"
	"github.com/your-org/pestgenie-sdui/internal/config"
	"github.com/your-org/pestgenie-sdui/internal/domain/repository"
	"github.com/your-org/pestgenie-sdui/internal/secret"
	storememory "github.com/your-org/pestgenie-sdui/internal/store/memory"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: parseLogLevel(cfg.Telemetry.LogLevel)}))

	var provider secret.Provider
	switch cfg.Secrets.Provider {
	case "gcp":
		p, err := secret.NewGCPSecretManager(cfg.Secrets.ProjectID)
		if err != nil {
			log.Printf("warning: gcp secret manager unavailable, falling back to env provider: %v", err)
			provider = secret.EnvProvider{}
		} else {
			provider = p
		}
	default:
		provider = secret.EnvProvider{}
	}

	if cfg.Secrets.CacheTTL > 0 {
		provider = secret.NewCachedProvider(provider, cfg.Secrets.CacheTTL)
	}

	_ = provider // TODO: inject into services when secret-backed dependencies are added

	// Repositories (in-memory for now)
	store := storememory.NewStore()
	repos := repository.Repository{
		Technicians: store,
		Routes:      store,
		Screens:     store,
		Sync:        store,
		Devices:     store,
	}

	srv := app.NewServer(cfg, repos, logger)

	server := &http.Server{
		Addr:              ":" + cfg.Server.Port,
		Handler:           srv.Router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       cfg.Server.ReadTimeout,
		WriteTimeout:      cfg.Server.WriteTimeout,
		IdleTimeout:       cfg.Server.IdleTimeout,
	}

	go func() {
		logger.Info("server started", slog.String("addr", server.Addr), slog.String("env", string(cfg.Environment)))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server error", slog.Any("error", err))
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	logger.Info("shutting down")
	if err := server.Shutdown(ctx); err != nil {
		logger.Error("graceful shutdown failed", slog.Any("error", err))
	}
}

func parseLogLevel(level string) slog.Level {
	switch level {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
