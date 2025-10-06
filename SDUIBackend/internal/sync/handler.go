package sync

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"log/slog"

	"github.com/your-org/pestgenie-sdui/internal/config"
	domain "github.com/your-org/pestgenie-sdui/internal/domain/models"
	"github.com/your-org/pestgenie-sdui/internal/domain/repository"
	"github.com/your-org/pestgenie-sdui/internal/http/respond"
	"github.com/your-org/pestgenie-sdui/internal/middleware"
	transport "github.com/your-org/pestgenie-sdui/internal/models"
)

// Handler exposes the sync endpoints consumed by the mobile client.
type Handler struct {
	repos  repository.Repository
	cfg    config.SyncConfig
	logger *slog.Logger
}

// NewHandler creates a sync handler with its dependencies injected.
func NewHandler(repos repository.Repository, cfg config.SyncConfig, logger *slog.Logger) *Handler {
	return &Handler{repos: repos, cfg: cfg, logger: logger}
}

// CreateJob receives pending job payloads from the device for persistence.
func (h *Handler) CreateJob(w http.ResponseWriter, r *http.Request) {
	var payload transport.JobUploadData
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		respond.Error(w, http.StatusBadRequest, "invalid payload", err.Error())
		return
	}

	logger := middleware.LoggerFrom(r.Context())
	job := domain.JobUpload{
		ID:            payload.ID,
		CustomerName:  payload.CustomerName,
		Address:       payload.Address,
		ScheduledDate: payload.ScheduledDate,
		Status:        payload.Status,
		ReceivedAt:    time.Now(),
	}

	if err := h.saveWithRetry(func() error { return h.repos.Sync.SaveJobUpload(job) }); err != nil {
		logger.Error("failed to persist job upload", slog.Any("error", err))
		respond.Error(w, http.StatusInternalServerError, "failed to queue job", "temporary error, please retry")
		return
	}

	respond.JSON(w, http.StatusAccepted, transport.UploadResponse{
		Success:  true,
		JobID:    payload.ID,
		ServerID: payload.ID,
		Message:  "queued",
	})
}

// CreateChemical ingests chemical inventory updates.
func (h *Handler) CreateChemical(w http.ResponseWriter, r *http.Request) {
	var payload transport.ChemicalUploadData
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		respond.Error(w, http.StatusBadRequest, "invalid payload", err.Error())
		return
	}

	logger := middleware.LoggerFrom(r.Context())
	upload := domain.ChemicalUpload{
		ID:               payload.ID,
		Name:             payload.Name,
		ActiveIngredient: payload.ActiveIngredient,
		ManufacturerName: payload.ManufacturerName,
		EPARegistration:  payload.EPARegistration,
		Concentration:    payload.Concentration,
		UnitOfMeasure:    payload.UnitOfMeasure,
		QuantityInStock:  payload.QuantityInStock,
		ExpirationDate:   payload.ExpirationDate,
		LastModified:     payload.LastModified,
	}

	if err := h.saveWithRetry(func() error { return h.repos.Sync.SaveChemicalUpload(upload) }); err != nil {
		logger.Error("failed to persist chemical upload", slog.Any("error", err))
		respond.Error(w, http.StatusInternalServerError, "failed to queue chemical", "temporary error, please retry")
		return
	}

	respond.JSON(w, http.StatusAccepted, transport.UploadResponse{
		Success:  true,
		JobID:    payload.ID,
		ServerID: payload.ID,
		Message:  "queued",
	})
}

// CreateChemicalTreatment ingests treatment logs from the device.
func (h *Handler) CreateChemicalTreatment(w http.ResponseWriter, r *http.Request) {
	var payload transport.ChemicalTreatmentUploadData
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		respond.Error(w, http.StatusBadRequest, "invalid payload", err.Error())
		return
	}

	logger := middleware.LoggerFrom(r.Context())
	upload := domain.ChemicalTreatmentUpload{
		ID:                 payload.ID,
		JobID:              payload.JobID,
		ChemicalID:         payload.ChemicalID,
		ApplicatorName:     payload.ApplicatorName,
		ApplicationDate:    payload.ApplicationDate,
		ApplicationMethod:  payload.ApplicationMethod,
		TargetPests:        payload.TargetPests,
		QuantityUsed:       payload.QuantityUsed,
		DosageRate:         payload.DosageRate,
		DilutionRatio:      payload.DilutionRatio,
		EnvironmentalNotes: payload.EnvironmentalNotes,
		WeatherConditions:  payload.WeatherSummary,
		Notes:              payload.Notes,
		LastModified:       payload.LastModified,
	}

	if err := h.saveWithRetry(func() error { return h.repos.Sync.SaveChemicalTreatment(upload) }); err != nil {
		logger.Error("failed to persist chemical treatment", slog.Any("error", err))
		respond.Error(w, http.StatusInternalServerError, "failed to queue treatment", "temporary error, please retry")
		return
	}

	respond.JSON(w, http.StatusAccepted, transport.UploadResponse{
		Success:  true,
		JobID:    payload.ID,
		ServerID: payload.ID,
		Message:  "queued",
	})
}

// RegisterDevice stores the APNs token for push notifications.
func (h *Handler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	var payload transport.DeviceRegistration
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		respond.Error(w, http.StatusBadRequest, "invalid payload", err.Error())
		return
	}

	logger := middleware.LoggerFrom(r.Context())
	device := domain.DeviceToken{
		Token:        payload.Token,
		Platform:     payload.Platform,
		BundleID:     payload.BundleID,
		RegisteredAt: time.Now(),
	}

	if err := h.saveWithRetry(func() error { return h.repos.Devices.SaveDeviceToken(device) }); err != nil {
		logger.Error("failed to save device token", slog.Any("error", err))
		respond.Error(w, http.StatusInternalServerError, "failed to register device", "temporary error, please retry")
		return
	}

	respond.JSON(w, http.StatusAccepted, map[string]string{"status": "queued"})
}

// GetUpdates returns route/job deltas since the provided timestamp.
func (h *Handler) GetUpdates(w http.ResponseWriter, r *http.Request) {
	sinceParam := r.URL.Query().Get("since")

	var since time.Time
	var err error
	if sinceParam != "" {
		since, err = time.Parse(time.RFC3339, sinceParam)
		if err != nil {
			respond.Error(w, http.StatusBadRequest, "invalid since parameter", err.Error())
			return
		}
	}

	logger := middleware.LoggerFrom(r.Context())
	logger.Info("updates requested", slog.Time("since", since))

	payload := transport.ServerUpdates{
		Jobs:               []transport.JobUpdateData{},
		Routes:             []transport.RouteUpdateData{},
		Chemicals:          []transport.ChemicalUpdateData{},
		ChemicalTreatments: []transport.ChemicalTreatmentUpdateData{},
	}

	respond.JSON(w, http.StatusOK, payload)
}

func (h *Handler) saveWithRetry(fn func() error) error {
	attempts := h.cfg.MaxRetries
	if attempts <= 0 {
		attempts = 1
	}
	backoff := h.cfg.Backoff
	if backoff <= 0 {
		backoff = 100 * time.Millisecond
	}

	var lastErr error
	for i := 0; i < attempts; i++ {
		if err := fn(); err != nil {
			lastErr = err
			time.Sleep(backoff * time.Duration(i+1))
			continue
		}
		return nil
	}
	if lastErr == nil {
		lastErr = errors.New("unknown error")
	}
	return lastErr
}
