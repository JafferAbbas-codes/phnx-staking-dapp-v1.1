pragma solidity ^0.6.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DaoStakeContract is Ownable, Pausable {
    // Library for safely handling uint256
    using SafeMath for uint256;

    address public phnxContractAddress;

    uint256 ONE_DAY;
    uint256 public stakeDays;
    uint256 public maxStakedQuantity;
    uint256 public ratio;
    uint256 public totalStakedTokens;

    mapping(address => uint256) public stakerBalance;
    mapping(bytes32 => StakerData) public stakerData;

    struct StakerData {
        uint256 altQuantity;
        uint256 initiationTimestamp;
        uint256 durationTimestamp;
        uint256 rewardAmount;
        address staker;
    }

    event StakeCompleted(
        bytes32 stakeID,
        uint256 altQuantity,
        uint256 initiationTimestamp,
        uint256 durationTimestamp,
        uint256 rewardAmount,
        address staker,
        address phnxContractAddress,
        address portalAddress
    );

    event Unstake(
        bytes32 stakeID,
        address staker,
        address stakedToken,
        address portalAddress,
        uint256 altQuantity,
        uint256 durationTimestamp
    ); // When ERC20s are withdrawn
    
    event BaseInterestUpdated(uint256 _newRate, uint256 _oldRate);

    constructor() public {
        ratio = 821917808219178;
        phnxContractAddress = 0xfe1b6ABc39E46cEc54d275efB4b29B33be176c2A;
        maxStakedQuantity = 10000000000000000000000;
        stakeDays = 365;
        ONE_DAY = 60;
    }

    /* @dev stake function which enable the user to stake PHNX Tokens.
     *  @param _altQuantity, PHNX amount to be staked.
     *  @param _days, how many days PHNX tokens are staked for (in days)
     */
    function stakeALT(uint256 _altQuantity, uint256 _days)
        external
        whenNotPaused
        returns (uint256 rewardAmount)
    {
        require(_days <= stakeDays && _days > 0, "Invalid Days"); // To check days
        require(
            _altQuantity <= maxStakedQuantity && _altQuantity > 0,
            "Invalid PHNX quantity"
        ); // To verify PHNX quantity

       
        uint256 _timestamp = block.timestamp;
        bytes32 stakeId = keccak256(abi.encode(totalStakedTokens ,_timestamp ,getTotalrewardTokens(), msg.sender, _altQuantity));
        require(stakerData[stakeId].staker ==address(0),"Staking ID not unique, staking data already exists on this ID");
        rewardAmount = _calculateReward(_altQuantity, ratio, _days);
        

        require(rewardAmount<getTotalrewardTokens(),"Insufficient Reward");
        
        IERC20(phnxContractAddress).transferFrom(
            msg.sender,
            address(this),
            _altQuantity
        );

        
        totalStakedTokens = totalStakedTokens.add(_altQuantity);

        

        if (stakerData[stakeId].staker != address(0)) {
            _timestamp = _timestamp.add(1);
        }

        stakerData[stakeId] = StakerData(
            _altQuantity,
            _timestamp,
            _days.mul(ONE_DAY),
            rewardAmount,
            msg.sender
        );

        stakerBalance[msg.sender] = stakerBalance[msg.sender].add(_altQuantity);


        IERC20(phnxContractAddress).transfer(msg.sender, rewardAmount);

        emit StakeCompleted(
            stakeId,
            _altQuantity,
            _timestamp,
            _days.mul(ONE_DAY),
            rewardAmount,
            msg.sender,
            phnxContractAddress,
            address(this)
        );
    }

    /*  @dev unStake function which enable the user to withdraw his PHNX Tokens.
     *  @param _expiredTimestamps, time when PHNX tokens are unlocked.
     *  @param _amount, amount to be withdrawn by the user.
     */
    function unstakeALT(bytes32[] calldata _expiredStakeIds, uint256 _amount)
        external
        whenNotPaused
        returns (uint256)
    {
        require(_amount > 0, "Amount should be greater than 0");
        uint256 withdrawAmount = 0;
        uint256 burnAmount = 0;
        for (uint256 i = 0; i < _expiredStakeIds.length; i = i.add(1)) {
             bytes32 stakeId = _expiredStakeIds[i];
            require(
                stakerData[stakeId].durationTimestamp != 0,
                "Nothing staked"
            );
            if (
                stakerData[stakeId].initiationTimestamp.add(
                    stakerData[stakeId].durationTimestamp //if timestamp is not expired
                ) >= block.timestamp
            ) {
                uint256 _remainingDays = (
                    stakerData[stakeId]
                        .durationTimestamp
                        .add(stakerData[stakeId].initiationTimestamp)
                        .sub(block.timestamp)
                )
                    .div(ONE_DAY);
                uint256 _totalDays = stakerData[stakeId]
                    .durationTimestamp
                    .div(ONE_DAY);
                if (_amount >= stakerData[stakeId].altQuantity) {
                    uint256 stakeBurn = _calculateBurn(
                        stakerData[stakeId].altQuantity,
                        _remainingDays,
                        _totalDays
                    );
                    burnAmount = burnAmount.add(stakeBurn);
                    withdrawAmount = withdrawAmount.add(
                        stakerData[stakeId].altQuantity.sub(
                            stakeBurn
                        )
                    );
                    _amount = _amount.sub(
                        stakerData[stakeId].altQuantity
                    );
                    emit Unstake(
                        stakeId,
                        msg.sender,
                        phnxContractAddress,
                        address(this),
                        stakerData[stakeId].altQuantity,
                        stakerData[stakeId].durationTimestamp
                    );
                    stakerData[stakeId].altQuantity = 0;
                } else if (
                    (_amount < stakerData[stakeId].altQuantity) &&
                    _amount > 0 // if timestamp is expired
                ) {
                    stakerData[stakeId]
                        .altQuantity = stakerData[stakeId]
                        .altQuantity
                        .sub(_amount);
                    uint256 stakeBurn = _calculateBurn(
                        _amount,
                        _remainingDays,
                        _totalDays
                    );
                    burnAmount = burnAmount.add(stakeBurn);
                    withdrawAmount = withdrawAmount.add(_amount.sub(stakeBurn));
                    emit Unstake(
                        stakeId,
                        msg.sender,
                        phnxContractAddress,
                        address(this),
                        _amount,
                        stakerData[stakeId].durationTimestamp
                    );
                    _amount = 0;
                }
            } else {
                if (_amount >= stakerData[stakeId].altQuantity) {
                    _amount = _amount.sub(
                        stakerData[stakeId].altQuantity
                    );
                    withdrawAmount = withdrawAmount.add(
                        stakerData[stakeId].altQuantity
                    );
                    emit Unstake(
                        stakeId,
                        msg.sender,
                        phnxContractAddress,
                        address(this),
                        stakerData[stakeId].altQuantity,
                        stakerData[stakeId].durationTimestamp
                    );
                    stakerData[stakeId].altQuantity = 0;
                } else if (
                    (_amount < stakerData[stakeId].altQuantity) &&
                    _amount > 0
                ) {
                    stakerData[stakeId]
                        .altQuantity = stakerData[stakeId]
                        .altQuantity
                        .sub(_amount);
                    withdrawAmount = withdrawAmount.add(_amount);
                    emit Unstake(
                        stakeId,
                        msg.sender,
                        phnxContractAddress,
                        address(this),
                        _amount,
                        stakerData[stakeId].durationTimestamp
                    );
                    break;
                }
            }
        }
        require(withdrawAmount != 0, "Not Transferred");

        if (burnAmount > 0) {
            IERC20(phnxContractAddress).transfer(
                0x0000000000000000000000000000000000000001,
                burnAmount
            );
        }

        stakerBalance[msg.sender] = stakerBalance[msg.sender].sub(
            withdrawAmount
        );

        totalStakedTokens = totalStakedTokens.sub(withdrawAmount);

        IERC20(phnxContractAddress).transfer(msg.sender, withdrawAmount);
        return withdrawAmount;
    }

    /* @dev to calculate reward Amount
     *  @param _altQuantity , amount of ALT tokens staked.
     *@param _baseInterest rate
     */
    function _calculateReward(
        uint256 _altQuantity,
        uint256 _ratio,
        uint256 _days
    ) internal pure returns (uint256 rewardAmount) {
        rewardAmount = (_altQuantity.mul(_ratio).mul(_days)).div(
            1000000000000000000
        );
    }

    /* @dev function to calculate the amount of PHNX token burned incase of early unstake.
     *@param _amount, The amount of Tokens user is unstaking.
     *@param _remainingDays, remaining time before the tokens will be unlocked.
     *@param _totalDays, total days tokens were staked for.
     */
    function _calculateBurn(
        uint256 _amount,
        uint256 _remainingDays,
        uint256 _totalDays
    ) internal pure returns (uint256 burnAmount) {
        burnAmount = ((_amount * _remainingDays) / _totalDays);
    }

    /* @dev to set base interest rate. Can only be called by owner
     *  @param _rate, interest rate (in wei)
     */
    function updateRatio(uint256 _rate) external onlyOwner whenNotPaused {
        ratio = _rate;
    }

    function updateTime(uint256 _time) external onlyOwner whenNotPaused {
        ONE_DAY = _time;
    }

    function updateQuantity(uint256 _quantity) external onlyOwner whenNotPaused {
        maxStakedQuantity = _quantity;
    }

    /* @dev function to update stakeDays.
     *@param _stakeDays, updated Days .
     */
    function updatestakeDays(uint256 _stakeDays) external onlyOwner {
        stakeDays = _stakeDays;
    }

    /* @dev Funtion to withdraw all PHNX from contract incase of emergency, can only be called by owner.*/
    function withdrawTokens() external onlyOwner {
        IERC20(phnxContractAddress).transfer(
            owner(),
            IERC20(phnxContractAddress).balanceOf(address(this))
        );
        pause();
    }

    function getTotalrewardTokens() public view returns(uint256){
        return IERC20(phnxContractAddress).balanceOf(address(this)).sub(totalStakedTokens);
    }

    /* @dev function to update Phoenix contract address.
     *@param _address, new address of the contract.
     */
    function setPheonixContractAddress(address _address) public onlyOwner {
        phnxContractAddress = _address;
    }

    /* @dev function which restricts the user from stakng PHNX tokens. */
    function pause() public onlyOwner {
        _pause();
    }

    /* @dev function which disables the Pause function. */
    function unPause() public onlyOwner {
        _unpause();
    }
}