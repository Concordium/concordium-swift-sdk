import Foundation

enum DataError: Error {
    case invalidHexString
}

// Courtesy of ChatGPT ¯\_(ツ)_/¯

extension Data {
    init(fromHexString hex: String) throws {
        let length = hex.count / 2
        var data = Data(capacity: length)

        for i in 0..<length {
            let start = hex.index(hex.startIndex, offsetBy: i * 2)
            let end = hex.index(start, offsetBy: 2)
            guard let byte = UInt8(hex[start..<end], radix: 16) else {
                throw DataError.invalidHexString
            }
            data.append(byte)
        }
        self = data
    }
    
    public func hexadecimalString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
