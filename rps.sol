 // SPDX-License-Identifier: GPL-3.0
 pragma solidity ^0.8.4;
 
 contract RPS{
     address owner;
     mapping(string => mapping(string => string)) winningCombination;
     struct Game{
         uint256 player1PlayedTime;
         uint256 player2PlayedTime;
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
     
     modifier isGameOpen(string calldata name){
         require(games[name].player2 == address(0), "Game already full");
         _;
     }
     
     modifier playerInGame(string calldata name){
         require(games[name].player1 != msg.sender || games[name].player2 != msg.sender, "You already joined the game");
         _;
     }
     
     modifier playerHasAccess(string calldata name){
         require(games[name].player1 != msg.sender || games[name].player2 != msg.sender, "You cannot play this game because you were not registered to play");
         _;
     }
     
     modifier findExistingGame(string calldata name){
         require(keccak256(bytes(games[name].name)) == keccak256(bytes(name)) && games[name].isActive == false, 'Game does not exist or completed');
         _;
     }
     
     event Created(string indexed name, uint256  leastStakeAbleAmount, address indexed player);
     event Registered(string indexed name, uint256  leastStakeAbleAmount, address indexed player);
     event Played(string indexed name, string indexed hand, address indexed player);
     event Drawn(string indexed name, address indexed player1, address indexed player2);
     event Won(string indexed name, address indexed player, uint256 amountWon);
     event Paid(string indexed name, address indexed player, uint256 amountWon);
     event Withdrawn(uint256 amount, address indexed player);
     event Cancelled(string indexed name, address indexed player, uint256 cancelledAt);
     
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
     
     function newGame(string calldata name) external payable playerInGame(name) returns(bool){
        require(games[name].player1 == address(0), "This game already exists");
        require(msg.value != 0, "Please add a wager value");
        games[name] = Game({name:name, player1:msg.sender, player2:address(0), player1PlayedTime:0, player2PlayedTime:0, player1Score:0, player2Score:0, 
                            player1CurrentHand:'', player2CurrentHand:'', winner:address(0), earningCleared:false, isActive:true, totalPlays:0, totalStake:msg.value,
                            leastStakeAbleAmount:msg.value}) ;
 
        emit Created(name, msg.value, msg.sender);
        
        return true;
     }
     
     function getGame(string calldata name) external view findExistingGame(name) playerInGame(name) returns(Game memory){
        return games[name];
     }
    
     function joinGame(string calldata name) external payable findExistingGame(name) playerInGame(name) isGameOpen(name) returns(bool){
        require(games[name].leastStakeAbleAmount == msg.value, 
        string(abi.encodePacked("The money you staked is below or above minimum stake-able amount which is"," ","games[name].leastStakeAbleAmount"))
        );
        games[name].player2 = msg.sender;
        games[name].totalStake += msg.value;
        emit Registered(name, msg.value, msg.sender);
        return true;
     }
     
     function play(string calldata name, string calldata handPlayed) external findExistingGame(name) playerHasAccess(name) returns(string memory){
        Game storage game = games[name];
        
        require(game.player2 != address(0), "Waiting for Player 2 to join");
        
        require(hands[handPlayed] != 0, "Invalid hand played. Options: rock, scissors and paper");

        if(game.player1 == msg.sender && game.player1PlayedTime > game.player2PlayedTime){
            return "Waiting for player 2 to play";
        }
        
        if(game.player2 == msg.sender && game.player2PlayedTime > game.player1PlayedTime){
            return "Waiting for player 1 to play";
        }
         
        if(game.player1 == msg.sender){
            game.player1CurrentHand = handPlayed;
            game.player1PlayedTime = block.timestamp;
        }
        
        if(game.player2 == msg.sender){
            game.player2CurrentHand = handPlayed;
            game.player2PlayedTime = block.timestamp;
        }
         
         if(game.player2 == msg.sender){
             if(keccak256(bytes(game.player1CurrentHand)).length > 0){
                computePlay(game);
                game.player1CurrentHand = '';
                game.player2CurrentHand = '';
                game.totalPlays++;
             }
             
             if(game.totalPlays == 6){
                 emit Played(name, handPlayed, msg.sender);
                 updateEarningAndCloseGame(game);
                 return "Game over, winner total earning updated";
             }
         }
         
        emit Played(name, handPlayed, msg.sender);
        
        return "You have played your hand";
     }
  
     function computePlay(Game storage game) internal{
        
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
     
     function result(string calldata name) external view returns(uint256 player1Score, uint256 player2Score){
          player1Score = games[name].player1Score;
          player2Score = games[name].player2Score;
     }
     
     
     function updateEarningAndCloseGame(Game storage game) internal{
         if(game.player1Score == game.player2Score){
              totalEarning[game.player1] += game.leastStakeAbleAmount;
              totalEarning[game.player1] += game.leastStakeAbleAmount;
              emit Drawn(game.name, game.player1, game.player2);
          }else if(game.player1Score > game.player2Score){
               game.winner = game.player1;
          }else{
               game.winner = game.player2;
          }
          
          totalEarning[game.winner] += game.totalStake;
          game.earningCleared = true;
          game.isActive = false;
          emit Won(game.name, game.winner, game.totalStake);
     }
     
     function totalEarnings() external view returns(uint256){
          return totalEarning[msg.sender];
     }
     
     function withdraw(uint256 amount) external payable returns(string memory){
          require(amount > 0, 'Minimum Withdrawal is 1');
          require(totalEarning[msg.sender] >= amount, 'Sorry you cannot withdraw above your total earnings');
          totalEarning[msg.sender] -= amount;
          bool isSent = payable(msg.sender).send(amount);
          
          if(! isSent){
              revert('Withdrawal failed');
          }
          
          emit Withdrawn(amount, msg.sender);
          return "Withdrawal successful";
     }
     
    function cancel(string calldata name, uint256 cancelledAt) external findExistingGame(name) playerHasAccess(name) returns(string memory){
          Game storage game = games[name];
          
          address cancelledBy = msg.sender;
          
          if(game.player2 != address(0) && keccak256(bytes(game.player1CurrentHand)) != keccak256(bytes(''))){
              return "You cannot cancel this game, because player two already joined";
          }
          
          if(game.player1 == msg.sender){
              
          }
          game.isActive = false;
          emit Cancelled(name, cancelledBy, cancelledAt);
          
          return "Game was cancelled";
     }
 }
