package secret

import (
	"errors"
	"os"
	"sync"
	"time"
)

// Provider represents a secret retrieval mechanism.
type Provider interface {
	Get(name string) (string, error)
}

// EnvProvider reads secrets from environment variables.
type EnvProvider struct{}

// Get returns the value for the provided name using environment variables.
func (e EnvProvider) Get(name string) (string, error) {
	if value, ok := os.LookupEnv(name); ok {
		return value, nil
	}
	return "", errors.New("secret not found in environment")
}

// CachedProvider wraps another provider and caches values for the specified TTL.
type CachedProvider struct {
	base Provider
	ttl  time.Duration

	mu    sync.RWMutex
	cache map[string]cachedSecret
}

type cachedSecret struct {
	value     string
	expiresAt time.Time
}

// NewCachedProvider creates a caching decorator.
func NewCachedProvider(base Provider, ttl time.Duration) *CachedProvider {
	return &CachedProvider{base: base, ttl: ttl, cache: make(map[string]cachedSecret)}
}

// Get returns a cached secret value or fetches it from the base provider.
func (c *CachedProvider) Get(name string) (string, error) {
	if c == nil {
		return "", errors.New("nil provider")
	}
	now := time.Now()

	c.mu.RLock()
	entry, ok := c.cache[name]
	c.mu.RUnlock()
	if ok && entry.expiresAt.After(now) {
		return entry.value, nil
	}

	value, err := c.base.Get(name)
	if err != nil {
		return "", err
	}

	c.mu.Lock()
	c.cache[name] = cachedSecret{value: value, expiresAt: now.Add(c.ttl)}
	c.mu.Unlock()
	return value, nil
}

// GCPSecretManager is a placeholder stub that can be expanded with the official
// cloud.google.com/go/secretmanager client once network access and dependencies
// are available. For now it returns an informative error so callers can fall
// back to environment variables during development.
type GCPSecretManager struct{}

func NewGCPSecretManager(projectID string) (*GCPSecretManager, error) {
	if projectID == "" {
		return nil, errors.New("project id required for gcp secret manager")
	}
	return &GCPSecretManager{}, nil
}

func (g *GCPSecretManager) Get(name string) (string, error) {
	return "", errors.New("gcp secret manager not integrated in this build")
}
