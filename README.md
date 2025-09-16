# EcoFi

## Overview

EcoFi is a decentralized carbon credit trading platform that enables the registration, verification, issuance, and trading of carbon credits. It supports transparent project tracking, validator certification, credit issuance, offset retirement, and transfer between participants.

## Features

* Register and validate carbon offset initiatives
* Authorize certified validators to assess projects
* Issue carbon credit batches for trading
* Purchase carbon credits using STX
* Retire credits with optional beneficiary assignment
* Generate retirement certificates for transparency
* Transfer credits between participants
* Read-only queries for project, batch, holdings, and retirement details

## Data Structures

* **environmental-initiatives**: Registered carbon projects with details, lifecycle state, and offsets tracking
* **initiative-validations**: Validator assessments and verification records
* **offset-batches**: Issued carbon credit batches with availability and cost
* **offset-holdings**: User-owned carbon credits per project and production year
* **retired-offsets**: Records of permanently retired credits with optional certificate links
* **certified-validators**: Authorized validators with organizational and qualification details
* **next-initiative-id, next-batch-id, next-retirement-id, next-validation-id**: ID counters for unique tracking

## Key Functions

* **register-initiative**: Register a new carbon offset project
* **validate-initiative**: Authorize and record project validation with issued offsets
* **certify-validator**: Certify validators with organizational details
* **create-offset-batch**: Create credit batches for sale under a validated project
* **purchase-carbon-offsets**: Buy credits from available batches
* **retire-offsets**: Retire owned credits with purpose and optional recipient
* **transfer-offsets**: Transfer credits between participants
* **generate-retirement-documentation**: Issue documentation for retired credits
* **get-initiative-details, get-batch-details, get-offset-holdings, get-retirement-details**: Query functions for transparency

## Usage Flow

1. Administrator certifies validators
2. Project administrators register carbon offset initiatives
3. Certified validators validate initiatives and issue offsets
4. Administrators create carbon credit batches for sale
5. Buyers purchase credits from available batches
6. Holders may retire offsets for carbon neutrality or transfer to others
7. Administrators can generate retirement documentation for public accountability
