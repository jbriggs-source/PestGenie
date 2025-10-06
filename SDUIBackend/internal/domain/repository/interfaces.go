package repository

import (
	"time"

	"github.com/your-org/pestgenie-sdui/internal/domain/models"
)

// TechnicianRepository retrieves technician profiles.
type TechnicianRepository interface {
	GetByID(id string) (models.Technician, error)
}

// RouteRepository retrieves route assignments.
type RouteRepository interface {
	GetRoute(technicianID string, serviceDate time.Time) (models.Route, error)
	SaveRoute(route models.Route) error
}

// ScreenRepository manages SDUI templates and variants.
type ScreenRepository interface {
	GetTemplate(id string, version int) (models.ScreenTemplate, error)
	SaveTemplate(template models.ScreenTemplate) error
}

// SyncRepository persists sync uploads for downstream processing.
type SyncRepository interface {
	SaveJobUpload(upload models.JobUpload) error
	SaveChemicalUpload(upload models.ChemicalUpload) error
	SaveChemicalTreatment(upload models.ChemicalTreatmentUpload) error
	ListPendingJobs(limit int) ([]models.JobUpload, error)
}

// DeviceRepository stores device registration tokens.
type DeviceRepository interface {
	SaveDeviceToken(token models.DeviceToken) error
}

// Repository aggregates all dependencies for service construction.
type Repository struct {
	Technicians TechnicianRepository
	Routes      RouteRepository
	Screens     ScreenRepository
	Sync        SyncRepository
	Devices     DeviceRepository
}

// Validate ensures all dependencies are present.
func (r Repository) Validate() error {
	if r.Technicians == nil {
		return ErrMissingRepository{"technicians"}
	}
	if r.Routes == nil {
		return ErrMissingRepository{"routes"}
	}
	if r.Screens == nil {
		return ErrMissingRepository{"screens"}
	}
	if r.Sync == nil {
		return ErrMissingRepository{"sync"}
	}
	if r.Devices == nil {
		return ErrMissingRepository{"devices"}
	}
	return nil
}

// ErrMissingRepository indicates a required repository has not been provided.
type ErrMissingRepository struct {
	Name string
}

func (e ErrMissingRepository) Error() string {
	return "missing repository: " + e.Name
}
