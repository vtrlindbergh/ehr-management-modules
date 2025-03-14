package utils

import (
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// GetState retrieves the value for a given key from the ledger.
func GetState(ctx contractapi.TransactionContextInterface, key string) (string, error) {
	value, err := ctx.GetStub().GetState(key)
	if err != nil {
		return "", fmt.Errorf("failed to read from world state: %v", err)
	}
	if value == nil {
		return "", fmt.Errorf("key %s does not exist", key)
	}
	return string(value), nil
}
