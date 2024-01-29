use wallet_library::wallet::{
    get_account_public_key_aux, get_account_signing_key_aux,
    get_attribute_commitment_randomness_aux, get_credential_id_aux, get_id_cred_sec_aux,
    get_prf_key_aux, get_signature_blinding_randomness_aux,
    get_verifiable_credential_backup_encryption_key_aux, get_verifiable_credential_public_key_aux,
    get_verifiable_credential_signing_key_aux,
};

// UniFFI book: https://mozilla.github.io/uniffi-rs/udl_file_spec.html
uniffi::include_scaffolding!("lib");

/// Error type returned by the bridge functions.
/// A corresponding Swift type will be generated (via the UDL definition).
#[derive(Debug, thiserror::Error)]
enum ConcordiumWalletCryptoError {
    #[error("call {call} failed: {msg}")]
    CallFailed { call: String, msg: String },
}

fn get_account_signing_key(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
    credential_counter: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_account_signing_key_aux(seed_hex, net.as_str(), identity_provider_index, identity_index, credential_counter)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_account_signing_key(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index}, credential_counter={credential_counter})"),
            msg: e.to_string(),
        })
}

fn get_account_public_key(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
    credential_counter: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_account_public_key_aux(seed_hex, net.as_str(), identity_provider_index, identity_index, credential_counter)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_account_public_key(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index}, credential_counter={credential_counter})"),
            msg: e.to_string(),
        })
}

fn get_id_cred_sec(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_id_cred_sec_aux(seed_hex, net.as_str(), identity_provider_index, identity_index)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_id_cred_sec(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index})"),
            msg: e.to_string(),
        })
}

fn get_prf_key(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_prf_key_aux(seed_hex, net.as_str(), identity_provider_index, identity_index)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_prf_key(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index})"),
            msg: e.to_string(),
        })
}

fn get_credential_id(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
    credential_counter: u8,
    commitment_key: String,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_credential_id_aux(seed_hex, net.as_str(), identity_provider_index, identity_index, credential_counter, commitment_key.as_str())
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_credential_id(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index}, credential_counter={credential_counter}, commitment_key={commitment_key})"),
            msg: e.to_string(),
        })
}

fn get_signature_blinding_randomness(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_signature_blinding_randomness_aux(seed_hex, net.as_str(), identity_provider_index, identity_index)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_signature_blinding_randomness(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index})"),
            msg: e.to_string(),
        })
}

fn get_attribute_commitment_randomness(
    seed_hex: String,
    net: String,
    identity_provider_index: u32,
    identity_index: u32,
    credential_counter: u32,
    attribute: u8,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_attribute_commitment_randomness_aux(seed_hex, net.as_str(), identity_provider_index, identity_index, credential_counter, attribute)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_attribute_commitment_randomness(seed_hex, net={net}, identity_provider_index={identity_provider_index}, identity_index={identity_index}, credential_counter={credential_counter}, attribute={attribute})"),
            msg: e.to_string(),
        })
}

fn get_verifiable_credential_signing_key(
    seed_hex: String,
    net: String,
    issuer_index: u64,
    issuer_subindex: u64,
    verifiable_credential_index: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_verifiable_credential_signing_key_aux(seed_hex, net.as_str(), issuer_index, issuer_subindex, verifiable_credential_index)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_verifiable_credential_signing_key(seed_hex, net={net}, issuer_index={issuer_index}, issuer_subindex={issuer_subindex}, verifiable_credential_index={verifiable_credential_index})"),
            msg: e.to_string(),
        })
}

fn get_verifiable_credential_public_key(
    seed_hex: String,
    net: String,
    issuer_index: u64,
    issuer_subindex: u64,
    verifiable_credential_index: u32,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_verifiable_credential_public_key_aux(seed_hex, net.as_str(), issuer_index, issuer_subindex, verifiable_credential_index)
        .map_err(|e| ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_verifiable_credential_public_key(seed_hex, net={net}, issuer_index={issuer_index}, issuer_subindex={issuer_subindex}, verifiable_credential_index={verifiable_credential_index})"),
            msg: e.to_string(),
        })
}

fn get_verifiable_credential_backup_encryption_key(
    seed_hex: String,
    net: String,
) -> Result<String, ConcordiumWalletCryptoError> {
    get_verifiable_credential_backup_encryption_key_aux(seed_hex, net.as_str()).map_err(|e| {
        ConcordiumWalletCryptoError::CallFailed {
            call: format!("get_verifiable_credential_backup_encryption_key(seed_hex, net={net}"),
            msg: e.to_string(),
        }
    })
}
