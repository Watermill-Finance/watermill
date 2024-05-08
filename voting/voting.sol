// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable, ReentrancyGuard{
    using SafeERC20 for IERC20;

    IERC20 immutable public vWAT;

    uint public counter = 0;

    struct Ballot {
        string question;
        string[] options;
        uint startTime;
        uint duration;
    }

    mapping(uint => Ballot) private _ballots;
    mapping(uint => mapping(uint => uint)) private _tally;
    mapping(uint => mapping(address => bool)) public hasVoted;

    constructor(address _vWAT){
        vWAT = IERC20(_vWAT);
    }

    function createBallot(
        string memory question_,
        string[] memory options_,
        uint startTime_,
        uint duration_
    ) external onlyOwner nonReentrant {
        require(duration_ > 0, "Duration must be greater than 0");
        require(
            startTime_ > block.timestamp,
            "Start time must be in the future"
        );
        require(options_.length >= 2, "Provide at minimum two options");
        _ballots[counter] = Ballot(question_, options_, startTime_, duration_);
        counter++;
    }

    function getBallotByIndex(
        uint index_
    ) external view returns (Ballot memory ballot) {
        ballot = _ballots[index_];
    }

    function vote(uint ballotIndex_, uint optionIndex_, uint amount) external nonReentrant {
        require(
            !hasVoted[ballotIndex_][msg.sender],
            "Address already casted a vote for ballot"
        );
        Ballot memory ballot = _ballots[ballotIndex_];
        require(
            block.timestamp >= ballot.startTime,
            "Can't cast before start time"
        );
        require(
            block.timestamp < ballot.startTime + ballot.duration,
            "Can't cast after end time"
        );

        vWAT.safeTransferFrom(msg.sender, address(this), amount);

        _tally[ballotIndex_][optionIndex_] += amount;
        hasVoted[ballotIndex_][msg.sender] = true;
    }

    function getTally(
        uint ballotIndex_,
        uint optionIndex_
    ) external view returns (uint) {
        return _tally[ballotIndex_][optionIndex_];
    }

    function results(uint ballotIndex_) external view returns (uint[] memory) {
        Ballot memory ballot = _ballots[ballotIndex_];
        uint len = ballot.options.length;
        uint[] memory result = new uint[](len);
        for (uint i = 0; i < len; i++) {
            result[i] = _tally[ballotIndex_][i];
        }
        return result;
    }

    function winners(uint ballotIndex_) external view returns (bool[] memory) {
        Ballot memory ballot = _ballots[ballotIndex_];
        uint len = ballot.options.length;
        uint[] memory result = new uint[](len);
        uint max;
        for (uint i = 0; i < len; i++) {
            result[i] = _tally[ballotIndex_][i];
            if (result[i] > max) {
                max = result[i];
            }
        }
        bool[] memory winner = new bool[](len);
        for (uint i = 0; i < len; i++) {
            if (result[i] == max) {
                winner[i] = true;
            }
        }
        return winner;
    }
}