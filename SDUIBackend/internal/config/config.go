package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Environment represents the deployment environment.
type Environment string

const (
	EnvLocal Environment = "local"
	EnvDev   Environment = "dev"
	EnvProd  Environment = "prod"
)

// Config is the immutable application configuration root.
type Config struct {
	Environment Environment
	Server      ServerConfig
	Telemetry   TelemetryConfig
	Secrets     SecretsConfig
	Datastore   DatastoreConfig
	Sync        SyncConfig
}

// ServerConfig controls HTTP behaviour.
type ServerConfig struct {
	Port           string
	ReadTimeout    time.Duration
	WriteTimeout   time.Duration
	IdleTimeout    time.Duration
	AllowedOrigins []string
	EnableSwagger  bool
}

// TelemetryConfig controls structured logging and tracing.
type TelemetryConfig struct {
	ServiceName   string
	LogLevel      string
	OTLPEndpoint  string
	EnableTracing bool
}

// SecretsConfig defines secret manager behaviour.
type SecretsConfig struct {
	Provider  string // env, gcp
	ProjectID string
	CacheTTL  time.Duration
}

// DatastoreConfig defines persistence options (Firestore by default).
type DatastoreConfig struct {
	Driver            string // memory, firestore
	FirestoreProject  string
	FirestoreEmulator string
}

// SyncConfig captures retry/backoff settings for sync processing.
type SyncConfig struct {
	MaxRetries int
	Backoff    time.Duration
}

// Load reads configuration from environment variables with sane defaults.
func Load() (Config, error) {
	env := Environment(getEnv("SDUI_ENV", string(EnvLocal)))
	if env != EnvLocal && env != EnvDev && env != EnvProd {
		return Config{}, fmt.Errorf("unsupported environment: %s", env)
	}

	server := ServerConfig{
		Port:           getEnv("PORT", "8080"),
		ReadTimeout:    getDuration("SERVER_READ_TIMEOUT", 10*time.Second),
		WriteTimeout:   getDuration("SERVER_WRITE_TIMEOUT", 15*time.Second),
		IdleTimeout:    getDuration("SERVER_IDLE_TIMEOUT", 60*time.Second),
		AllowedOrigins: splitAndTrim(getEnv("SERVER_ALLOWED_ORIGINS", "")),
		EnableSwagger:  getBool("SERVER_ENABLE_SWAGGER", env == EnvLocal),
	}

	telemetry := TelemetryConfig{
		ServiceName:   getEnv("TELEMETRY_SERVICE_NAME", "pestgenie-sdui"),
		LogLevel:      strings.ToLower(getEnv("TELEMETRY_LOG_LEVEL", "info")),
		OTLPEndpoint:  getEnv("TELEMETRY_OTLP_ENDPOINT", ""),
		EnableTracing: getBool("TELEMETRY_ENABLE_TRACING", env != EnvLocal),
	}

	secrets := SecretsConfig{
		Provider:  strings.ToLower(getEnv("SECRETS_PROVIDER", "env")),
		ProjectID: getEnv("SECRETS_PROJECT_ID", getEnv("GOOGLE_CLOUD_PROJECT", "")),
		CacheTTL:  getDuration("SECRETS_CACHE_TTL", 5*time.Minute),
	}

	datastore := DatastoreConfig{
		Driver:            strings.ToLower(getEnv("DATASTORE_DRIVER", "memory")),
		FirestoreProject:  getEnv("DATASTORE_FIRESTORE_PROJECT", secrets.ProjectID),
		FirestoreEmulator: getEnv("FIRESTORE_EMULATOR_HOST", ""),
	}

	syncCfg := SyncConfig{
		MaxRetries: getInt("SYNC_MAX_RETRIES", 5),
		Backoff:    getDuration("SYNC_BACKOFF", time.Second*2),
	}

	cfg := Config{
		Environment: env,
		Server:      server,
		Telemetry:   telemetry,
		Secrets:     secrets,
		Datastore:   datastore,
		Sync:        syncCfg,
	}

	return cfg, cfg.validate()
}

func (c Config) validate() error {
	if c.Secrets.Provider != "env" && c.Secrets.Provider != "gcp" {
		return fmt.Errorf("invalid secrets provider: %s", c.Secrets.Provider)
	}
	if c.Datastore.Driver != "memory" && c.Datastore.Driver != "firestore" {
		return fmt.Errorf("invalid datastore driver: %s", c.Datastore.Driver)
	}
	if c.Sync.MaxRetries < 0 {
		return fmt.Errorf("sync max retries must be >= 0")
	}
	if c.Sync.Backoff < 0 {
		return fmt.Errorf("sync backoff must be >= 0")
	}
	return nil
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}
	return fallback
}

func getDuration(key string, fallback time.Duration) time.Duration {
	str := getEnv(key, "")
	if str == "" {
		return fallback
	}
	value, err := time.ParseDuration(str)
	if err != nil {
		return fallback
	}
	return value
}

func getInt(key string, fallback int) int {
	str := getEnv(key, "")
	if str == "" {
		return fallback
	}
	value, err := strconv.Atoi(str)
	if err != nil {
		return fallback
	}
	return value
}

func getBool(key string, fallback bool) bool {
	str := strings.ToLower(getEnv(key, ""))
	if str == "" {
		return fallback
	}
	value, err := strconv.ParseBool(str)
	if err != nil {
		return fallback
	}
	return value
}

func splitAndTrim(value string) []string {
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		item := strings.TrimSpace(p)
		if item != "" {
			result = append(result, item)
		}
	}
	return result
}
