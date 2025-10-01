package sync

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/your-org/pestgenie-sdui/internal/middleware"
	"github.com/your-org/pestgenie-sdui/internal/models"
)

// Handler exposes the sync endpoints consumed by the mobile client.
type Handler struct{}

// NewHandler creates a sync handler. Dependencies (datastore, pubsub, etc.) can
// be threaded in later as the service matures.
func NewHandler() *Handler {
	return &Handler{}
}

// CreateJob receives pending job payloads from the device for persistence.
func (h *Handler) CreateJob(w http.ResponseWriter, r *http.Request) {
	var payload models.JobUploadData
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	corr := middleware.FromContext(r.Context())
	log.Printf("job upload received (corr=%s, id=%s, customer=%s)", corr, payload.ID, payload.CustomerName)

	response := models.UploadResponse{
		Success:  true,
		JobID:    payload.ID,
		ServerID: payload.ID, // placeholder until persistence assigns IDs
		Message:  "queued",
	}

	writeJSON(w, http.StatusAccepted, response)
}

// CreateChemical ingests chemical inventory updates.
func (h *Handler) CreateChemical(w http.ResponseWriter, r *http.Request) {
	var payload models.ChemicalUploadData
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	corr := middleware.FromContext(r.Context())
	log.Printf("chemical upload received (corr=%s, id=%s, name=%s)", corr, payload.ID, payload.Name)

	response := models.UploadResponse{
		Success:  true,
		JobID:    payload.ID,
		ServerID: payload.ID,
		Message:  "queued",
	}

	writeJSON(w, http.StatusAccepted, response)
}

// CreateChemicalTreatment ingests treatment logs from the device.
func (h *Handler) CreateChemicalTreatment(w http.ResponseWriter, r *http.Request) {
	var payload models.ChemicalTreatmentUploadData
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	corr := middleware.FromContext(r.Context())
	log.Printf("chemical treatment upload received (corr=%s, id=%s, job=%s)", corr, payload.ID, payload.JobID)

	response := models.UploadResponse{
		Success:  true,
		JobID:    payload.ID,
		ServerID: payload.ID,
		Message:  "queued",
	}

	writeJSON(w, http.StatusAccepted, response)
}

// RegisterDevice stores the APNs token for push notifications.
func (h *Handler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	var payload models.DeviceRegistration
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	corr := middleware.FromContext(r.Context())
	log.Printf("device registration received (corr=%s, bundle=%s)", corr, payload.BundleID)

	writeJSON(w, http.StatusAccepted, map[string]string{"status": "queued"})
}

// GetUpdates returns route/job deltas since the provided timestamp.
func (h *Handler) GetUpdates(w http.ResponseWriter, r *http.Request) {
	sinceParam := r.URL.Query().Get("since")
	corr := middleware.FromContext(r.Context())

	var since time.Time
	var err error
	if sinceParam != "" {
		since, err = time.Parse(time.RFC3339, sinceParam)
		if err != nil {
			http.Error(w, "invalid since parameter", http.StatusBadRequest)
			return
		}
	}

	log.Printf("updates requested (corr=%s, since=%s)", corr, since)

	payload := models.ServerUpdates{
		Jobs:               []models.JobUpdateData{},
		Routes:             []models.RouteUpdateData{},
		Chemicals:          []models.ChemicalUpdateData{},
		ChemicalTreatments: []models.ChemicalTreatmentUpdateData{},
	}

	writeJSON(w, http.StatusOK, payload)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("failed to encode response: %v", err)
	}
}
