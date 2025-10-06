package respond

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
)

// JSON writes a payload as JSON with given status code.
func JSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if payload == nil {
		return
	}
	_ = json.NewEncoder(w).Encode(payload)
}

// Error writes RFC7807-style problem details response.
func Error(w http.ResponseWriter, status int, title, detail string) {
	if status == 0 {
		status = http.StatusInternalServerError
	}

	problem := ProblemDetails{
		Type:    "about:blank",
		Title:   title,
		Status:  status,
		Detail:  detail,
		TraceID: uuid.NewString(),
	}
	JSON(w, status, problem)
}

// ProblemDetails represents a RFC7807 error payload.
type ProblemDetails struct {
	Type    string `json:"type"`
	Title   string `json:"title"`
	Status  int    `json:"status"`
	Detail  string `json:"detail,omitempty"`
	TraceID string `json:"traceId,omitempty"`
}
