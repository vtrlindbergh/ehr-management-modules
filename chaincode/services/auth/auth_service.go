package auth

import (
	"encoding/json"
	"fmt"
	"log"

	"ehrchaincode/chaincode/models"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type AuthService struct{}

// GetClientIdentity retrieves the 'hf.EnrollmentID' from the client certificate.
func (a *AuthService) GetClientIdentity(ctx contractapi.TransactionContextInterface) (string, error) {
	enrollmentID, found, err := ctx.GetClientIdentity().GetAttributeValue("hf.EnrollmentID")
	if err != nil {
		log.Printf("Error reading 'hf.EnrollmentID': %v", err)
		return "", fmt.Errorf("error reading 'hf.EnrollmentID': %v", err)
	}
	if !found || enrollmentID == "" {
		log.Printf("No valid 'hf.EnrollmentID' found in the certificate")
		return "", fmt.Errorf("no valid 'hf.EnrollmentID' found in the certificate")
	}
	return enrollmentID, nil
}

// IsProviderAuthorized checks whether the current client is listed in the patient's consent.
func (a *AuthService) IsProviderAuthorized(ctx contractapi.TransactionContextInterface, patientID string) (bool, error) {
	clientID, err := a.GetClientIdentity(ctx)
	if err != nil {
		return false, err
	}

	consentKey := "CONSENT-" + patientID
	consentBytes, err := ctx.GetStub().GetState(consentKey)
	if err != nil {
		log.Printf("Failed to retrieve consent record for patientID %s: %v", patientID, err)
		return false, fmt.Errorf("failed to retrieve consent record: %v", err)
	}
	if consentBytes == nil {
		log.Printf("No consent record found for patientID %s", patientID)
		return false, nil
	}

	var consent models.Consent
	if err := json.Unmarshal(consentBytes, &consent); err != nil {
		log.Printf("Failed to parse consent record for patientID %s: %v", patientID, err)
		return false, fmt.Errorf("failed to parse consent record: %v", err)
	}

	log.Printf("Consent record for patientID %s: %+v", patientID, consent)
	log.Printf("Authorized providers: %v", consent.AuthorizedProviders)
	log.Printf("Client identity (hf.EnrollmentID): %s", clientID)

	for _, provider := range consent.AuthorizedProviders {
		if provider == clientID {
			log.Printf("Provider %s is authorized to access EHR for patientID %s", clientID, patientID)
			return true, nil
		}
	}

	log.Printf("Provider %s is not authorized to access EHR for patientID %s", clientID, patientID)
	return false, nil
}
