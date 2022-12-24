// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableSwap {
    function coins(uint256 i) external view returns (address);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        address _receiver
    ) external returns (uint256);

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        address _receiver
    ) external returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function calc_token_amount(uint256[] memory amounts, bool _is_deposit)
        external
        view
        returns (uint256);

    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received
    ) external;

    function remove_liquidity_imbalance(uint256[] memory _amounts, uint256 _max_burn_amount)
        external;

    function remove_liquidity(
        uint256 burn_amount,
        uint256[] memory min_amounts,
        address to
    ) external returns (uint256[] memory outputAmounts);

    function remove_liquidity(
        uint256 burn_amount,
        uint256[] memory min_amounts,
        bool useETH,
        address to
    ) external returns (uint256[] memory outputAmounts);

    function add_liquidity(
        uint256[] memory _deposit_amounts,
        uint256 min_mint_amount,
        address to
    ) external returns (uint256);

    function add_liquidity(
        uint256[] memory _deposit_amounts,
        uint256 min_mint_amount,
        bool useETH,
        address to
    ) external returns (uint256);
}
