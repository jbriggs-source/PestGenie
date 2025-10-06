package config

import (
	"os"
	"testing"
	"time"
)

func TestLoadDefaults(t *testing.T) {
	os.Clearenv()
	cfg, err := Load()
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if cfg.Server.Port != "8080" {
		t.Errorf("expected default port 8080, got %s", cfg.Server.Port)
	}
	if cfg.Secrets.Provider != "env" {
		t.Errorf("expected env secrets provider, got %s", cfg.Secrets.Provider)
	}
	if cfg.Datastore.Driver != "memory" {
		t.Errorf("expected memory datastore, got %s", cfg.Datastore.Driver)
	}
	if !cfg.Server.EnableSwagger {
		t.Errorf("expected swagger enabled in local env")
	}
}

func TestLoadOverrides(t *testing.T) {
	t.Cleanup(func() { os.Clearenv() })

	os.Setenv("SDUI_ENV", "prod")
	os.Setenv("PORT", "9090")
	os.Setenv("SERVER_ALLOWED_ORIGINS", "https://app.example.com, https://admin.example.com")
	os.Setenv("SECRETS_PROVIDER", "gcp")
	os.Setenv("DATASTORE_DRIVER", "firestore")
	os.Setenv("SYNC_MAX_RETRIES", "10")
	os.Setenv("SYNC_BACKOFF", "3s")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if cfg.Environment != EnvProd {
		t.Errorf("expected EnvProd, got %s", cfg.Environment)
	}
	if cfg.Server.Port != "9090" {
		t.Errorf("expected port 9090, got %s", cfg.Server.Port)
	}
	if len(cfg.Server.AllowedOrigins) != 2 {
		t.Fatalf("expected 2 allowed origins, got %d", len(cfg.Server.AllowedOrigins))
	}
	if cfg.Secrets.Provider != "gcp" {
		t.Errorf("expected secrets provider gcp, got %s", cfg.Secrets.Provider)
	}
	if cfg.Datastore.Driver != "firestore" {
		t.Errorf("expected firestore driver, got %s", cfg.Datastore.Driver)
	}
	if cfg.Sync.MaxRetries != 10 {
		t.Errorf("expected max retries 10, got %d", cfg.Sync.MaxRetries)
	}
	if cfg.Sync.Backoff != 3*time.Second {
		t.Errorf("expected backoff 3s, got %s", cfg.Sync.Backoff)
	}
	if cfg.Server.EnableSwagger {
		t.Errorf("expected swagger disabled in prod")
	}
}

func TestInvalidProvider(t *testing.T) {
	t.Cleanup(func() { os.Clearenv() })

	os.Setenv("SECRETS_PROVIDER", "invalid")
	if _, err := Load(); err == nil {
		t.Fatalf("expected error for invalid secrets provider")
	}
}
