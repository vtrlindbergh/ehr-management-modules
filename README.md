# EHR Management System on Hyperledger Fabric

A blockchain-based Electronic Health Record (EHR) management system built on Hyperledger Fabric. This chaincode application enables secure sharing and management of patient health records while maintaining consent controls.

## Overview

This project implements a chaincode solution for managing Electronic Health Records on the Hyperledger Fabric blockchain platform. The system provides secure methods for healthcare providers to access patient data with proper authorization.

## Features

- **EHR Management**: Create, read, update, and delete electronic health records
- **Consent Management**: Allow patients to grant and revoke provider access to their records
- **Authentication**: Validate provider identity and authorization before data access
- **Secure Storage**: Store health records securely on the blockchain

## Project Structure

- `ehrManagement.go`: Main entry point for the chaincode
- `chaincode`: Core implementation of the smart contract
  - `smartcontract.go`: Main contract implementation
  - `models/`: Data models for EHR and consent records
  - `services/`: Business logic services
    - `ehr_service.go`: EHR management functionality
    - `consent_service.go`: Consent management
    - `auth/`: Authentication services
  - `utils/`: Helper utilities

## Getting Started

### Prerequisites

- Go 1.15+
- Hyperledger Fabric v2.x
- Docker and Docker Compose

### Installation

1. Clone this repository to your Fabric development environment
2. Install dependencies:
   ```
   go mod download
   ```
3. Build the chaincode:
   ```
   go build
   ```

### Deployment

Deploy the chaincode to your Hyperledger Fabric network following the standard chaincode deployment process.

## Testing

The project includes comprehensive unit tests for the smart contract functionality:

```
go test ./chaincode/...
```

## Usage

Once deployed, the chaincode exposes the following functions:

- `CreateEHR`: Create a new patient health record
- `ReadEHR`: Retrieve a patient's health record (requires authorization)
- `UpdateEHR`: Modify an existing health record
- `DeleteEHR`: Remove a health record
- `GrantConsent`: Allow a provider to access patient records
- `RevokeConsent`: Remove a provider's access to patient records
- `ReadConsent`: View current consent settings

## License

This project is licensed under the Apache License 2.0.