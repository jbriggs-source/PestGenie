package swaggerui

import (
	"embed"
	"net/http"
)

//go:embed doc.json index.html
var swaggerFS embed.FS

// SpecHandler serves the OpenAPI specification as JSON.
func SpecHandler(w http.ResponseWriter, r *http.Request) {
	data, err := swaggerFS.ReadFile("doc.json")
	if err != nil {
		http.Error(w, "spec not found", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(data)
}

// UIHandler serves the Swagger UI HTML referencing the doc.json endpoint.
func UIHandler(w http.ResponseWriter, r *http.Request) {
	data, err := swaggerFS.ReadFile("index.html")
	if err != nil {
		http.Error(w, "swagger ui not found", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(data)
}
