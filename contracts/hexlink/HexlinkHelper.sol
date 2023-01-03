// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IHexlink.sol";
import "../Structs.sol";

contract HexlinkHelper {
    using Address for address;

    event Deploy(bytes32 indexed name, address indexed impl, address account);
    IHexlink immutable hexlink;
    address immutable accountBase;
    address immutable gasStation;
    address immutable redPacket;

    constructor(
        address _hexlink,
        address _gasStation,
        address _redPacket
    ) {
        hexlink = IHexlink(_hexlink);
        accountBase = hexlink.accountBase();
        gasStation = _gasStation;
        redPacket = _redPacket;
    }

    function deploy(bytes32 salt, bytes calldata txData) public returns(address) {
        address account = Clones.cloneDeterministic(accountBase, salt);
        account.functionCall(txData);
        emit Deploy(salt, accountBase, account);
        return account;
    }

    function redeployAndReset(
        bytes32 name,
        bytes calldata txData,
        AuthProof[] calldata proofs
    ) external {
        bytes32 salt = keccak256(abi.encode(name, block.timestamp));
        address account = deploy(salt, txData);
        if (proofs.length == 2) {
            IHexlink(hexlink).reset2Fac(name, account, proofs[0], proofs[1]);
        } else if (proofs.length == 1) {
            IHexlink(hexlink).reset2Stage(name, account, proofs[0]);
        } else {
            revert("HEXL014");
        }
    }

    function deployAndCreateRedPacket(
        bytes32 name,
        bytes calldata txData,
        AuthProof calldata proof,
        address owner,
        address packetToken,
        uint256 packetTokenAmount,
        address gasToken,
        uint256 gasTokenAmount
    ) external {
        address account = hexlink.addressOfName(name);
        if (packetToken != address(0)) {
            IERC20(packetToken).transferFrom(owner, account, packetTokenAmount);
        }
        if (gasToken != address(0)) {
            IERC20(gasToken).transferFrom(owner, account, gasTokenAmount);
        }
        hexlink.deploy(name, txData, proof);
    }
}
