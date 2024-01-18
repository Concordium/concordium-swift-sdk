use std::ffi::{c_char, CStr, CString};

#[no_mangle]
pub extern fn rust_greeting(to: *const c_char) -> *mut c_char {
    let c_str = unsafe { CStr::from_ptr(to) };
    let recipient = match c_str.to_str() {
        Err(_) => "there",
        Ok(string) => string,
    };
    CString::new("Hello ".to_owned() + recipient).unwrap().into_raw()
}

#[no_mangle]
pub extern fn rust_greeting_free(s: *mut c_char) {
    unsafe {
        if s.is_null() { return }
        CString::from_raw(s)
    };
}

// #[no_mangle]
// #[allow(non_snake_case)]
// pub extern fn getAccountSigningKey(
//     env: JNIEnv,
//     _: JClass,
//     seedAsHex: JString,
//     netAsStr: JString,
//     identityProviderIndex: jlong,
//     identityIndex: jlong,
//     credentialCounter: jlong,
// ) -> jstring {
//     let seed_net = match get_seed_and_net(seedAsHex, netAsStr, env) {
//         Ok(h) => h,
//         Err(err) => return KeyResult::Err(err).to_jstring(&env),
//     };
//
//     let account_signing_key = match get_account_signing_key_aux(
//         seed_net.seed_as_hex,
//         &seed_net.net_as_str,
//         identityProviderIndex as u32,
//         identityIndex as u32,
//         credentialCounter as u32,
//     ) {
//         Ok(k) => k,
//         Err(err) => return KeyResult::from(err).to_jstring(&env),
//     };
//
//     CryptoJniResult::Ok(account_signing_key).to_jstring(&env)
// }
