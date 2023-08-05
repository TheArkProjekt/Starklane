// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./sn/Cairo.sol";
import "./token/TokenUtil.sol";

/**
   @notice Request to bridge tokens.
*/
struct Request {
    felt252 header;
    felt252 hash;

    address collectionL1;
    snaddress collectionL2;

    address ownerL1;
    snaddress ownerL2;

    string name;
    string symbol;
    string uri;

    uint256[] tokenIds;
    uint256[] tokenValues;
    string[] tokenURIs;
}

/**
   @title Library related to the protocol for bridging tokens.
*/
library Protocol {

    uint256 private constant ERC721_MASK = 0x100;
    uint256 private constant ERC1155_MASK = 0x200;

    /**
       @notice Computes the V1 header value.

       @dev Header is a felt252 (31 bits).
       Byte 0 is the version (0x1).
       Byte 1 is the contract interface (0x1 = ERC721, 0x2 = ERC1155).

       @param ctype The collection type.
     */
    function requestHeaderV1(
        CollectionType ctype
    )
        internal
        pure
        returns (felt252)
    {
        uint256 h = 0x1;

        if (ctype == CollectionType.ERC721) {
            h |= ERC721_MASK;
        } else {
            h |= ERC1155_MASK;
        }

        return Cairo.felt252Wrap(h);
    }

    /**
       @notice Computes the request hash.

       @param salt Random salt.
       @param collection Token collection contract address (L1).
       @param toL2Address New owner on Starknet (L2).
       @param tokenIds List of token ids to be transfered.

       @return Request hash.
     */
    function requestHash(
        uint256 salt,
        address collection,
        snaddress toL2Address,
        uint256[] memory tokenIds
    )
        internal
        pure
        returns (felt252)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                salt,
                collection,
                snaddress.unwrap(toL2Address),
                tokenIds
            )
        );

        uint256 hashUint = uint256(hash) & (type(uint256).max >> 8);
        return Cairo.felt252Wrap(hashUint);
    }

    /**
       @notice Computes the serialized length of a request.

       @param req Request of which the length is computed.

       @return Length of the uint256[] that can contain the serialized request.
    */
    function requestSerializedLength(
        Request memory req
    )
        internal
        pure
        returns (uint256)
    {
        // Constant length part of the request is always 6 uint256 long.
        uint256 len = 6;

        len += Cairo.shortStringSerializedLength(req.name);
        len += Cairo.shortStringSerializedLength(req.symbol);
        len += Cairo.shortStringSerializedLength(req.uri);

        // Arrays always have their length first, then serialized length of each element.
        // For uint256, we can pre-compute it as a uint256 is 2 felts long.
        len += (req.tokenIds.length * 2) + 1;
        len += (req.tokenValues.length * 2) + 1;

        // For strings, we must iterate on the array to know the length of each string.
        // We start by adding the length of the tokenURIs array.
        len += 1;
        for (uint256 i = 0; i < req.tokenURIs.length; i++) {
            len += Cairo.shortStringSerializedLength(req.tokenURIs[i]);
        }

        return len;
    }

    /**
       @notice Serializes a bridge request into an array of uint256
       that is compatible with serialization expected by Starknet messaging.

       @param req Request to serialize.

       @return uint256[] with the serialized request.
    */
    function requestSerialize(
        Request memory req
    )
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory buf = new uint256[](requestSerializedLength(req));

        // Constant length part of the request.
        buf[0] = felt252.unwrap(req.header);
        buf[1] = felt252.unwrap(req.hash);

        buf[2] = uint256(uint160(req.collectionL1));
        buf[3] = snaddress.unwrap(req.collectionL2);

        buf[4] = uint256(uint160(req.ownerL1));
        buf[5] = snaddress.unwrap(req.ownerL2);

        // Variable length part of the request.
        uint256 offset = 6;
        offset += Cairo.shortStringSerialize(req.name, buf, offset);
        offset += Cairo.shortStringSerialize(req.symbol, buf, offset);
        offset += Cairo.shortStringSerialize(req.uri, buf, offset);

        offset += Cairo.uint256ArraySerialize(req.tokenIds, buf, offset);
        offset += Cairo.uint256ArraySerialize(req.tokenValues, buf, offset);
        offset += Cairo.shortStringArraySerialize(req.tokenURIs, buf, offset);

        return buf;
    }

    /**
       @notice Deserializes a request from uint256[] from starknet messaging.

       @param buf Uint256[] buffer with the serialized request.
       @param offset Offset in the buffer where deserialization starts.

       @return Request.
    */
    function requestDeserialize(
        uint256[] memory buf,
        uint256 offset
    )
        internal
        pure
        returns (Request memory)
    {
        Request memory req;

        req.header = Cairo.felt252Wrap(buf[offset++]);
        req.hash = Cairo.felt252Wrap(buf[offset++]);

        req.collectionL1 = address(uint160(buf[offset++]));
        req.collectionL2 = Cairo.snaddressWrap(buf[offset++]);

        req.ownerL1 = address(uint160(buf[offset++]));
        req.ownerL2 = Cairo.snaddressWrap(buf[offset++]);

        uint256 inc;

        (inc, req.name) = Cairo.shortStringDeserialize(buf, offset);
        offset += inc;

        (inc, req.symbol) = Cairo.shortStringDeserialize(buf, offset);
        offset += inc;

        (inc, req.uri) = Cairo.shortStringDeserialize(buf, offset);
        offset += inc;

        (inc, req.tokenIds) = Cairo.uint256ArrayDeserialize(buf, offset);
        offset += inc;

        (inc, req.tokenValues) = Cairo.uint256ArrayDeserialize(buf, offset);
        offset += inc;

        (inc, req.tokenURIs) = Cairo.shortStringArrayDeserialize(buf, offset);
        offset += inc;

        return req;
    }

}