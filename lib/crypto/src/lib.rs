use wallet_library::wallet::get_account_signing_key_aux;

// UniFFI book: https://mozilla.github.io/uniffi-rs/udl_file_spec.html
uniffi::include_scaffolding!("lib");

#[derive(Debug, thiserror::Error)]
enum WalletCryptoError {
    #[error("call {call} failed: {msg}")]
    CallFailed { call: String, msg: String },
}

fn get_account_signing_key(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u32, credential_counter: u32) -> Result<String, WalletCryptoError> {
    get_account_signing_key_aux(seed_hex, net.as_str(), identity_provider_index, identity_index, credential_counter)
        .map_err(|e| WalletCryptoError::CallFailed {
            call: format!("get_account_signing_key(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index}, credential_counter={credential_counter})"),
            msg: e.to_string(),
        })
}

fn getAccountPublicKey(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u64, credential_counter: u32) -> String {
    todo!()
}

fn getIdCredSec(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u32) -> String {
    todo!()
}

fn getPrfKey(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u32) -> String {
    todo!()
}

fn getCredentialId(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u32, credential_counter: u32, commitment_key: String) -> String {
    todo!()
}

fn getSignatureBlindingRandomness(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u32) -> String {
    todo!()
}

fn getAttributeCommitmentRandomness(seed_hex: String, net: String, identity_provider_index: u32, identity_index: u64, credential_counter: u64, attribute: u32) -> String {
    todo!()
}
