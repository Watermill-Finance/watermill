// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

library Array {
    function inArray(
        address[] memory array,
        address value
    ) internal pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }

    // function removeArray(address[] memory array, address value) internal {
    //     for (uint i = 0; i < array.length; i++) {
    //         if (array[i] == value) {
    //             delete array[i];
    //         }
    //     }
    // }
}
