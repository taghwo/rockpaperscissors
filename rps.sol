 // SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Strings.sol";

 contract RPS{
     address owner;
     mapping(string => mapping(string => string)) winningCombination;

     struct Game{
         uint256 player1CurrentRound;
         uint256 player2CurrentRound;
         uint256 player1Score;
         uint256 player2Score;
         uint256 totalPlays;
         uint256 totalStake;
         uint256 leastStakeAbleAmount;
         address player1;
         address player2;
         address winner;
         string name;
         string player1CurrentHand;
         string player2CurrentHand;
         bool earningCleared;
         bool isActive;
     }
     
     mapping(string => Game) games;
     
     mapping(string => uint256) hands;
     
     mapping(address => uint256) totalEarning;
    
     modifier UnauthorizedAccess(string calldata name){
         require(games[name].player1 == msg.sender || games[name].player2 == msg.sender, "Not eligible to play this game");
         _;
     }
     
     modifier ExistingActiveGame(string calldata name){
         require(keccak256(bytes(games[name].name)) == keccak256(bytes(name)) && games[name].isActive == true, 'Game does not exist or completed');
         _;
     }
     
     event Created(string indexed name, uint256  leastStakeAbleAmount, address indexed player);
     event Registered(string indexed name, uint256  leastStakeAbleAmount, address indexed player);
     event Played(string indexed name, string indexed hand, address indexed player);
     event Drew(string indexed name, address indexed player1, address indexed player2);
     event Won(string indexed name, address indexed player, uint256 amountWon);
     event Paid(string indexed name, address indexed player, uint256 amountWon);
     event Withdrew(uint256 amount, address indexed player);
     event Cancelled(string indexed name, address indexed player, uint256 cancelledAt);
     
     ///Initiliaze attributes
     constructor(){
         owner = msg.sender;
         hands['rock'] = 1;
         hands['paper'] = 2;
         hands['scissors'] = 3;
         
         winningCombination['rock']['paper'] = 'paper';
         winningCombination['paper']['rock'] = 'paper';
         winningCombination['rock']['scissors'] = 'rock';
         winningCombination['scissors']['rock'] = 'rock';
         winningCombination['scissors']['paper'] = 'scissors';
         winningCombination['paper']['scissors'] = 'scissors';
     }
     
     /// @dev Create new game and set msg.sender as player1
     /// @param name of Game
     function create(string calldata name) external payable{
        require(keccak256(bytes(games[name].name)) != keccak256(bytes(name)), "This game already exists");
        require(msg.value != 0, "Please add a wager value");
        
        games[name].name = name;  
        games[name].player1 = msg.sender;               
        games[name].player2 = address(0);
        games[name].player1CurrentRound = 0;
        games[name].player2CurrentRound = 0;
        games[name].player1Score = 0;
        games[name].player2Score = 0;
        games[name].player1CurrentHand = '';
        games[name].player2CurrentHand = '';
        games[name].winner = address(0);
        games[name].earningCleared = false;
        games[name].isActive = true;
        games[name].totalPlays = 0;
        games[name].totalStake = msg.value;
        games[name].leastStakeAbleAmount = msg.value;

        emit Created(name, msg.value, msg.sender);
     }
     
     /// @dev handles cancelling and refunds
     /// @param name of Game
     function getGame(string calldata name) external view ExistingActiveGame(name) UnauthorizedAccess(name) returns(Game memory){
        return games[name];
     }
    
     /// @dev Register new player to game
     /// @param name of Game
     function join(string calldata name) external payable ExistingActiveGame(name){
        require(games[name].player2 == address(0), "Game is full");
        require(games[name].player1 != msg.sender, "You are in this game already");
        require(games[name].player2 != msg.sender, "You are in this game already");
        string memory leastAmount = Strings.toString(games[name].leastStakeAbleAmount);
        require(games[name].leastStakeAbleAmount == msg.value,
        string(abi.encodePacked("The value you staked is below or above minimum stake-able amount which is ", leastAmount))
        );

        games[name].player2 = msg.sender;
        games[name].totalStake += msg.value;
        
        emit Registered(name, msg.value, msg.sender);
     }
     
     /// @dev Play game. Game rounds starts with player 
     /// @param name of Game
     /// @param handPlayed based on hands
     function play(string calldata name, string calldata handPlayed) external ExistingActiveGame(name) UnauthorizedAccess(name){
        Game storage game = games[name];
        
        require(game.player2 != address(0), "Waiting for Player 2 to join");
        require(hands[handPlayed] != 0, "Invalid hand played. Options: rock, scissors and paper");

        if(game.player1 == msg.sender && game.player1CurrentRound > game.player2CurrentRound){
            revert("Waiting for player 2 to play");
        }
        
        if(game.player2 == msg.sender && game.player2CurrentRound > game.player1CurrentRound){
            revert("Waiting for player 1 to play");
        }
         
        if(game.player1 == msg.sender){
            game.player1CurrentHand = handPlayed;
            game.player1CurrentRound += 1 ;
        }
        
        if(game.player2 == msg.sender){
            game.player2CurrentHand = handPlayed;
            game.player2CurrentRound += 1 ;
        }
        
         game.totalPlays++;
         
         if(game.player2 == msg.sender && keccak256(bytes(game.player1CurrentHand)).length > 0){
                computeRound(game);
                game.player1CurrentHand = '';
                game.player2CurrentHand = '';
         }
         
         if(game.totalPlays == 6){
            updateEarningAndCloseGame(game);
         }
         
         emit Played(name, handPlayed, msg.sender);
     }
     
     /// @dev Compute score for round played
     /// @param game instance of Game
     function computeRound(Game storage game) internal{
        
         if(keccak256(bytes(game.player1CurrentHand)) == keccak256(bytes(game.player2CurrentHand))){
            game.player1Score += 1;
            game.player2Score += 1;
         }else{
             string memory winningHand = winningCombination[game.player1CurrentHand][game.player2CurrentHand];
         
             if(keccak256(bytes(winningHand)) == keccak256(bytes(game.player1CurrentHand))) {
                game.player1Score += 1;
             }else{
                game.player2Score += 1;
             }
         }
     } 
     
     /// @dev fetch score of player1Score and player2Score
     /// @param name of Game
     /// @return player1Score and player2Score 
     function result(string calldata name) external view returns(uint256 player1Score, uint256 player2Score){
          player1Score = games[name].player1Score;
          player2Score = games[name].player2Score;
     }
     
     /// @dev Update earnings and close game
     /// @param game instance OF Game
     function updateEarningAndCloseGame(Game storage game) internal{
         if(game.player1Score == game.player2Score){
              totalEarning[game.player1] += game.leastStakeAbleAmount;
              totalEarning[game.player1] += game.leastStakeAbleAmount;
              
              emit Drew(game.name, game.player1, game.player2);
          }else if(game.player1Score > game.player2Score){
               game.winner = game.player1;
               totalEarning[game.winner] += game.totalStake;
          }else{
               game.winner = game.player2;
               totalEarning[game.winner] += game.totalStake;
          }
          
          game.earningCleared = true;
          game.isActive = false;
          
          emit Won(game.name, game.winner, game.totalStake);
     }
     
     /// @dev Fetch total earning for an address
     /// @return uint256 totalEarnings
     function totalEarnings() external view returns(uint256){
          return totalEarning[msg.sender];
     }
     
     /// @dev Initiliaze withdrawal from totalEarning based on address 
     /// @param amount TO withdraw
     function withdraw(uint256 amount) external payable{
          require(amount > 0, 'Minimum Withdrawal is 1');
          require(totalEarning[msg.sender] >= amount, 'Insufficient funds');
         
          totalEarning[msg.sender] -= amount;
          
          bool isSent = payable(msg.sender).send(amount);
          
          if(! isSent){
              revert('Withdrawal failed');
          }
          
          emit Withdrew(amount, msg.sender);
     }
     
     /// @dev Cancel and refund handler
     /// @param name of Game
     /// @param cancelledAt time in seconds
     function cancel(string calldata name, uint256 cancelledAt) external ExistingActiveGame(name) UnauthorizedAccess(name){
          Game storage game = games[name];
          address cancelledBy = msg.sender;
          
          if(game.player2 != address(0) && keccak256(bytes(game.player1CurrentHand)) != keccak256(bytes(''))){
              revert("You cannot cancel this game, because player two already joined");
          }
          
          if(game.player2 != address(0)){
              totalEarning[game.player1] += game.leastStakeAbleAmount;
              totalEarning[game.player2] += game.leastStakeAbleAmount;
          }else{
              totalEarning[game.player1] += game.leastStakeAbleAmount;
          }
          
          game.isActive = false;
          
          emit Cancelled(name, cancelledBy, cancelledAt);
     }
 }
