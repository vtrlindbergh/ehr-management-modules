package services

import (
	"encoding/json"
	"fmt"
	"log"

	"ehrchaincode/chaincode/models"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ConsentService struct{}

// GrantConsent creates or updates a Consent record for a patient.
func (c *ConsentService) GrantConsent(ctx contractapi.TransactionContextInterface, patientID string, providersJSON string) error {
	log.Printf("GrantConsent called with patientID: %s, providersJSON: %s", patientID, providersJSON)
	txID := ctx.GetStub().GetTxID()
	channelID := ctx.GetStub().GetChannelID()
	log.Printf("Transaction ID: %s, Channel ID: %s", txID, channelID)

	var providers []string
	if err := json.Unmarshal([]byte(providersJSON), &providers); err != nil {
		log.Printf("Failed to parse authorized providers JSON: %v", err)
		return fmt.Errorf("failed to parse authorized providers JSON: %v", err)
	}

	consent := models.Consent{
		PatientID:           patientID,
		AuthorizedProviders: providers,
	}

	consentBytes, err := json.Marshal(consent)
	if err != nil {
		log.Printf("Failed to marshal consent: %v", err)
		return fmt.Errorf("failed to marshal consent: %v", err)
	}

	consentKey := "CONSENT-" + patientID
	log.Printf("Storing consent record with key: %s, value: %s", consentKey, string(consentBytes))
	if err := ctx.GetStub().PutState(consentKey, consentBytes); err != nil {
		log.Printf("Failed to store consent: %v", err)
		return fmt.Errorf("failed to store consent: %v", err)
	}

	log.Printf("Consent successfully granted for patientID: %s", patientID)
	return nil
}

// RevokeConsent removes the Consent record for a patient.
func (c *ConsentService) RevokeConsent(ctx contractapi.TransactionContextInterface, patientID string) error {
	log.Printf("RevokeConsent transaction for patientID: %s", patientID)
	if err := ctx.GetStub().DelState("CONSENT-" + patientID); err != nil {
		log.Printf("Failed to revoke consent for patientID %s: %v", patientID, err)
		return fmt.Errorf("failed to revoke consent: %v", err)
	}
	log.Printf("Consent successfully revoked for patientID: %s", patientID)
	return nil
}

// ReadConsent retrieves the Consent record for a patient.
func (c *ConsentService) ReadConsent(ctx contractapi.TransactionContextInterface, patientID string) (*models.Consent, error) {
	consentBytes, err := ctx.GetStub().GetState("CONSENT-" + patientID)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve consent record: %v", err)
	}
	if consentBytes == nil {
		return nil, fmt.Errorf("no consent record found for patientID: %s", patientID)
	}

	var consent models.Consent
	if err := json.Unmarshal(consentBytes, &consent); err != nil {
		return nil, fmt.Errorf("failed to parse consent record: %v", err)
	}

	return &consent, nil
}
