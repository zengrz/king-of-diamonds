// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <=0.8.17;

library Util {
    function udiv(uint numerator, uint denominator, bool round)
        public
        pure
        returns (uint)
    {
        return numerator/denominator + (round ? ((numerator % denominator) * 2 > denominator ? 1 : 0) : 0);
    }

    function dist(uint a, uint b)
        public
        pure
        returns (uint)
    {
        return a > b ? a-b : b-a;
    }
    
    function indexOf(address[] memory self, address target)
        public
        pure
        returns (int256)
    {
        for (uint256 idx; idx < self.length; idx++) {
            if (self[idx] == target) {
                return int256(idx);
            }
        }

        return -1;
    }

    function contains(address[] memory self, address addr)
        public
        pure
        returns (bool)
    {
        return indexOf(self, addr) != -1;
    }

    function count(int256[] memory self, int256 target)
        public
        pure
        returns (uint256)
    {
        uint256 targetCount;
        for (uint256 idx; idx < self.length; idx++) {
            if (self[idx] == target) {
                targetCount++;
            }
        }

        return targetCount;
    }

    function sum(int256[] memory self)
        public
        pure
        returns (int256)
    {
        int256 arraySum;
        for (uint256 idx; idx < self.length; idx++) {
            arraySum += self[idx];
        }

        return arraySum;
    }

    function isEmpty(string memory s)
        public
        pure
        returns (bool)
    {
        return bytes(s).length == 0;
    }
}

interface Game {
    event PlayerNeutralized(address indexed _from, uint lives);
    event PlayerActivated(address indexed _from);

    // player
    function join() external payable;
    function quit() external;

    // game
    function startGame() external;
    function startNewRound() external;
    function getRoundAnswer() external view returns (uint);
    function getRoundWinners() external view returns (address[] memory);
    function endRound() external;
    function endGame() external;
}

abstract contract KingOfDiamondsBase {
    struct Player {
        // general info
        address addr;
        string name;
        uint256 unclaimedReward;

        // game status
        bool active;
        uint idx; // 0-activePlayers.length
        uint lives; // 0-10

        // round status
        bool submitted;
        uint guess; // 0-100
    }

    address owner;

    mapping(address => Player) players;

    /* game */
    bool gameStarted;
    address[] activePlayers;

    /* round */
    bool roundStarted;
    uint numSubmitted;

    /* events */
    modifier isValidGuess(uint guess) {
        require(guess >= 0 && guess <= 100, "guess must be 0-100 inclusive");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not owner");
        _;
    }

    /* player */
    modifier playerExists {
        require(players[msg.sender].addr != address(0), "create player first");
        _;
    }

    modifier playerActive {
        require(players[msg.sender].active, "player is not currently in the game");
        _;
    }

    modifier playerNotActive {
        require(!players[msg.sender].active, "player already joined the game");
        _;
    }

    modifier playerNotSubmitted {
        require(!players[msg.sender].submitted, "player has already submitted a response for the round");
        _;
    }

    /* round */
    modifier roundInProgress {
        require(gameStarted, "game has not started");
        require(roundStarted, "round has not started");
        _;
    }

    modifier roundNotInProgress {
        require(!roundStarted, "round is in progress");
        _;
    }

    /* game */
    modifier gameInProgress {
        require(gameStarted, "game has not started");
        _;
    }

    modifier gameNotInProgress {
        require(!gameStarted, "game is in progress");
        _;
    }

    modifier canEndRound {
        require(roundStarted, "round has not started");
        require(numSubmitted == activePlayers.length, "some players have not submitted their guesses");
        _;
    }
}

contract KingOfDiamonds is KingOfDiamondsBase, Game {
    uint256 constant wager = 1 ether;

    uint256 totalReward;
    uint256 sumOfGuesses;
    // uint256 roundCloseTime;

    constructor() {
        owner = msg.sender;
        createPlayer("zero");
    }

    using Util for string;
    function createPlayer(string memory name) public {
        require(!name.isEmpty(), "name cannot be empty");

        players[msg.sender] = Player(msg.sender, name, 0, false, 0, 0, false, 0);
    }

    function resetPlayerRoundState(address playerAddr) private {
        players[playerAddr].submitted = false;
        players[playerAddr].guess = 101;
    }

    function activatePlayer(address playerAddr) private onlyOwner {
        players[playerAddr].active = true;
        players[playerAddr].idx = activePlayers.length;
        players[playerAddr].lives = 10;
        resetPlayerRoundState(playerAddr);

        activePlayers.push(playerAddr);
    }

    function deactivatePlayer(address playerAddr) private onlyOwner {
        uint idxToRemove = players[playerAddr].idx;
        players[playerAddr].active = false;

        players[activePlayers[activePlayers.length-1]].idx = idxToRemove; // update last active player index to removed index

        activePlayers[idxToRemove] = activePlayers[activePlayers.length-1]; // move last active player to removed player
        activePlayers.pop(); // remove last active player
    }

    function join() external payable override playerExists playerNotActive {
        require(msg.value == wager, "wager must be 1 ether");

        activatePlayer(msg.sender);
        emit PlayerActivated(msg.sender);

        totalReward += msg.value;
    }

    function quit() external override playerExists playerActive {
        deactivatePlayer(msg.sender);

        emit PlayerNeutralized(msg.sender, players[msg.sender].lives);
    }

    function startNewRound() public override onlyOwner roundNotInProgress {
        roundStarted = true;
    }

    function submit(uint n) external roundInProgress playerActive playerNotSubmitted isValidGuess(n) {
        // require(block.timestamp <= closeTime, "late submission");

        players[msg.sender].submitted = true;
        players[msg.sender].guess = n;
        sumOfGuesses += n;
        ++numSubmitted;
    }

    function getRoundAnswer() public view override canEndRound returns (uint) {
        return Util.udiv(sumOfGuesses*4, activePlayers.length*5, true); // needs to be random
    }

    function getRoundWinners() public view override canEndRound returns (address[] memory) {
        uint ans = getRoundAnswer();
        uint minDist = 100;
        uint numWinners;

        uint[] memory distFromAns = new uint[](activePlayers.length);

        for (uint i = 0; i < activePlayers.length; ++i) {
            distFromAns[i] = Util.dist(players[activePlayers[i]].guess, ans);
            if (minDist > distFromAns[i]) {
                minDist = distFromAns[i];
                numWinners = 1;
            } else if (minDist == distFromAns[i]) {
                ++numWinners;
            }
        }

        address[] memory winners = new address[](numWinners);

        uint j = 0;
        for (uint i = 0; i < distFromAns.length; ++i) {
            if (distFromAns[i] == minDist) {
                winners[j++] = activePlayers[i];
            }
        }

        return winners;
    }

    function updateLosers(address[] memory winners) private {
        bool[] memory toRemove = new bool[](activePlayers.length);

        for (uint i = 0; i < activePlayers.length; ++i) {
            address activePlayerAddr = activePlayers[i];
            if (!winners.contains(activePlayerAddr)) {
                --players[activePlayerAddr].lives;
                if (players[activePlayerAddr].lives == 0) {
                    toRemove[i] = true;
                    emit PlayerNeutralized(msg.sender, players[msg.sender].lives);
                }
            }
        }
    }

    function updatePlayers() private {
        address[] memory winners = getRoundWinners();
        updateLosers(winners);
    }

    function resetPlayerRoundStates() private {
        for (uint i = 0; i < activePlayers.length; ++i) {
            resetPlayerRoundState(activePlayers[i]);
        }
    }

    function resetGameRoundState() private {
        sumOfGuesses = 0;
        numSubmitted = 0;

        roundStarted = false;
    }

    using Util for address[];
    function endRound() public override onlyOwner canEndRound {
        updatePlayers(); // fix remove
        resetPlayerRoundStates();
        resetGameRoundState();
    }

    function GetSumOfPlayersLivesLeft() private view returns (uint256) {
        uint256 totalLives = 0;
        for (uint i = 0; i < activePlayers.length; ++i) {
            totalLives += players[activePlayers[i]].lives;
        }
        return totalLives;
    }

    function GetPlayerReward(uint256 totalPlayerReward, uint256 totalPlayersLives) private view returns (uint256) {
        require(players[msg.sender].lives <= totalPlayersLives, "lives is wrong");
        require(totalPlayerReward <= totalReward*4/5, "reward is wrong");

        return totalPlayerReward * players[msg.sender].lives/totalPlayersLives;
        // return totalPlayerReward / activePlayers.length;
    }

    function startGame() public override onlyOwner gameNotInProgress {
        gameStarted = true;
    }

    function endGame() public override onlyOwner gameInProgress roundNotInProgress {
        uint256 totalPlayerReward = 0;
        for (uint i = 0; i < activePlayers.length; ++i) {
            uint256 playerReward = GetPlayerReward(totalReward*4/5, GetSumOfPlayersLivesLeft());
            players[activePlayers[i]].unclaimedReward = playerReward;
            totalPlayerReward += playerReward;
        }

        players[owner].unclaimedReward = totalReward - totalPlayerReward;

        totalReward = 0;
    }

    function withdraw() public {
        uint256 amt = players[msg.sender].unclaimedReward;
        players[msg.sender].unclaimedReward = 0;
        (bool sent, ) = payable(msg.sender).call{value: amt}("");
        require(sent, "withdraw failed");
    }

    function terminateContract() public onlyOwner {
        selfdestruct(payable(owner));
    }
}