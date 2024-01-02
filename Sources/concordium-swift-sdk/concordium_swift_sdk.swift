import MobileWallet

enum MobileWalletError: Error, Equatable {
    case noResponse
    case failed(String)
}

func parameterToJson(_ inputJson: String) throws -> String {
    // From https://github.com/Concordium/concordium-reference-wallet-ios/blob/24a7ed0ac635bd56aac89f536fff0739b12cd577/Dependencies/MobileWalletFacade.swift#L127
    var res = ""
    try inputJson.withCString { inputPointer in
        var code: UInt8 = 0
        guard let resPtr = parameter_to_json(inputPointer, &code) else {
            throw MobileWalletError.noResponse
        }
        res = String(cString: resPtr)
        free_response_string(resPtr)

        guard code == 1 else {
            throw MobileWalletError.failed(res)
        }
    }
    return res
}
