// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IKAP22 {
    function cap() external view returns (uint256);

    function currentIndex() external view returns (uint256);

    function currentPeriod() external view returns (uint256);

    function startTime() external view returns (uint256);

    function periodLength() external view returns (uint256);

    function mint(uint256 amount, address receiver) external returns (bool);

    function burn(uint256 period, uint256 amount, address owner) external returns (bool);

    event Mint(uint256 indexed period, address indexed receiver, uint256 amount);

    event Burn(address indexed owner, uint256 amount);
}