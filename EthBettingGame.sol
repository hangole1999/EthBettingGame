pragma solidity ^0.4.24;

// ----------------------- Public Network Part -----------------------

contract EthBettingGame {
    
    // Variables
    EthBettingGameCore public privateNetwork;
    address public owner;
    
    // Mapping
    mapping(address => uint) public userIds;
    mapping(uint => address) public idUsers;
    mapping(uint => uint) public betAmount;
    
    // Constructor
    constructor() public {
        owner = msg.sender;
    }
    
    // Modifier
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    // Transfer Ownership
    function transferOwnership(address newOwner) public onlyOwner() {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
    
    // Events
    event _CallbackSetPlayer(uint userId, address msgSender);
    event SetPlayer(bytes32 _userName, bytes32 _comment, address msgSender);
    event Winner(bytes32 winnerName);
    
    // Getters
    function getUser(uint _id) public view returns(address) {
        return(idUsers[_id]);
    }
    
    function getOwner() public view returns(address) {
        return privateNetwork.owner();
    }
    
    // Setters
    function setprivateNetwork(address _address) public onlyOwner() {
        privateNetwork = EthBettingGameCore(_address);
    }
    
    // Public Interfaces
    function setPlayer(bytes32 _userName, bytes32 _comment) public payable {
        privateNetwork.setPlayer(_userName, _comment, msg.sender);
    }
    
    function setComment(bytes32 _comment) public {
        uint userId = userIds[msg.sender];
        privateNetwork.setComment(userId, _comment);
    }
    
    function bettingGame(uint _gameId, uint _betNumber) public payable {
        uint userId = userIds[msg.sender];
        betAmount[userId] = msg.value;
        privateNetwork.bettingGame(userId, _gameId, _betNumber);
    }
    
    // Callback Functions
    function _callbackSetPlayer(uint _userId, address _msgSender) public {
        userIds[_msgSender] = _userId;
        idUsers[_userId] = _msgSender;
        emit _CallbackSetPlayer(_userId, _msgSender);
    }
    
    function _callbackBettingGame(bool _result, uint _winnerId, bytes32 _winnerName) public payable {
        if(_result){
            emit Winner(_winnerName);
            idUsers[_winnerId].transfer(betAmount[_winnerId]*2);
        }
    }
    
}

// ----------------------- Private Network Part -----------------------

contract EthBettingGameCore {
    
    // Structures
    struct Player {
        uint playerId;
        bytes32 userName;
        bytes32 comment;
    }
    
    struct Game {
        uint gameId;
        mapping (uint => uint) playerIdM;
        mapping(uint => uint) betNumberM;
        uint playerCount;
        uint betNumberCount;
        uint256 randomNumber;
        uint gamePlayerLength;
    }
    
    struct GameHistory {
        uint date;
        bytes32 winner;
    }
    
    // Variables
    EthBettingGame internal publicNetwork;
    address public owner;
    
    mapping (uint => Player) public playerM;
    mapping (uint => Game) private gameM;
    mapping (uint => GameHistory) public gameHistoryM;
    
    uint private playerIdCount = 0;
    uint private gameIdCount = 0;
    uint private gameHistoryIdCount = 0;
    
    // Constructor
    constructor(address _address) public {
        owner = msg.sender;
        publicNetwork = EthBettingGame(_address);
    }
    
    // Modifier
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    // Transfer Ownership
    function transferOwnership(address newOwner) public onlyOwner() {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
    
    // Events
    event SetPlayer(bytes32 userName, bytes32 comment);
    event SetComment(bytes32 userName, bytes32 comment);
    event CreateGame(uint gameId);
    event BettingGame(uint gameId, bytes32 userName, uint betNumber);
    event Winner(uint gameId, bytes32 userName);
    
    // Interfaces
    function setPlayer(bytes32 _userName, bytes32 _comment, address _msgSender) public {
        playerIdCount++;
        
        playerM[playerIdCount] = Player({
            playerId: playerIdCount,
            userName: _userName,
            comment: _comment
        });
        
        emit SetPlayer(_userName, _comment);
        
        publicNetwork._callbackSetPlayer(playerIdCount, _msgSender);
    }
    
    function setComment(uint _playerId, bytes32 _comment) public returns (uint) {
        playerM[_playerId].comment = _comment;
        
        return(_playerId);
    }
    
    function bettingGame(uint _playerId, uint _gameId, uint _betNumber) public returns (bool, uint) {
        gameM[_gameId].playerCount++;
        
        gameM[_gameId].playerIdM[gameM[_gameId].playerCount] = _playerId;
        gameM[_gameId].betNumberM[_betNumber] = _playerId;
        
        bool result = false;
        uint winnerId = 0;
        
        if (gameM[_gameId].playerCount == gameM[_gameId].gamePlayerLength+1) {
            result = true;
            winnerId = finishGame(_gameId);
        } else {
            publicNetwork._callbackBettingGame(false, 0, 0x00);
        }
        
        return (result, winnerId);
    }
    
    function finishGame(uint _gameId) internal returns(uint) {
        uint winNumber = gameM[_gameId].randomNumber;
        uint winnerId = gameM[_gameId].betNumberM[winNumber];
        
        bytes32 winnerName = playerM[winnerId].userName;
        
        gameHistoryIdCount++;
        
        gameHistoryM[gameHistoryIdCount] = GameHistory({
            date: now,
            winner: winnerName
        });
        
        publicNetwork._callbackBettingGame(true, winnerId, winnerName);
        
        return (winnerId);
    }
    
    function createGame(uint gamePlayerLength) public onlyOwner() returns(uint) {
        gameIdCount++;
        
        uint gameId = gameIdCount;
        
        gameM[gameId] = Game({
            gameId: gameId,
            playerCount: 0,
            betNumberCount: 0,
            randomNumber: 0,
            gamePlayerLength: gamePlayerLength
        });
        
        gameM[gameId].randomNumber = uint(block.blockhash(block.number-1)) % gameM[gameId].gamePlayerLength + 1;
        
        emit CreateGame(gameId);
        
        return (gameId);
    }
    
}
