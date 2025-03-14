package mocks

import (
	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// FakeClientID pretends to be cid.ClientID without automatically parsing the stub.
// We store desired ID/MSP in public fields and override the methods to skip real parsing.
type FakeClientID struct {
	// The real cid.ClientID has "id", "mspid", etc. as private fields.
	// We'll store them here ourselves:
	IDVal  string
	MSPVal string

	// If your chaincode calls GetAttributeValue, store some attributes here as needed.
}

// GetID returns the fake enrollment ID.
func (f *FakeClientID) GetID() (string, error) {
	// Skip calling init(). Just return our fake IDVal.
	return f.IDVal, nil
}

// GetMSPID returns the fake MSP.
func (f *FakeClientID) GetMSPID() (string, error) {
	return f.MSPVal, nil
}

// GetAttributeValue no-ops unless you need it.
func (f *FakeClientID) GetAttributeValue(attrName string) (string, bool, error) {
	return "", false, nil
}

// AssertAttributeValue no-ops unless you need it.
func (f *FakeClientID) AssertAttributeValue(attrName, attrValue string) error {
	return nil
}

// MockTransactionContext implements contractapi.TransactionContextInterface,
// returning our custom FakeClientID instead of the real stub-parsing *cid.ClientID.
type MockTransactionContext struct {
	// We embed the real TransactionContext. That means we also satisfy
	// the TransactionContextInterface, plus any overrides below.
	contractapi.TransactionContext

	// The fake ID we want to return
	FakeCID *FakeClientID
}

// GetClientIdentity returns our FakeClientID as a *cid.ClientID pointer.
// NOTE: This "convert" works if we treat FakeClientID as the same underlying struct.
// But if your chaincode calls internal methods of cid.ClientID, it may still panic.
func (m *MockTransactionContext) GetClientIdentity() *cid.ClientID {
	// Trick: cast a *FakeClientID to a *cid.ClientID pointer.
	// They have the same method set if your chaincode only calls
	// GetID(), GetMSPID(), etc. from the interface.
	return (*cid.ClientID)(m.FakeCID)
}

// If your chaincode also calls ctx.GetStub(), you can embed a
// shimtest.MockStub or define a custom stub mock here, e.g.:
//
// func (m *MockTransactionContext) GetStub() contractapi.ChaincodeStub {
//     return &MockChaincodeStub{...}
// }
