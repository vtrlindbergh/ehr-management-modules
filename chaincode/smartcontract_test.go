package chaincode_test

import (
	"testing"

	"github.com/stretchr/testify/require"

	// Import your chaincode package and the mocks
	"ehrchaincode/chaincode"
	"ehrchaincode/chaincode/mocks"
)

func TestCreateAndReadEHR(t *testing.T) {
	// 1) Instantiate your SmartContract
	sc := new(chaincode.SmartContract)

	// 2) Create a MockTransactionContext that returns a mock identity
	mockCtx := &mocks.MockTransactionContext{
		ClientIdentity: &mocks.MockClientIdentity{
			IDValue:  "testUserA",
			MSPValue: "Org1MSP",
		},
	}

	// 3) Call chaincode methods directly
	ehrJSON := `{
		"patientID": "P001",
		"patientName": "John Doe",
		"healthData": "Blood Pressure 120/80",
		"lastUpdated": "2025-01-01"
	}`

	// CreateEHR
	err := sc.CreateEHR(mockCtx, ehrJSON)
	require.NoError(t, err, "CreateEHR should not fail when identity is mocked")

	// ReadEHR
	ehr, err := sc.ReadEHR(mockCtx, "P001")
	require.NoError(t, err, "ReadEHR should not fail")
	require.NotNil(t, ehr)

	require.Equal(t, "P001", ehr.PatientID)
	require.Equal(t, "John Doe", ehr.PatientName)
	require.Equal(t, "Blood Pressure 120/80", ehr.HealthData)
	require.Equal(t, "2025-01-01", ehr.LastUpdated)
}

func TestUpdateEHR(t *testing.T) {
	sc := new(chaincode.SmartContract)
	mockCtx := &mocks.MockTransactionContext{
		ClientIdentity: &mocks.MockClientIdentity{
			IDValue:  "testUserB",
			MSPValue: "Org1MSP",
		},
	}

	// First create the EHR
	ehrJSON := `{
		"patientID": "P001",
		"patientName": "John Doe",
		"healthData": "BP 120/80",
		"lastUpdated": "2025-01-01"
	}`
	require.NoError(t, sc.CreateEHR(mockCtx, ehrJSON))

	// Now update
	updatedJSON := `{
		"patientID": "P001",
		"patientName": "John Doe (UPDATED)",
		"healthData": "BP 110/70",
		"lastUpdated": "2025-02-01"
	}`
	err := sc.UpdateEHR(mockCtx, updatedJSON)
	require.NoError(t, err)

	// Read back
	ehr, err := sc.ReadEHR(mockCtx, "P001")
	require.NoError(t, err)
	require.NotNil(t, ehr)
	require.Equal(t, "John Doe (UPDATED)", ehr.PatientName)
	require.Equal(t, "BP 110/70", ehr.HealthData)
	require.Equal(t, "2025-02-01", ehr.LastUpdated)
}

func TestDeleteEHR(t *testing.T) {
	sc := new(chaincode.SmartContract)
	mockCtx := &mocks.MockTransactionContext{
		ClientIdentity: &mocks.MockClientIdentity{
			IDValue:  "testUserA",
			MSPValue: "Org1MSP",
		},
	}

	// Create
	ehrJSON := `{
		"patientID": "P001",
		"patientName": "John Doe",
		"healthData": "BP 120/80",
		"lastUpdated": "2025-01-01"
	}`
	require.NoError(t, sc.CreateEHR(mockCtx, ehrJSON))

	// Delete
	require.NoError(t, sc.DeleteEHR(mockCtx, "P001"))

	// Attempt to read after delete
	_, err := sc.ReadEHR(mockCtx, "P001")
	require.Error(t, err, "ReadEHR on a deleted EHR should fail")
	require.Contains(t, err.Error(), "no EHR found")
}

func TestGrantRevokeConsent(t *testing.T) {
	sc := new(chaincode.SmartContract)
	mockCtx := &mocks.MockTransactionContext{
		ClientIdentity: &mocks.MockClientIdentity{
			IDValue:  "testUserA",
			MSPValue: "Org1MSP",
		},
	}

	patientID := "P001"
	providersJSON := `["ProviderA","ProviderB"]`

	// Grant
	err := sc.GrantConsent(mockCtx, patientID, providersJSON)
	require.NoError(t, err, "GrantConsent should succeed")

	// Revoke
	err = sc.RevokeConsent(mockCtx, patientID)
	require.NoError(t, err, "RevokeConsent should succeed")
}
