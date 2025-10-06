package memory

import (
	"errors"
	"strconv"
	"sync"
	"time"

	"github.com/your-org/pestgenie-sdui/internal/domain/models"
	"github.com/your-org/pestgenie-sdui/internal/domain/repository"
)

// Store is a thread-safe in-memory repository implementation for local development.
type Store struct {
	mu sync.RWMutex

	technicians map[string]models.Technician
	routes      map[routeKey]models.Route
	templates   map[string]models.ScreenTemplate
	jobs        []models.JobUpload
	chemicals   []models.ChemicalUpload
	treatments  []models.ChemicalTreatmentUpload
	devices     []models.DeviceToken
}

// NewStore creates an empty in-memory store.
func NewStore() *Store {
	return &Store{
		technicians: make(map[string]models.Technician),
		routes:      make(map[routeKey]models.Route),
		templates:   make(map[string]models.ScreenTemplate),
	}
}

// Ensure Store satisfies repository interfaces at compile time.
var _ repository.TechnicianRepository = (*Store)(nil)
var _ repository.RouteRepository = (*Store)(nil)
var _ repository.ScreenRepository = (*Store)(nil)
var _ repository.SyncRepository = (*Store)(nil)
var _ repository.DeviceRepository = (*Store)(nil)

// routeKey identifies a route by technician and service date.
type routeKey struct {
	technicianID string
	serviceDate  string // yyyy-mm-dd
}

// Technician operations

func (s *Store) GetByID(id string) (models.Technician, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	tech, ok := s.technicians[id]
	if !ok {
		return models.Technician{}, errors.New("technician not found")
	}
	return tech, nil
}

// AddTechnician seeds the store with a technician (helper for tests/dev).
func (s *Store) AddTechnician(t models.Technician) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.technicians[t.ID] = t
}

// Route operations

func (s *Store) GetRoute(technicianID string, serviceDate time.Time) (models.Route, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	key := routeKey{technicianID: technicianID, serviceDate: serviceDate.Format("2006-01-02")}
	route, ok := s.routes[key]
	if !ok {
		return models.Route{}, errors.New("route not found")
	}
	return route, nil
}

func (s *Store) SaveRoute(route models.Route) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := routeKey{technicianID: route.TechnicianID, serviceDate: route.ServiceDate.Format("2006-01-02")}
	if route.LastModified.IsZero() {
		route.LastModified = time.Now()
	}
	s.routes[key] = route
	return nil
}

// Screen operations

func (s *Store) GetTemplate(id string, version int) (models.ScreenTemplate, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	key := templateKey(id, version)
	tpl, ok := s.templates[key]
	if !ok {
		return models.ScreenTemplate{}, errors.New("template not found")
	}
	return tpl, nil
}

func (s *Store) SaveTemplate(template models.ScreenTemplate) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if template.Version == 0 {
		template.Version = 1
	}
	if template.CreatedAt.IsZero() {
		template.CreatedAt = time.Now()
	}
	template.UpdatedAt = time.Now()
	s.templates[templateKey(template.ID, template.Version)] = template
	return nil
}

func templateKey(id string, version int) string {
	return id + "#" + strconv.Itoa(version)
}

// Sync operations

func (s *Store) SaveJobUpload(upload models.JobUpload) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	upload.ReceivedAt = time.Now()
	s.jobs = append(s.jobs, upload)
	return nil
}

func (s *Store) SaveChemicalUpload(upload models.ChemicalUpload) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.chemicals = append(s.chemicals, upload)
	return nil
}

func (s *Store) SaveChemicalTreatment(upload models.ChemicalTreatmentUpload) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.treatments = append(s.treatments, upload)
	return nil
}

func (s *Store) ListPendingJobs(limit int) ([]models.JobUpload, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if limit <= 0 || limit > len(s.jobs) {
		limit = len(s.jobs)
	}
	out := make([]models.JobUpload, limit)
	copy(out, s.jobs[:limit])
	return out, nil
}

// Device tokens

func (s *Store) SaveDeviceToken(token models.DeviceToken) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if token.RegisteredAt.IsZero() {
		token.RegisteredAt = time.Now()
	}
	s.devices = append(s.devices, token)
	return nil
}
