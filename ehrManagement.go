package main

import (
	"ehrchaincode/chaincode" // Adjust import path as needed
	"log"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	smartContract := new(chaincode.SmartContract)

	cc, err := contractapi.NewChaincode(smartContract)
	if err != nil {
		log.Panicf("Error creating EHR management chaincode: %v", err)
	}

	if err := cc.Start(); err != nil {
		log.Panicf("Error starting EHR management chaincode: %v", err)
	}
}
