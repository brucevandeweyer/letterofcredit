pragma solidity ^0.4.0;

//----- DougEnabled - Base class for contacting Doug

contract DougEnabled {
    address internal DOUG;

    // Set Doug address and don't allow to be set again, unless by Doug itself.
    function setDougAddress(address dougAddr) public returns (bool result){
        if(DOUG != 0x0 && msg.sender != DOUG){
            return false;
        } else {
            DOUG = dougAddr;
            return true;
        }
    }

    // Makes it so that Doug is the only contract that may kill it.
    function remove() public{
        if(msg.sender == DOUG){
            selfdestruct(DOUG);
        }
    }
}

//----- Doug CMC - Store contracts and handles contract requests

contract Doug {

    address owner;

    // This is where we keep all the contracts.
    mapping (bytes32 => address) public contracts;

    modifier onlyOwner { //a modifier to reduce code replication
        if (msg.sender == owner) // this ensures that only the owner can access the function
            _;
    }
    
    // Constructor
    constructor() internal{
        owner = msg.sender;
    }

    // Add a new contract to Doug. This will overwrite an existing contract.
    function addContract(bytes32 name, address addr) public onlyOwner returns (bool result) {
        DougEnabled de = DougEnabled(addr);
        // Don't add the contract if this does not work.
        if(!de.setDougAddress(address(this))) {
            return false;
        } else {
            contracts[name] = addr;
            return true;
        }
    }

    // Check current contract address
    function checkContract (bytes32 name) public onlyOwner view returns (address addr) {
        addr = contracts[name];
        return addr;
    }
      
    // Remove a contract from Doug. We could also selfdestruct if we want to.
    function removeContract(bytes32 name) public onlyOwner returns (bool result) {
        if (contracts[name] == 0x0){
            return false;
        }
        contracts[name] = 0x0;
        return true;
    }

    function remove() public onlyOwner {
        address loc = contracts["loc"];
        address users = contracts["users"];
        address usersdb = contracts["usersdb"];
        address letters = contracts["letters"];
        address lettersdb = contracts["lettersdb"];
        address payments = contracts["payments"];
        address paymentsdb = contracts["paymentsdb"];

        // Remove everything.
        if(loc != 0x0){DougEnabled(loc).remove();}
        if(users != 0x0){DougEnabled(users).remove();}
        if(usersdb != 0x0){DougEnabled(usersdb).remove();}
        if(letters != 0x0){DougEnabled(letters).remove();}
        if(lettersdb != 0x0){DougEnabled(lettersdb).remove();}
        if(payments != 0x0){DougEnabled(letters).remove();}
        if(paymentsdb != 0x0){DougEnabled(lettersdb).remove();}

        // Finally, remove doug. Doug will now have all the funds of the other contracts,
        // and when suiciding it will all go to the owner.
        selfdestruct(owner);
    }
}

//----- ContractProvider - Handles contract requests from Doug

contract ContractProvider {
    function contracts(bytes32 name) public returns (address addr) {}
}

//----- ContractEnabled - Handles correct dataflows

contract ContractEnabled is DougEnabled {

    // Checks if LoC is caller
    function isLoC() public view returns (bool) {
        if(DOUG != 0x0){
            address loc = ContractProvider(DOUG).contracts("loc");
            return msg.sender == loc;
        } else {
            return false;
        }
    }
    
    // Checks if Users is caller
    function isUsers() public view returns (bool) {
        if(DOUG != 0x0){
            address users = ContractProvider(DOUG).contracts("users");
            return msg.sender == users;
        } else {
            return false;
        }
    }
    
    // Checks if Letters is caller
    function isLetters() public view returns (bool) {
        if(DOUG != 0x0){
            address letters = ContractProvider(DOUG).contracts("letters");
            return msg.sender == letters;
        } else {
            return false;
        }
    }
    
    // Checks if Payments is caller
    function isPayments() public view returns (bool) {
        if(DOUG != 0x0){
            address payments = ContractProvider(DOUG).contracts("payments");
            return msg.sender == payments;
        } else {
            return false;
        }
    }
}

//----- UsersDb - Stores all users

contract UsersDb is ContractEnabled {
    
    mapping(address => uint8) public users;

    // Register new user
    function addUser(address addr, uint8 perm) public returns (bool res) {
        if(!isUsers()){
            return false;
        } else {
            address usersAddr = ContractProvider(DOUG).contracts("users");
            if (msg.sender == usersAddr){
                users[addr] = perm;
                return true;
            } else {
                return false;
            }
        }
    }
}

//---- Users - Handles all user operations

contract Users is ContractEnabled {

    // Register new user
    function addUser(address addr, uint8 perm) public returns (bool res) {
        if (!isLoC()){
            return false;
        } else {
            address usersDbAddr = ContractProvider(DOUG).contracts("usersdb");
            if (usersDbAddr == 0x0 ) {
                return false;
            } else {
                return UsersDb(usersDbAddr).addUser(addr, perm);
            }
        }
    }
}

//----- LettersDb - Stores all letters

contract LettersDb is ContractEnabled {
    
    struct LettersData {
        uint256 letterId;
        address buyer;
        address buyerBank;
        address seller;
        address sellerBank;
        uint amount;
        bytes32 reference;
        //letterStatus: 0 = new, 1 = reference received and order send, 2 = order delivered and ready to pay, 3 = payment pending, 4 = payment complete
        uint8 letterStatus;
    }
    
    uint256 nextLetterId;
    mapping(uint256 => LettersData) public letters;
    
    // Register new letter
    function addLetter (address buyer, address buyerBank, address seller, address sellerBank, uint amount) public returns (bool res) {
        if(!isLetters()){
            return false;
        } else {
            LettersData storage letter = letters[nextLetterId];
            letter.letterId = nextLetterId;
            letter.buyer = buyer;
            letter.buyerBank = buyerBank;
            letter.seller = seller;
            letter.sellerBank = sellerBank;
            letter.amount = amount;
            letter.reference = 0;
            letter.letterStatus = 0;
            nextLetterId++;
            return true;
        }
    }

    
    // Set letter reference - Check status and if request is being done by seller
    function setReference (uint256 id, bytes32 reference, address request) public returns (bool res) {
        if(!isLetters()){
            return false;
        } else {
            if (letters[id].letterStatus == 0 && letters[id].seller == request){
                letters[id].reference = reference;
                letters[id].letterStatus = 1;
                return true;
            } else {
                return false;
            }
        }
    }
    
    // Confirm delivery - Check status, if references match and if confirmation is being done by buyer
    function confirmDelivery (uint256 id, bytes32 reference, address request) public returns (bool res) {
        if(!isLetters()){
            return false;
        } else {
            if (letters[id].letterStatus == 1 && letters[id].reference == reference && letters[id].buyer == request){
                letters[id].letterStatus = 2;
                return true;
            } else {
                return false;
            }
        }
    }
    
    // Send payment - Checks status, if payment request is being made by buyerBank and send information back LoC
    function getPayment (uint256 id, address request) public returns (bool res) {
        if(!isLetters()){
            return false;
        } else {
            if (letters[id].letterStatus == 2 && letters[id].buyerBank == request){
                letters[id].letterStatus = 3;
                address buyerBank = request;
                address sellerBank = letters[id].sellerBank;
                address locAddr = ContractProvider(DOUG).contracts("loc");
                uint256 amount = letters[id].amount;
                return LoC(locAddr).completePayment(id, buyerBank, sellerBank, amount);
            } else {
                return false;
            }
        }    
    }
    
    function closeLetter (uint256 id) public returns (bool res) {
        if(!isLetters()){
            return false;
        } else {
            if (letters[id].letterStatus == 3){
                letters[id].letterStatus = 4;
                return true;
            } else {
                return false;
            }
        }
    }
    
    // FOR TESTING ONLY!! REMOVE LATER!!
    function checkStatus (uint256 id) public view returns (uint8 status){
        status = letters[id].letterStatus;
        return status;
    }
}

//----- Letters - Handles all letter operations

contract Letters is ContractEnabled {
    
     // Register new letter - send to LettersDb
    function addLetter (address buyer, address buyerBank, address seller, address sellerBank, uint amount, bytes32 reference) public returns (bool res) {
        address lettersDbAddr = ContractProvider(DOUG).contracts("lettersdb");
        if (!isLoC() || lettersDbAddr == 0x0){
            return false;
        } else {
            return LettersDb(lettersDbAddr).addLetter(buyer, buyerBank, seller, sellerBank, amount);
        }
    }
    
    // Set letter reference - send to LettersDb
    function setReference (uint256 id, bytes32 reference, address request) public returns (bool res){
        address lettersDbAddr = ContractProvider(DOUG).contracts("lettersdb");
        if (!isLoC() || lettersDbAddr == 0x0){
            return false;
        } else {
            return LettersDb(lettersDbAddr).setReference(id, reference, request);
        }
    }
    
    // Confirm delivery - send to LettersDb
    function confirmDelivery (uint256 id, bytes32 reference, address request) public returns (bool res){
        address lettersDbAddr = ContractProvider(DOUG).contracts("lettersdb");
        if (!isLoC() || lettersDbAddr == 0x0){
            return false;
        } else {
            return LettersDb(lettersDbAddr).confirmDelivery(id, reference, request);
        }
    }
    
    // Get payment - send to LettersDb
    function getPayment (uint256 id, address request) public returns (bool res){
        address lettersDbAddr = ContractProvider(DOUG).contracts("lettersdb");
        if (!isLoC() || lettersDbAddr == 0x0){
            return false;
        } else {
            return LettersDb(lettersDbAddr).getPayment(id, request);
        }
    }
    
    // Close letter - send to LettersDb
    function closeLetter (uint256 id) public returns (bool res){
        address lettersDbAddr = ContractProvider(DOUG).contracts("lettersdb");
        if (!isLoC() || lettersDbAddr == 0x0){
            return false;
        } else {
            return LettersDb(lettersDbAddr).closeLetter(id);
        }
    }
}

// ----- PaymentsDb - Stores balances

contract PaymentsDb is ContractEnabled {
    
    mapping (address => uint) public balances;

    // FOR TESTING ONLY!! REMOVE LATER!!
    function deposit() public payable returns (uint balance) {
        balances[msg.sender] += msg.value;
        balance = balances[msg.sender];
        return balance;
    }
    
    // FOR TESTING ONLY!! REMOVE LATER!!
    function checkBalance (address addr) public view returns (uint balance) {
        balance = balances[addr];
        return balance;
    }
    
    // Complete payment - Settle balances
    function completePayment (uint256 id, address buyerBank, address sellerBank, uint256 amount) public returns (bool rel) {
        if(!isPayments()){
            return false;
        } else {
            address locAddr = ContractProvider(DOUG).contracts("loc");
            balances[buyerBank] -= amount;
            balances[sellerBank] += amount;
            return LoC(locAddr).closeLetter(id);
        }
    }
}

//----- Payments - Handles all payment operations

contract Payments is ContractEnabled {
    
    
    // Complete payment - Check balances and send to PaymentsDb
    function completePayment (uint256 id, address buyerBank, address sellerBank, uint256 amount) public returns (bool rel) {
        address paymentsDbAddr = ContractProvider(DOUG).contracts("paymentsdb");
        if (!isLoC() || paymentsDbAddr == 0x0){
            return false;
        } else {
            if (PaymentsDb(paymentsDbAddr).balances(buyerBank) >= amount) {
                return PaymentsDb(paymentsDbAddr).completePayment(id, buyerBank, sellerBank, amount);
            } else {
                return false;
            }
        }
    }   
}
    
//----- Letter of Credit core (handles all contracts)

contract LoC is DougEnabled {

    // We still want an owner.
    address owner;

    // Constructor
    constructor(){
        owner = msg.sender;
    }

    // Register new user (owner LoC only) - send to Users
    function addUser(address addr, uint8 perm) public returns (bool res) {
        address usersAddr = ContractProvider(DOUG).contracts("users");
        if (msg.sender != owner || usersAddr == 0x0){
            return false;
        } else {
            return Users(usersAddr).addUser(addr, perm);
        }
    }
    
    // Register new letter - check permissions and send to Letters
    function addLetter (address buyer, address buyerBank, address seller, address sellerBank, uint amount, bytes32 reference) public returns (bool res) {
        address lettersAddr = ContractProvider(DOUG).contracts("letters");
        address usersDbAddr = ContractProvider(DOUG).contracts("usersdb");
        if (lettersAddr == 0x0 || usersDbAddr == 0x0) {
            return false;
        } else {
            if (UsersDb(usersDbAddr).users(msg.sender) >= 1) {
                return Letters(lettersAddr).addLetter(buyer, buyerBank, seller, sellerBank, amount, reference);
            } else {
                return false;
            }
        }
    }
    
    // Set letter reference - check permission and send with request address to Letters
    function setReference (uint256 id, bytes32 reference) public returns (bool res) {
        address lettersAddr = ContractProvider(DOUG).contracts("letters");
        address usersDbAddr = ContractProvider(DOUG).contracts("usersdb");
        if (lettersAddr == 0x0 || usersDbAddr == 0x0) {
            return false;
        } else {
            if (UsersDb(usersDbAddr).users(msg.sender) >= 1) {
                address request = msg.sender;
                return Letters(lettersAddr).setReference(id, reference, request);
            } else {
                return false;
            }
        }
    }
    
    // Confirm delivery - check permission and send with request address to Letters
    function confirmDelivery (uint256 id, bytes32 reference) public returns (bool res){
        address lettersAddr = ContractProvider(DOUG).contracts("letters");
        address usersDbAddr = ContractProvider(DOUG).contracts("usersdb");
        if (lettersAddr == 0x0 || usersDbAddr == 0x0) {
            return false;
        } else {
            if (UsersDb(usersDbAddr).users(msg.sender) >= 1) {
                address request = msg.sender;
                return Letters(lettersAddr).confirmDelivery(id, reference, request);
            } else {
                return false;
            }
        }
    }
    
    // Get payment information - check permission and send with request address to Letters
    function getPayment (uint256 id) public returns (bool res){
        address lettersAddr = ContractProvider(DOUG).contracts("letters");
        address usersDbAddr = ContractProvider(DOUG).contracts("usersdb");
        if (lettersAddr == 0x0 || usersDbAddr == 0x0) {
            return false;
        } else {
            if (UsersDb(usersDbAddr).users(msg.sender) >= 2) {
                address request = msg.sender;
                return Letters(lettersAddr).getPayment(id, request);
            } else {
                return false;
            }
        }
    }
    
    // Complete payment - check if lettersDb is requester and send to Payments
    function completePayment (uint256 id, address buyerBank, address sellerBank, uint256 amount) public returns (bool res){
        address lettersDbAddr = ContractProvider(DOUG).contracts("lettersdb");
        if (msg.sender != lettersDbAddr){
            return false;
        } else {
            address paymentsAddr = ContractProvider(DOUG).contracts("payments");
            return Payments(paymentsAddr).completePayment(id, buyerBank, sellerBank, amount);
        }
    }
    
    // Close letter - check if paymentsDb is caller and send to Letters
    function closeLetter (uint256 id) public returns (bool res){
        address paymentsDbAddr = ContractProvider(DOUG).contracts("paymentsdb");
        if (msg.sender != paymentsDbAddr){
            return false;
        } else {
            address lettersAddr = ContractProvider(DOUG).contracts("letters");
            return Letters(lettersAddr).closeLetter(id);
        }
    }
        
}