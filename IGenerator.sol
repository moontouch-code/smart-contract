// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// @Dev See { MoonTouchDNARandom }.
interface IGenerator {
    function spawn(uint seed) external returns (string memory);
}