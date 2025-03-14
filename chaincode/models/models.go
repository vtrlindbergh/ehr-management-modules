package models

// EHR represents a simplified Electronic Health Record.
type EHR struct {
	PatientID   string `json:"patientID"`
	PatientName string `json:"patientName"`
	HealthData  string `json:"healthData"` // Could be JSON or structured data
	LastUpdated string `json:"lastUpdated"`
}

// Consent represents a simplified consent model.
type Consent struct {
	PatientID           string   `json:"patientID"`
	AuthorizedProviders []string `json:"authorizedProviders"`
}
