// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDotDotLPStaker {
    struct Amounts {
        uint256 epx;
        uint256 ddd;
    }
    struct ExtraReward {
        address token;
        uint256 amount;
    }

    // pool -> DDD deposit token
    // mapping(address => address) public depositTokens;
    function depositTokens(address _pool) external view returns (address);

    // user -> pool -> deposit amount
    // mapping(address => mapping(address => uint256)) public userBalances;
    function userBalances(address _user, address _pool) external view returns (uint256);

    function extraRewardsLength(address _pool) external view returns (uint256);

    function claimable(address _user, address[] calldata _tokens)
        external
        view
        returns (Amounts[] memory);

    function claimableExtraRewards(address user, address pool)
        external
        view
        returns (ExtraReward[] memory);

    function deposit(
        address _user,
        address _token,
        uint256 _amount
    ) external;

    function withdraw(
        address _receiver,
        address _token,
        uint256 _amount
    ) external;

    function claim(
        address _receiver,
        address[] calldata _tokens,
        uint256 _maxBondAmount
    ) external;

    /**
        @notice Claim all third-party incentives earned from `pool`
     */
    function claimExtraRewards(address _receiver, address pool) external;

    /**
        @notice Update the local cache of third-party rewards for a given LP token
        @dev Must be called each time a new incentive token is added to a pool, in
             order for the protocol to begin distributing that token.
     */
    function updatePoolExtraRewards(address pool) external;

    function transferDeposit(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);
}
