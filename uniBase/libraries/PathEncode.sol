// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

library PathEncode {
    function pathEncode(
        address[] memory pathList,
        uint24[] memory feeList
    ) internal pure returns (bytes memory path) {
        require(feeList.length == (pathList.length - 1));

        uint lastIdx = pathList.length - 1;
        path = new bytes(0);
        for (uint256 i = 0; i < pathList.length; i++) {
            path = abi.encodePacked(path, pathList[i]);

            if (i != lastIdx) {
                path = abi.encodePacked(path, feeList[i]);
            }
        }
    }

    function pathEncodeReverse(
        address[] memory pathList,
        uint24[] memory feeList
    ) internal pure returns (bytes memory path) {
        require(feeList.length == (pathList.length - 1));

        uint lastIdx = pathList.length;
        path = new bytes(0);
        for (uint256 i = lastIdx; i > 0; i--) {
            if (i != lastIdx) {
                path = abi.encodePacked(path, feeList[i - 1]);
            }

            path = abi.encodePacked(path, pathList[i - 1]);
        }
    }
}
