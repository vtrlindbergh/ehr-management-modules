package services

import (
	"encoding/json"
	"fmt"
	"log"

	"ehrchaincode/chaincode/models"
	"ehrchaincode/chaincode/services/auth"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type EHRService struct{}

// CreateEHR creates a new EHR on the ledger.
func (e *EHRService) CreateEHR(ctx contractapi.TransactionContextInterface, ehrJSON string) error {
	var ehr models.EHR
	if err := json.Unmarshal([]byte(ehrJSON), &ehr); err != nil {
		log.Printf("Failed to parse EHR JSON: %v", err)
		return fmt.Errorf("failed to parse EHR JSON: %v. Ensure the JSON is valid and properly formatted", err)
	}

	exists, err := e.ehrExists(ctx, ehr.PatientID)
	if err != nil {
		log.Printf("Error checking if EHR exists for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to check if EHR exists: %v", err)
	}
	if exists {
		log.Printf("EHR for patientID '%s' already exists", ehr.PatientID)
		return fmt.Errorf("EHR for patientID '%s' already exists. Use UpdateEHR to modify it", ehr.PatientID)
	}

	log.Printf("CreateEHR transaction for patientID: %s", ehr.PatientID)
	ehrBytes, err := json.Marshal(ehr)
	if err != nil {
		log.Printf("Failed to marshal EHR for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to marshal EHR: %v", err)
	}

	if err := ctx.GetStub().PutState("EHR-"+ehr.PatientID, ehrBytes); err != nil {
		log.Printf("Failed to write EHR to ledger for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to write EHR to ledger: %v", err)
	}

	log.Printf("EHR successfully created for patientID: %s", ehr.PatientID)
	return nil
}

// ReadEHR retrieves an EHR from the ledger after verifying provider authorization.
func (e *EHRService) ReadEHR(ctx contractapi.TransactionContextInterface, patientID string) (*models.EHR, error) {
	authSvc := auth.AuthService{}
	authorized, err := authSvc.IsProviderAuthorized(ctx, patientID)
	if err != nil {
		log.Printf("Error checking provider authorization for patientID %s: %v", patientID, err)
		return nil, fmt.Errorf("failed to check provider authorization: %v", err)
	}
	if !authorized {
		log.Printf("Provider not authorized to access EHR for patientID %s", patientID)
		return nil, fmt.Errorf("provider not authorized to access this EHR")
	}

	ehrKey := "EHR-" + patientID
	ehrBytes, err := ctx.GetStub().GetState(ehrKey)
	if err != nil {
		log.Printf("Failed to read EHR from ledger for patientID %s: %v", patientID, err)
		return nil, fmt.Errorf("failed to read EHR from ledger: %v", err)
	}
	if ehrBytes == nil {
		log.Printf("No EHR found for patientID: %s", patientID)
		return nil, fmt.Errorf("no EHR found for patientID: %s", patientID)
	}

	var ehr models.EHR
	if err := json.Unmarshal(ehrBytes, &ehr); err != nil {
		log.Printf("Failed to unmarshal EHR JSON for patientID %s: %v", patientID, err)
		return nil, fmt.Errorf("failed to unmarshal EHR JSON: %v", err)
	}

	log.Printf("EHR successfully retrieved for patientID: %s", patientID)
	return &ehr, nil
}

// UpdateEHR updates an existing EHR on the ledger.
func (e *EHRService) UpdateEHR(ctx contractapi.TransactionContextInterface, ehrJSON string) error {
	var ehr models.EHR
	if err := json.Unmarshal([]byte(ehrJSON), &ehr); err != nil {
		log.Printf("Failed to parse EHR JSON: %v", err)
		return fmt.Errorf("failed to parse EHR JSON: %v. Ensure the JSON is valid and properly formatted", err)
	}

	exists, err := e.ehrExists(ctx, ehr.PatientID)
	if err != nil {
		log.Printf("Error checking if EHR exists for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to check if EHR exists: %v", err)
	}
	if !exists {
		log.Printf("EHR does not exist for patientID '%s'", ehr.PatientID)
		return fmt.Errorf("EHR does not exist for patientID '%s'. Use CreateEHR to add it", ehr.PatientID)
	}

	authSvc := auth.AuthService{}
	authorized, err := authSvc.IsProviderAuthorized(ctx, ehr.PatientID)
	if err != nil {
		log.Printf("Error checking provider authorization for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to check provider authorization: %v", err)
	}
	if !authorized {
		log.Printf("Provider not authorized to update EHR for patientID %s", ehr.PatientID)
		return fmt.Errorf("provider not authorized to update this EHR")
	}

	log.Printf("UpdateEHR transaction for patientID: %s", ehr.PatientID)
	ehrBytes, err := json.Marshal(ehr)
	if err != nil {
		log.Printf("Failed to marshal EHR for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to marshal EHR: %v", err)
	}

	if err := ctx.GetStub().PutState("EHR-"+ehr.PatientID, ehrBytes); err != nil {
		log.Printf("Failed to write updated EHR to ledger for patientID %s: %v", ehr.PatientID, err)
		return fmt.Errorf("failed to write updated EHR to ledger: %v", err)
	}

	log.Printf("EHR successfully updated for patientID: %s", ehr.PatientID)
	return nil
}

// DeleteEHR removes an EHR from the ledger.
func (e *EHRService) DeleteEHR(ctx contractapi.TransactionContextInterface, patientID string) error {
	authSvc := auth.AuthService{}
	authorized, err := authSvc.IsProviderAuthorized(ctx, patientID)
	if err != nil {
		log.Printf("Error checking provider authorization for patientID %s: %v", patientID, err)
		return fmt.Errorf("failed to check provider authorization: %v", err)
	}
	if !authorized {
		log.Printf("Provider not authorized to delete EHR for patientID %s", patientID)
		return fmt.Errorf("provider not authorized to delete this EHR")
	}

	exists, err := e.ehrExists(ctx, patientID)
	if err != nil {
		log.Printf("Error checking if EHR exists for patientID %s: %v", patientID, err)
		return fmt.Errorf("failed to check if EHR exists: %v", err)
	}
	if !exists {
		log.Printf("EHR does not exist for patientID '%s'", patientID)
		return fmt.Errorf("EHR does not exist for patientID '%s'", patientID)
	}

	log.Printf("DeleteEHR transaction for patientID: %s", patientID)
	if err := ctx.GetStub().DelState("EHR-" + patientID); err != nil {
		log.Printf("Failed to delete EHR for patientID %s: %v", patientID, err)
		return fmt.Errorf("failed to delete EHR: %v", err)
	}

	log.Printf("EHR successfully deleted for patientID: %s", patientID)
	return nil
}

// ehrExists checks if an EHR exists for the given patientID.
func (e *EHRService) ehrExists(ctx contractapi.TransactionContextInterface, patientID string) (bool, error) {
	ehrKey := "EHR-" + patientID
	data, err := ctx.GetStub().GetState(ehrKey)
	if err != nil {
		log.Printf("Failed to read EHR from ledger for patientID %s: %v", patientID, err)
		return false, fmt.Errorf("failed to read EHR from ledger: %v", err)
	}
	return data != nil, nil
}
