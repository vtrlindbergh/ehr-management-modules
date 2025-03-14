package mocks

// MockClientIdentity implements contractapi.ClientIdentity.
// It returns the MSP ID and Enrollment ID that you configure.
type MockClientIdentity struct {
	IDValue  string
	MSPValue string
}

// GetID returns the enrollment ID (like "testUserA").
func (m *MockClientIdentity) GetID() (string, error) {
	return m.IDValue, nil
}

// GetMSPID returns the MSP ID (like "Org1MSP").
func (m *MockClientIdentity) GetMSPID() (string, error) {
	return m.MSPValue, nil
}

// GetAttributeValue is unused here, but required for the interface.
func (m *MockClientIdentity) GetAttributeValue(attrName string) (string, bool, error) {
	return "", false, nil
}

// AssertAttributeValue is unused here, but required for the interface.
func (m *MockClientIdentity) AssertAttributeValue(attrName, attrValue string) error {
	return nil
}
