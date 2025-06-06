# 📝 Name Registry Smart Contract

A simple and efficient name registration system built on the Stacks blockchain using Clarity smart contracts. Register unique names and associate them with wallet addresses! 🚀

## ✨ Features

- 🏷️ **Name Registration**: Register unique names up to 50 characters
- 👤 **Address Mapping**: Bidirectional mapping between names and addresses
- 💰 **Fee System**: Configurable registration fees
- 🔄 **Name Transfer**: Transfer ownership of registered names
- 📋 **Metadata Support**: Add descriptions and website URLs to names
- 🗑️ **Name Release**: Release names back to the pool
- 🔍 **Query Functions**: Check availability and lookup information

## 🛠️ Core Functions

### Public Functions

#### `register-name`
Register a new name to your address
```clarity
(contract-call? .name-registry register-name "myname")
```

#### `transfer-name`
Transfer your registered name to another address
```clarity
(contract-call? .name-registry transfer-name "myname" 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `update-metadata`
Add description and website to your name
```clarity
(contract-call? .name-registry update-metadata "myname" "My awesome profile" "https://mysite.com")
```

#### `release-name`
Release your name back to the available pool
```clarity
(contract-call? .name-registry release-name "myname")
```

### Read-Only Functions

#### `get-name-owner`
Get the owner of a specific name
```clarity
(contract-call? .name-registry get-name-owner "myname")
```

#### `get-address-name`
Get the name registered to an address
```clarity
(contract-call? .name-registry get-address-name 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `is-name-available`
Check if a name is available for registration
```clarity
(contract-call? .name-registry is-name-available "newname")
```

## 💡 Key Learning Concepts

This contract demonstrates:
- 🗂️ **Key-Value Storage**: Using Clarity maps for efficient data storage
- 🔗 **Bidirectional Mapping**: Linking names to addresses and vice versa
- 💸 **Payment Processing**: Handling STX transfers for registration fees
- 🛡️ **Access Control**: Owner-only functions and validation
- 📊 **State Management**: Tracking registrations and metadata

## 🚀 Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd name-registry
clarinet check
```

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy --testnet
```

## 📋 Contract Details

- **Registration Fee**: 1 STX (configurable by contract owner)
- **Name Length**: 1-50 ASCII characters
- **One Name Per Address**: Each address can only register one name
- **Unique Names**: Each name can only be registered once

## 🔧 Error Codes

- `u100`: Unauthorized access
- `u101`: Name already taken
- `u102`: Name not found
- `u103`: Invalid name format
- `u104`: Address already has a registered name
- `u105`: Insufficient payment

## 🤝 Contributing

Feel free to submit issues and enhancement requests! 

## 📄 License

This project is open source and available under the MIT License.
```

**Git Commit Message:**
```
feat: implement name registry MVP with registration and transfer functionality
```

**GitHub Pull Request Title:**
```
🚀 Add Name Registry Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## 📝 Summary
Added a complete Name Registry smart contract that allows users to register unique names and associate them with their wallet addresses.

## ✨ Features Added
- Name registration with STX payment
- Bidirectional name-to-address mapping
- Name transfer functionality
- Metadata support (description, website)
- Name release mechanism
- Comprehensive read-only query functions
- Owner-controlled registration fees

## 🛠️ Technical Details
- Uses Clarity maps for efficient key-value storage
- Implements proper access control and validation
- Handles STX transfers for registration fees
- Maintains data consistency with bidirectional mappings

## 🧪 Testing
- All functions tested and validated
- Error handling implemented
- Edge cases covered

This MVP provides a solid foundation for a name registry system and demonstrates key Clarity programming concepts including map storage, payment processing, and access control.
