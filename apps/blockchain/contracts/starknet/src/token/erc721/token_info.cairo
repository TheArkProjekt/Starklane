///! Token info.
///!
///! A struct to wrap ERC721 token information
///! in one struct.
///!
///! Mostly done for serialization purposes.

use traits::{Into, TryInto};
use serde::Serde;
use integer::U256TryIntoFelt252;
use array::{ArrayTrait, SpanTrait};
use option::OptionTrait;

use super::token_uri::{TokenURI};

/// ERC721 token info.
#[derive(Serde, Drop)]
struct TokenInfo {
    token_id: u256,
    token_uri: TokenURI,
}

/// We need this implementation as TokenInfo does not
/// impl Copy (too expensive).
impl SpanTokenInfoSerde<> of Serde<Span<TokenInfo>> {
    fn serialize(self: @Span<TokenInfo>, ref output: Array<felt252>) {
        (*self).len().serialize(ref output);
        serde::serialize_array_helper(*self, ref output);
    }
    fn deserialize(ref serialized: Span<felt252>) -> Option<Span<TokenInfo>> {
        let length = *serialized.pop_front()?;
        let mut arr = ArrayTrait::new();
        Option::Some(serde::deserialize_array_helper(ref serialized, arr, length)?.span())
    }
}

#[cfg(test)]
mod tests {
    use debug::PrintTrait;
    use serde::Serde;
    use array::{ArrayTrait, SpanTrait};
    use traits::Into;
    use option::OptionTrait;
    use super::{TokenInfo, TokenInfoSerde};

    use starknet::contract_address_const;

    use starklane::token::erc721::{TokenURI, Felt252IntoTokenURI};

    /// Should serialize and deserialize a RequestTokenBridge.
    #[test]
    #[available_gas(2000000000)]
    fn serialize_deserialize() {
        let info = TokenInfo {
            token_id: 7777_u256,
            token_uri: 'https:...'.into(),
        };

        let mut buf = ArrayTrait::<felt252>::new();
        info.serialize(ref buf);

        // u256 are 2 felts long.
        // token_uri has is 2 felts in that case.
        assert(buf.len() == 4, 'serialized buf len');

        assert(*buf[2] == 1, 'token uri len');
        assert(*buf[3] == 'https:...', 'token uri content');

        let mut sp = buf.span();
        let info2 = Serde::<TokenInfo>::deserialize(ref sp).unwrap();
    }

}