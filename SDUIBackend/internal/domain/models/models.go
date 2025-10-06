package models

import "time"

// Technician represents a field technician using the app.
type Technician struct {
	ID             string
	Email          string
	DisplayName    string
	Role           string
	Region         string
	Certifications []string
}

// Route represents a technician's assignment for a given date.
type Route struct {
	ID            string
	TechnicianID  string
	ServiceDate   time.Time
	CustomerStops []RouteStop
	Alerts        []RouteAlert
	LastModified  time.Time
}

// RouteStop represents an individual customer visit.
type RouteStop struct {
	CustomerID   string
	CustomerName string
	Address      string
	WindowStart  time.Time
	WindowEnd    time.Time
	Priority     string
	Notes        string
}

// RouteAlert conveys route-level communications.
type RouteAlert struct {
	Type     string
	Message  string
	Severity string
}

// ScreenTemplate represents an SDUI template stored on the backend.
type ScreenTemplate struct {
	ID          string
	Version     int
	PayloadJSON []byte
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// ScreenContext contains personalised data to merge with templates.
type ScreenContext struct {
	Technician Technician
	Route      Route
	Metadata   map[string]string
}

// JobUpload contains job data uploaded from the device during sync.
type JobUpload struct {
	ID            string
	TechnicianID  string
	CustomerName  string
	Address       string
	ScheduledDate time.Time
	Status        string
	ReceivedAt    time.Time
}

// ChemicalUpload contains chemical inventory updates.
type ChemicalUpload struct {
	ID               string
	TechnicianID     string
	Name             string
	ActiveIngredient string
	ManufacturerName string
	EPARegistration  string
	Concentration    float64
	UnitOfMeasure    string
	QuantityInStock  float64
	ExpirationDate   time.Time
	LastModified     time.Time
}

// ChemicalTreatmentUpload contains treatment logs from the field.
type ChemicalTreatmentUpload struct {
	ID                 string
	JobID              string
	ChemicalID         string
	TechnicianID       string
	ApplicatorName     string
	ApplicationDate    time.Time
	ApplicationMethod  string
	TargetPests        string
	QuantityUsed       float64
	DosageRate         float64
	DilutionRatio      string
	EnvironmentalNotes string
	WeatherConditions  string
	Notes              string
	LastModified       time.Time
}

// DeviceToken associates an APNs token with a technician.
type DeviceToken struct {
	Token        string
	TechnicianID string
	Platform     string
	BundleID     string
	RegisteredAt time.Time
}
