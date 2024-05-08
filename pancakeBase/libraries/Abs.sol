// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

library Abs {
    function abs(int x) internal pure returns (int) {
        return x >= 0 ? x : -x;
    }
}