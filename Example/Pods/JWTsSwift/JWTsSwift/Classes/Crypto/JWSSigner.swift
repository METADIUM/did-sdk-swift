//
//  JWSSigner.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation
import CommonCrypto


/// Sign Error
///
/// - notSupportedAlgorithm: Not supported algorim.
/// - signError: Error signing
enum SigningError: Error {
    case notSupportedAlgorithm
    case signError
}


/// JWS signer
public protocol JWSSigner {
    func sign(header: JWSHeader, signingInput: Data) throws -> Data
}


/// sha256
///
/// - Parameter data: to hash
/// - Returns: hashed
func sha256(data : Data) -> Data {
    var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0, CC_LONG(data.count), &hash)
    }
    return Data.init(_: hash)
}
