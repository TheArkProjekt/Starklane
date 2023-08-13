///! Bridge contract.
///!
///! The bridge contract is in charge to handle
///! the logic associated with assets transfer.
///!
///! The bridge needs to keep L1<->L2 reverse mapping up to date
///! to ensure all scenarios can be hanlded without deploying
///! the same collection twice.
///! This takes in account the possible minting after a collection
///! being bridged.

use starknet::{ContractAddress, ClassHash};
use starklane::protocol::Request;

#[starknet::interface]
trait IBridge<T> {
    //fn on_l1_message(ref self: T) -> ContractAddress;
    fn on_l1_message(ref self: T, req: Request) -> ContractAddress;

    fn deposit_tokens(
        ref self: T,
        hash: felt252,
        collection_l2: ContractAddress,
        owner_l1: felt252,
        token_ids: Span<u256>
    );

    fn set_bridge_l1_addr(ref self: T, address: felt252);

    fn set_erc721_default_contract(ref self: T, class_hash: ClassHash);

    fn get_erc721_default(self: @T) -> ClassHash;

    fn is_token_escrowed_ext(self: @T, collection_address: ContractAddress, token_id: u256) -> bool;

    fn replace_class(ref self: T, class_hash: ClassHash);

    fn read_dummy(self: @T) -> felt252;
}

#[starknet::contract]
mod bridge {
    use array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto};
    use zeroable::Zeroable;
    use serde::Serde;
    use debug::PrintTrait;

    use starknet::{ClassHash, ContractAddress};
    use starknet::contract_address::ContractAddressZeroable;

    use starklane::string::LongString;
    use starklane::protocol::Request;
    use starklane::protocol::deploy;
    use starklane::token::erc721::{
        TokenInfo, IERC721BridgeableDispatcher, IERC721BridgeableDispatcherTrait
    };

    // TODO(glihm): refacto when `Self` is supported inside imports.
    use starklane::token::erc721;

    #[storage]
    struct Storage {
        // Bridge administrator.
        bridge_admin: ContractAddress,
        // Bridge address on L1 (to allow it to consume messages).
        bridge_l1_address: felt252,
        // The class to deploy for ERC721 tokens.
        erc721_bridgeable_class: ClassHash,
        // Mapping between L2<->L1 collections addresses.
        // <collection_l2_address, collection_l1_address>
        l2_to_l1_addresses: LegacyMap::<ContractAddress, felt252>,
        // Mapping between L1<->L2 collections addresses.
        // <collection_l1_address, collection_l2_address>
        l1_to_l2_addresses: LegacyMap::<felt252, ContractAddress>,
        // Registry of escrowed token for collections.
        // <(collection_l2_address, token_id), original_depositor_l2_address>
        escrow: LegacyMap::<(ContractAddress, u256), ContractAddress>,
        //
        dummy: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, bridge_admin: ContractAddress) {
        self.bridge_admin.write(bridge_admin);
    }

    //
    // *** EVENTS ***
    //
    // TODO: check when it will be possible to declare
    // those events outside of the contract impl.
    //
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CollectionDeployedFromL1: CollectionDeployedFromL1,
        // TODO: factorize this events, one for all.
        ReplacedClassHash: ReplacedClassHash,
        ERC721DefaultClassChanged: ERC721DefaultClassChanged,
        TestEvent: TestEvent,
        TestEvent2: TestEvent2,
    }

    #[derive(Drop, starknet::Event)]
    struct CollectionDeployedFromL1 {
        l1_addr: felt252,
        l2_addr: ContractAddress,
        name: LongString,
        symbol: LongString
    }

    #[derive(Drop, starknet::Event)]
    struct TestEvent2 {
        type_1: felt252,
        l2_addr: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ReplacedClassHash {
        contract: ContractAddress,
        class: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    struct ERC721DefaultClassChanged {
        class: ClassHash, 
    }

    #[derive(Drop, starknet::Event)]
    struct TestEvent {
        vv: felt252, 
    }


    // *** VIEWS ***

    // TODO: add some views (admin and not admin) to see some states
    // for collections. For instance check if a collection is bridged,
    // what is it's L1 address, etc...
    //
    // For that -> maybe having a hash map l1<->l2 and l2<->l1 may be interesting?
    #[l1_handler]
    fn l1_test(ref self: ContractState, from_address: felt252, i2: felt252) {
        self.dummy.write(i2);
        self.emit(TestEvent { vv: 1234 });

        let mut p: Array<felt252> = ArrayTrait::new();
        p.append(1);
        p.append(2);
        p.append(3);

        starknet::send_message_to_l1_syscall(0xbeeffeeb, p.span(), ).unwrap_syscall();
    }

    #[external(v0)]
    fn set_dummy(ref self: ContractState, a: felt252) {
        self.dummy.write(a);

        self.emit(TestEvent { vv: a });

        let mut p: Array<felt252> = ArrayTrait::new();
        p.append(1);
        p.append(2);
        p.append(a);

        starknet::send_message_to_l1_syscall(0xbeeffeeb, p.span(), ).unwrap_syscall();
    }

    #[l1_handler]
    fn deposit_from_l1_3(
        ref self: ContractState,
        from_address: felt252,
        payload: Span<felt252>) {
        // Can't have a ref on payload...!
        // Need to copy all the values...?!
        // TODO: ensure it's the L1 bridge talking.
        //super::IBridge::on_l1_message(ref self, req);
        self.emit(TestEvent { vv: 123498 });
    }

    #[l1_handler]
    fn deposit_from_l1_2(
        ref self: ContractState,
        from_address: felt252,
        payload_len: felt252,
        req: Request) {
        // TODO: ensure it's the L1 bridge talking.
        super::IBridge::on_l1_message(ref self, req);
    }

    #[l1_handler]
    fn deposit_from_l1(ref self: ContractState, from_address: felt252, req: Request) {
        // TODO: ensure it's the L1 bridge talking.
        super::IBridge::on_l1_message(ref self, req);
    }

    #[external(v0)]
    fn write_dummy(ref self: ContractState, i2: felt252) {
        self.dummy.write(i2);
        self.emit(TestEvent { vv: i2 });

        let mut payload: Array<felt252> = ArrayTrait::new();
        payload.append(1);
        payload.append(i2);
        starknet::send_message_to_l1_syscall(i2, payload.span()).unwrap_syscall();
    }

    #[external(v0)]
    impl Bridge of super::IBridge<ContractState> {
        fn set_bridge_l1_addr(ref self: ContractState, address: felt252) {
            // TODO: only admin.
            self.bridge_l1_address.write(address);
        }

        fn read_dummy(self: @ContractState) -> felt252 {
            self.dummy.read()
        }

        fn get_erc721_default(self: @ContractState) -> ClassHash {
            self.erc721_bridgeable_class.read()
        }

        fn is_token_escrowed_ext(
            self: @ContractState, collection_address: ContractAddress, token_id: u256
        ) -> bool {
            !self.escrow.read((collection_address, token_id)).is_zero()
        }

        // *** EXTERNALS ***

        /// Simulates a message received from the L1.
        ///
        /// TODO: replace by the l1_handler. For that
        /// we must know exactly how deserialization works from l1_handler.
        ///
        /// TODO: Returns the contract address for testing purposes. Need to be revised.
        /// TODO: switch this to INTERNAL...!
        fn on_l1_message(ref self: ContractState, req: Request) -> ContractAddress {
            // TODO: check header version + len?
            // Length in header may be useless, only a version to start
            // to ensure we can upgrade both side without conflict.

            // TODO: add a global request verificator! (no owner addr to 0, at least 1 token, etc...)

            let collection_l2 = ensure_collection_deployment(ref self, @req);
            let collection = IERC721BridgeableDispatcher {
                contract_address: collection_l2
            };

            let mut i = 0;
            loop {
                if i == req.token_ids.len() {
                    break ();
                }

                let token_id = *req.token_ids[i];
                let token_uri = *req.token_URIs[i];

                let to = req.owner_l2;
                let from = starknet::get_contract_address();

                let is_escrowed = !self.escrow.read((collection_l2, token_id)).is_zero();

                if is_escrowed {
                    collection.transfer_from(from, to, token_id);
                    // TODO: emit event.
                } else {
                    collection.permissioned_mint(to, token_id, token_uri);
                    // TODO: emit event.
                }

                i += 1;
            };

            collection_l2
        }

        /// Deposits tokens to be bridged on the L1.
        ///
        /// * `req_hash` - Request hash, unique identifier of the request.
        /// * `collection_l2_address` - Address of the collection on L2.
        /// * `owner_l1_address` - Address of the owner on L1.
        /// * `tokens_ids` - Tokens to be bridged on L1.
        ///
        /// TODO: The return type may be omitted, it's for debug for now.
        /// TODO: add the useWithdrawQuick boolean + useAutoBurn on deposit too.
        fn deposit_tokens(
            ref self: ContractState,
            hash: felt252,
            collection_l2: ContractAddress,
            owner_l1: felt252,
            token_ids: Span<u256>
        ) {
            // TODO: is that correct? The deposit_tokens is called from user's account contract?
            let from = starknet::get_caller_address();
            let to = starknet::get_contract_address();
            let collection = IERC721BridgeableDispatcher {
                contract_address: collection_l2
            };

            let name = collection.name();
            let symbol = collection.symbol();

            let mut token_URIs = ArrayTrait::<LongString>::new();
            let mut i = 0;
            loop {
                if i == token_ids.len() {
                    break ();
                }

                // TODO: Will revert if the approval missing. Do we need to check
                // the approval explicitely? Or it's fine like this?
                let token_id = *token_ids[i];
                collection.transfer_from(from, to, token_id);
                self.escrow.write((collection_l2, token_id), from);

                let token_uri =
                    match erc721::token_uri_from_contract_call(collection_l2, token_id) {
                    Option::Some(uri) => uri,
                    Option::None(_) => {
                        // TODO: Token URI missing for the token...? Revert? Skip?
                        'NO_URI'.into()
                    }
                };

                token_URIs.append(token_uri);

                i += 1;
            };

            let collection_l1 = self.l2_to_l1_addresses.read(collection_l2);

            let req = Request {
                // TODO: define the header content.
                header: 0x222,
                hash,
                collection_l1,
                collection_l2,
                name,
                symbol,
                uri: ''.into(),
                owner_l1,
                owner_l2: from,
                token_ids: token_ids,
                token_values: ArrayTrait::<u256>::new().span(),
                token_URIs: token_URIs.span(),
            };

            let mut req_buf: Array<felt252> = ArrayTrait::new();
            req.serialize(ref req_buf);

            // TODO: check if bridge open or if at least bridge_l1_address is set.

            // TODO: we can match the error to emit an event in case of error and an event in case
            // of success.
            starknet::send_message_to_l1_syscall(
                self.bridge_l1_address.read(),
                req_buf.span(),
            )
                .unwrap_syscall();
        }

        /// Sets the default class hash to be deployed when the
        /// first token of a collection is bridged.
        ///
        /// * `class_hash` - Class hash of the ERC721 to set as default.
        fn set_erc721_default_contract(ref self: ContractState, class_hash: ClassHash) {
            ensure_is_admin(@self);
            self.erc721_bridgeable_class.write(class_hash);
            self.emit(ERC721DefaultClassChanged { class: class_hash });
        }

        fn replace_class(ref self: ContractState, class_hash: ClassHash) {
            ensure_is_admin(@self);

            match starknet::replace_class_syscall(class_hash) {
                Result::Ok(_) => self
                    .emit(
                        ReplacedClassHash {
                            contract: starknet::get_contract_address(), class: class_hash
                        }
                    ),
                Result::Err(revert_reason) => panic(revert_reason),
            };
        }
    }

    // *** INTERNALS ***

    /// Ensures the caller is the bridge admin. Revert if it's not.
    fn ensure_is_admin(self: @ContractState) {
        assert(starknet::get_caller_address() == self.bridge_admin.read(), 'Unauthorized action');
    }

    /// Verifies the collection addresses in the request and the local mapping
    /// to determines the correctness of the request and if the collection
    /// must be deployed or not.
    ///
    /// Returns collection L2 address if deploy is required, else 0.
    fn verify_request_mapping_addresses(
        self: @ContractState, l1_addr_req: felt252, l2_addr_req: ContractAddress, 
    ) -> ContractAddress {
        let l1_addr_mapping = self.l2_to_l1_addresses.read(l2_addr_req);
        let l2_addr_mapping = self.l1_to_l2_addresses.read(l1_addr_req);

        let mut panic_data: Array<felt252> = ArrayTrait::new();

        // L1 address must always be set as we receive the request from L1.
        if l1_addr_req.is_zero() {
            panic_data.append('L1 address cannot be 0');
            panic(panic_data);
        }

        // L1 address is present in the request and L2 address is not.
        if !l1_addr_req.is_zero() & l2_addr_req.is_zero() {
            if l2_addr_mapping.is_zero() {
                // It's the first token of the collection to be bridged.
                return ContractAddressZeroable::zero();
            } else {
                // It's not the first token of the collection to be bridged,
                // and the collection tokens were always bridged L1 -> L2.
                return l2_addr_mapping;
            }
        }

        // L1 address is present, and L2 address too.
        if !l1_addr_req.is_zero() & !l2_addr_req.is_zero() {
            if l2_addr_mapping != l2_addr_req {
                panic_data.append('Invalid collection L2 address');
                panic(panic_data);
            } else if l1_addr_mapping != l1_addr_req {
                panic_data.append('Invalid collection L1 address');
                panic(panic_data);
            } else {
                // All addresses match, we don't need to deploy anything.
                return l2_addr_mapping;
            }
        }

        panic_data.append('UNREACHABLE');
        panic(panic_data)
    }

    /// Deploys the collection contract, if necessary.
    /// Returns the address of the collection on l2.
    ///
    /// * `req` - Request for bridging assets.
    fn ensure_collection_deployment(
        ref self: ContractState, req: @Request
    ) -> ContractAddress {
        let collection_l2 = verify_request_mapping_addresses(
            @self, *req.collection_l1, *req.collection_l2
        );

        if !collection_l2.is_zero() {
            return collection_l2;
        }

        // TODO: check if pedersen if strong enough here, or do we need poseidon on
        // all the request? (which can be nice, in order to include the req_hash)
        let salt = pedersen(*req.collection_l1, *req.owner_l1);

        let l2_addr_from_deploy = deploy::deploy_erc721_bridgeable(
            self.erc721_bridgeable_class.read(),
            salt,
            *req.name,
            *req.symbol,
            starknet::get_contract_address(),
        );

        self.l1_to_l2_addresses.write(*req.collection_l1, l2_addr_from_deploy);
        self.l2_to_l1_addresses.write(l2_addr_from_deploy, *req.collection_l1);

        self
            .emit(
                CollectionDeployedFromL1 {
                    l1_addr: *req.collection_l1,
                    l2_addr: l2_addr_from_deploy,
                    name: *req.name,
                    symbol: *req.symbol
                }
            );

        l2_addr_from_deploy
    }
}

#[cfg(test)]
mod tests {
    use super::bridge;

    use array::{ArrayTrait, SpanTrait};
    use option::OptionTrait;
    use core::result::ResultTrait;
    use traits::{TryInto, Into};
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::{ContractAddress, ClassHash};

    use starknet::testing;

    /// Deploy a bridge instance.
    fn deploy(admin_addr: ContractAddress, ) -> ContractAddress {
        let mut calldata: Array<felt252> = array::ArrayTrait::new();
        calldata.append(admin_addr.into());

        let (addr, _) = starknet::deploy_syscall(
            bridge::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .expect('deploy_syscall failed');

        addr
    }
}