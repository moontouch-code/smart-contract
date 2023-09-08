// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// @Dev See { Random }.
interface IRandomizer {
     function rand(uint x, uint step, address user) external returns (uint new_seed);
}