package models

import "time"

// SDUIScreen mirrors the contract consumed by the iOS app.
type SDUIScreen struct {
	Version   int           `json:"version"`
	Component SDUIComponent `json:"component"`
}

// SDUIComponent represents a single node in the component tree. Only the
// commonly used fields are modelled here; the service can extend this struct as
// new component capabilities are added.
type SDUIComponent struct {
	ID           string             `json:"id,omitempty"`
	Type         string             `json:"type"`
	Key          string             `json:"key,omitempty"`
	Text         string             `json:"text,omitempty"`
	Label        string             `json:"label,omitempty"`
	ActionID     string             `json:"actionId,omitempty"`
	Font         string             `json:"font,omitempty"`
	Color        string             `json:"color,omitempty"`
	Foreground   string             `json:"foregroundColor,omitempty"`
	Background   string             `json:"backgroundColor,omitempty"`
	ValueKey     string             `json:"valueKey,omitempty"`
	Placeholder  string             `json:"placeholder,omitempty"`
	ConditionKey string             `json:"conditionKey,omitempty"`
	Destination  string             `json:"destination,omitempty"`
	Children     []SDUIComponent    `json:"children,omitempty"`
	ItemView     *SDUIComponent     `json:"itemView,omitempty"`
	Options      []SDUIPickerOption `json:"options,omitempty"`
}

// SDUIPickerOption supports picker-style components.
type SDUIPickerOption struct {
	ID    string `json:"id"`
	Text  string `json:"text"`
	Value string `json:"value"`
}

// ScreenRequest captures parameters that influence personalization.
type ScreenRequest struct {
	ScreenID    string
	UserID      string
	RouteID     string
	ServiceDate time.Time
	DeviceModel string
	AppVersion  string
	Locale      string
}

// ServerUpdates is the aggregation returned to the mobile sync client.
type ServerUpdates struct {
	Jobs               []JobUpdateData               `json:"jobs"`
	Routes             []RouteUpdateData             `json:"routes"`
	Chemicals          []ChemicalUpdateData          `json:"chemicals"`
	ChemicalTreatments []ChemicalTreatmentUpdateData `json:"chemicalTreatments"`
}

// JobUpdateData mirrors the structure consumed by the iOS sync manager.
type JobUpdateData struct {
	ServerID      string    `json:"serverId"`
	CustomerName  string    `json:"customerName"`
	Address       string    `json:"address"`
	ScheduledDate time.Time `json:"scheduledDate"`
	Status        string    `json:"status"`
	LastModified  time.Time `json:"lastModified"`
}

// RouteUpdateData describes technician route metadata.
type RouteUpdateData struct {
	ServerID     string    `json:"serverId"`
	Name         string    `json:"name"`
	Date         time.Time `json:"date"`
	TechnicianID string    `json:"technicianId"`
	LastModified time.Time `json:"lastModified"`
}

// ChemicalUpdateData captures inventory updates.
type ChemicalUpdateData struct {
	ServerID         string    `json:"serverId"`
	Name             string    `json:"name"`
	ActiveIngredient string    `json:"activeIngredient"`
	ManufacturerName string    `json:"manufacturerName"`
	EPARegistration  string    `json:"epaRegistrationNumber"`
	QuantityInStock  float64   `json:"quantityInStock"`
	UnitOfMeasure    string    `json:"unitOfMeasure"`
	ExpirationDate   time.Time `json:"expirationDate"`
	LastModified     time.Time `json:"lastModified"`
}

// ChemicalTreatmentUpdateData mirrors on-device expectations.
type ChemicalTreatmentUpdateData struct {
	ServerID          string    `json:"serverId"`
	JobServerID       string    `json:"jobServerId"`
	ChemicalServerID  string    `json:"chemicalServerId"`
	ApplicationDate   time.Time `json:"applicationDate"`
	ApplicationMethod string    `json:"applicationMethod"`
	TargetPests       string    `json:"targetPests"`
	QuantityUsed      float64   `json:"quantityUsed"`
	LastModified      time.Time `json:"lastModified"`
}

// UploadResponse mirrors the shape expected by the iOS client after POSTs.
type UploadResponse struct {
	Success  bool   `json:"success"`
	JobID    string `json:"jobId"`
	ServerID string `json:"serverId,omitempty"`
	Message  string `json:"message,omitempty"`
}

// PhotoUploadResponse is returned when image uploads complete.
type PhotoUploadResponse struct {
	Success bool   `json:"success"`
	PhotoID string `json:"photoId"`
	URL     string `json:"url,omitempty"`
	Message string `json:"message,omitempty"`
}

// DeviceRegistration matches the payload sent from the iOS notification manager.
type DeviceRegistration struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
	BundleID string `json:"bundleId"`
}

// JobUploadData is received when the app sends pending job entities.
type JobUploadData struct {
	ID            string    `json:"id"`
	CustomerName  string    `json:"customerName"`
	Address       string    `json:"address"`
	ScheduledDate time.Time `json:"scheduledDate"`
	Status        string    `json:"status"`
}

// ChemicalUploadData is the inbound chemical payload.
type ChemicalUploadData struct {
	ID               string    `json:"id"`
	Name             string    `json:"name"`
	ActiveIngredient string    `json:"activeIngredient"`
	ManufacturerName string    `json:"manufacturerName"`
	EPARegistration  string    `json:"epaRegistrationNumber"`
	Concentration    float64   `json:"concentration"`
	UnitOfMeasure    string    `json:"unitOfMeasure"`
	QuantityInStock  float64   `json:"quantityInStock"`
	ExpirationDate   time.Time `json:"expirationDate"`
	LastModified     time.Time `json:"lastModified"`
}

// ChemicalTreatmentUploadData is the inbound treatment record from the device.
type ChemicalTreatmentUploadData struct {
	ID                 string    `json:"id"`
	JobID              string    `json:"jobId"`
	ChemicalID         string    `json:"chemicalId"`
	ApplicatorName     string    `json:"applicatorName"`
	ApplicationDate    time.Time `json:"applicationDate"`
	ApplicationMethod  string    `json:"applicationMethod"`
	TargetPests        string    `json:"targetPests"`
	QuantityUsed       float64   `json:"quantityUsed"`
	DosageRate         float64   `json:"dosageRate"`
	DilutionRatio      string    `json:"dilutionRatio"`
	EnvironmentalNotes string    `json:"environmentalConditions"`
	WeatherSummary     string    `json:"weatherConditions"`
	Notes              string    `json:"notes"`
	LastModified       time.Time `json:"lastModified"`
}
