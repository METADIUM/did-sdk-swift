//
//  ECDSAVerifier.swift
//  JWS
//
//  Created by 전영배 on 16/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation
import secp256k1_swift


/// ECDSA verifier
/// SHA256WithECDSA
public class ECDSAVerifier : JWSVerifier {
    var publicKey: Data
    
    
    /// init with public key to verify
    ///
    /// - Parameter publicKey: to verify
    public init(publicKey: Data) {
        self.publicKey = publicKey
    }
    
    
    /// Verify JWS
    ///
    /// - Parameters:
    ///   - header: JWS header
    ///   - signedContent: to verify
    ///   - signature: to verify
    /// - Returns: verify result
    /// - Throws: notSupportedAlgorithm
    public func verify(header: JWSHeader, signedContent: Data, signature: Data) throws -> Bool {
        guard let algorithm = SignatureAlgorithm(rawValue: (header.parameters["alg"] as! String?)!) else {
            throw SigningError.notSupportedAlgorithm
        }
        
        switch algorithm {
        case .ES256K:
            return SECP256K1.ecdsaVerify(hash: sha256(data: signedContent), signature: signature, publicKey: publicKey)
        }
    }
    
    
}
