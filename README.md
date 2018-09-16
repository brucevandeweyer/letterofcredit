# letterofcredit
*Prototype of Letter of Credit system - Contract maintainability in Solidity*

## How does it work?

The Letter of Credit prototype is build around the CMC ***Doug***. All contracts use ***Doug*** to get the adresses of the other contracts and to validate the calls of the contracts. ***LoC*** is the ALC contract that communicates with the Controller Contracts ***Users***, ***Letters*** and ***Payments***. All other calls are denieded by the Controller Contracts. The Controller Contracts in turn communicate with the Database Contracts ***UsersDb***, ***LettersDb*** and ***PaymentsDb***. All other calls are denieded by the Database Contracts.

**Structure of the contracts**
![alt text](https://github.com/brucevandeweyer/letterofcredit/blob/master/structure.png)

## Content

- loc.sol: Solidity file that contains all the contracts
- epm.yaml: Happy path script
