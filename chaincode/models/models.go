package models

// FHIRResource represents a HL7 FHIR resource in JSON format
type FHIRResource struct {
	ResourceType string     `json:"resourceType"`
	ID           string     `json:"id,omitempty"`
	Meta         []MetaData `json:"meta"`
	// Store the actual structured FHIR data as a JSON string
	RawContent string `json:"rawContent"`
	// Keep the array of integers for basic vitals that need quick access
	Content []int `json:"content"`
}

// MetaData for FHIR resources
type MetaData struct {
	Version     string `json:"version"`
	LastUpdated string `json:"lastUpdated,omitempty"`
}

// EHR represents a simplified Electronic Health Record.
type EHR struct {
	PatientID   string       `json:"patientID"`
	PatientName string       `json:"patientName"`
	CreatedBy   string       `json:"createdBy"`  // The provider who created this EHR
	HealthData  FHIRResource `json:"healthData"` // Structured HL7 FHIR data
	LastUpdated string       `json:"lastUpdated"`
}

// Consent represents a simplified consent model.
type Consent struct {
	PatientID           string   `json:"patientID"`
	AuthorizedProviders []string `json:"authorizedProviders"`
}

// Example usage of the FHIRResource:
/*
{
  "patientID": "P001",
  "patientName": "John Doe",
  "healthData": {
    "resourceType": "Observation",
    "id": "bp-reading",
    "meta": [
      {
        "version": "1.0",
        "lastUpdated": "2025-01-01T12:00:00Z"
      }
    ],
    "rawContent": "{\"resourceType\":\"Observation\",\"id\":\"bp-reading\",\"status\":\"final\",\"category\":[{\"coding\":[{\"system\":\"http://terminology.hl7.org/CodeSystem/observation-category\",\"code\":\"vital-signs\",\"display\":\"Vital Signs\"}]}],\"code\":{\"coding\":[{\"system\":\"http://loinc.org\",\"code\":\"85354-9\",\"display\":\"Blood pressure panel\"}]},\"subject\":{\"reference\":\"Patient/P001\"},\"effectiveDateTime\":\"2025-01-01T12:00:00Z\",\"component\":[{\"code\":{\"coding\":[{\"system\":\"http://loinc.org\",\"code\":\"8480-6\",\"display\":\"Systolic blood pressure\"}]},\"valueQuantity\":{\"value\":120,\"unit\":\"mmHg\"}},{\"code\":{\"coding\":[{\"system\":\"http://loinc.org\",\"code\":\"8462-4\",\"display\":\"Diastolic blood pressure\"}]},\"valueQuantity\":{\"value\":80,\"unit\":\"mmHg\"}}]}",
    "content": [120, 80]
  },
  "lastUpdated": "2025-01-01"
}
*/
