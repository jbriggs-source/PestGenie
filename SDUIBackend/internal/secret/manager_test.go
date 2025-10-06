package secret

import (
	"os"
	"testing"
	"time"
)

func TestEnvProvider(t *testing.T) {
	os.Setenv("TEST_SECRET", "value")
	t.Cleanup(func() { os.Unsetenv("TEST_SECRET") })

	p := EnvProvider{}
	val, err := p.Get("TEST_SECRET")
	if err != nil {
		t.Fatalf("expected secret, got error %v", err)
	}
	if val != "value" {
		t.Fatalf("expected value, got %s", val)
	}

	if _, err := p.Get("MISSING_SECRET"); err == nil {
		t.Fatalf("expected error for missing secret")
	}
}

func TestCachedProvider(t *testing.T) {
	base := EnvProvider{}
	os.Setenv("CACHE_SECRET", "1")
	t.Cleanup(func() { os.Unsetenv("CACHE_SECRET") })

	cached := NewCachedProvider(base, 100*time.Millisecond)
	val, err := cached.Get("CACHE_SECRET")
	if err != nil {
		t.Fatalf("expected value, got %v", err)
	}
	if val != "1" {
		t.Fatalf("expected 1, got %s", val)
	}

	os.Setenv("CACHE_SECRET", "2")
	// Still cached
	val, err = cached.Get("CACHE_SECRET")
	if err != nil {
		t.Fatalf("expected cached value, got %v", err)
	}
	if val != "1" {
		t.Fatalf("expected cached value 1, got %s", val)
	}

	time.Sleep(150 * time.Millisecond)
	val, err = cached.Get("CACHE_SECRET")
	if err != nil {
		t.Fatalf("expected refreshed value, got %v", err)
	}
	if val != "2" {
		t.Fatalf("expected refreshed value 2, got %s", val)
	}
}
