 // SPDX-License-Identifier: GPL-3.0
 pragma solidity ^0.8.4;
 
 contract RPS{
     address owner;
     mapping(string => mapping(string => string)) winningCombination;
     
     struct Game{
         string name;
         address player1;
         address player2;
         uint256 player1PlayedTime;
         uint256 player2PlayedTime;
         uint256 player1Score;
         uint256 player2Score;
         string player1Hand;
         string player2Hand;
         address winner;
         uint256 totalPlays;
         uint256 moneyStaked;
         uint256 leastStakeAble;
     }
     
     mapping(string => Game) games;
     
     mapping(string => uint256) hands;
     
     mapping(address => uint256) totalCredit;
     
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
         require(keccak256(bytes(games[name].name)) == keccak256(bytes(name)), 'Game does not exist');
         _;
     }
     
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
        games[name] = Game(name, msg.sender, address(0), 0, 0, 0, 0, '', '', address(0), 0, msg.value, msg.value) ;
        
        return true;
     }
     
     function getGame(string calldata name) external view findExistingGame(name) playerInGame(name) returns(Game memory){
        return games[name];
     }
    
     function joinGame(string calldata name) external payable findExistingGame(name) playerInGame(name) isGameOpen(name) returns(bool){
        require(games[name].leastStakeAble == msg.value, 'The money you staked is below or above minimum stake-able amount which is games[name].leastStakeAble');
        games[name].player2 = msg.sender;
        
        games[name].moneyStaked += msg.value;

        return true;
     }
     
     function play(string calldata name, string calldata handPlayed) public findExistingGame(name) playerHasAccess(name) returns(string memory){
        Game storage game = games[name];
        
        require(game.player2 != address(0), "Waiting for Player 2 to join");
        
        require(hands[handPlayed] != 0, "Invalid hand played. Options: rock, scissors and paper");

        if(game.player1 == msg.sender && game.player1PlayedTime > game.player2PlayedTime){
            return "Waiting for player 2 to play";
        }
        
        if(game.player2 == msg.sender && game.player2PlayedTime > game.player1PlayedTime){
            return "Waiting for player 1 to play";
        }
         
        require(game.totalPlays <= 5, "Game over");
        
        if(game.player1 == msg.sender){
            game.player1Hand = handPlayed;
            game.player1PlayedTime = block.timestamp;
        }
        
        if(game.player2 == msg.sender){
            game.player2Hand = handPlayed;
            game.player2PlayedTime = block.timestamp;
        }
         
         if(game.player2 == msg.sender){
             if(keccak256(bytes(game.player1Hand)).length > 0){
                computePlay(game);
                game.player1Hand = '';
                game.player2Hand = '';
             }
             
             if(game.totalPlays == 6){
                 creditWinner(game);
             }
         }

        return "You have played";
     }
  
     function computePlay(Game storage game) internal{
        
         if(keccak256(bytes(game.player1Hand)) == keccak256(bytes(game.player2Hand))){
            game.player1Score += 1;
            game.player2Score += 1;
         }else{
             string memory winningHand = winningCombination[game.player1Hand][game.player2Hand];
         
             if(keccak256(bytes(winningHand)) == keccak256(bytes(game.player1Hand))) {
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
     
     function winner(string memory name) public view returns(address){
          if(games[name].player1Score > games[name].player2Score){
              return games[name].player1;
          }
           return games[name].player2;
     }
     
     function creditWinner(Game storage game) internal{
          string memory gameName = game.name;
          address _winner = winner(gameName);
          totalCredit[_winner] += game.moneyStaked;
     }
     
     function totalCredits() external view returns(uint256){
          return totalCredit[msg.sender];
     }
 }
