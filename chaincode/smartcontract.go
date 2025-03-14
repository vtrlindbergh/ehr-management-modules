package chaincode

import (
	"ehrchaincode/chaincode/models"
	"ehrchaincode/chaincode/services"
	"ehrchaincode/chaincode/services/auth"
	"ehrchaincode/chaincode/utils"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
	contractapi.Contract
	ehrService     services.EHRService
	consentService services.ConsentService
	authService    auth.AuthService
}

// NewSmartContract instantiates and returns a new SmartContract.
func NewSmartContract() *SmartContract {
	return &SmartContract{
		ehrService:     services.EHRService{},
		consentService: services.ConsentService{},
		authService:    auth.AuthService{},
	}
}

// CreateEHR delegates to the EHR service.
func (s *SmartContract) CreateEHR(ctx contractapi.TransactionContextInterface, ehrJSON string) error {
	return s.ehrService.CreateEHR(ctx, ehrJSON)
}

// ReadEHR delegates to the EHR service.
func (s *SmartContract) ReadEHR(ctx contractapi.TransactionContextInterface, patientID string) (*models.EHR, error) {
	return s.ehrService.ReadEHR(ctx, patientID)
}

// UpdateEHR delegates to the EHR service.
func (s *SmartContract) UpdateEHR(ctx contractapi.TransactionContextInterface, ehrJSON string) error {
	return s.ehrService.UpdateEHR(ctx, ehrJSON)
}

// DeleteEHR delegates to the EHR service.
func (s *SmartContract) DeleteEHR(ctx contractapi.TransactionContextInterface, patientID string) error {
	return s.ehrService.DeleteEHR(ctx, patientID)
}

// GrantConsent delegates to the Consent service.
func (s *SmartContract) GrantConsent(ctx contractapi.TransactionContextInterface, patientID string, providersJSON string) error {
	return s.consentService.GrantConsent(ctx, patientID, providersJSON)
}

// RevokeConsent delegates to the Consent service.
func (s *SmartContract) RevokeConsent(ctx contractapi.TransactionContextInterface, patientID string) error {
	return s.consentService.RevokeConsent(ctx, patientID)
}

// ReadConsent delegates to the Consent service.
func (s *SmartContract) ReadConsent(ctx contractapi.TransactionContextInterface, patientID string) (*models.Consent, error) {
	return s.consentService.ReadConsent(ctx, patientID)
}

// GetState uses the utility function to retrieve a key's value.
func (s *SmartContract) GetState(ctx contractapi.TransactionContextInterface, key string) (string, error) {
	return utils.GetState(ctx, key)
}
