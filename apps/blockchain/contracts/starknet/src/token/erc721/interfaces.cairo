use starknet::{ContractAddress, ClassHash};
use super::TokenURI;

#[abi]
trait IERC721Bridgeable {
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn balance_of(account: ContractAddress) -> u256;
    fn owner_of(token_id: u256) -> ContractAddress;
    fn token_uri(token_id: u256) -> TokenURI;
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool;

    fn permissioned_mint(to: ContractAddress, token_id: u256);
    fn set_approval_for_all(operator: ContractAddress, approved: bool);
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256);
    fn replace_class(class_hash: ClassHash);

    fn mint_with_uri(to: ContractAddress, token_id: u256, token_uri: TokenURI);
}