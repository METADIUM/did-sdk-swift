//
//  ECDSASigner.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation
import secp256k1_swift


/// ECDSA Signer
/// SHA256WithECDSA
public class ECDSASigner : JWSSigner {
    var privateKey: Data;
    
    
    /// init with private key to sign
    ///
    /// - Parameter privateKey: to sign
    public init(privateKey: Data) {
        self.privateKey = privateKey;
    }
    
    
    /// Sign data
    ///
    /// - Parameters:
    ///   - header: JWS header
    ///   - signingInput: to sign
    /// - Returns: signed data
    /// - Throws: notSupportedAlgorithm, signError
    public func sign(header: JWSHeader, signingInput: Data) throws -> Data {
        guard let algorithm = SignatureAlgorithm(rawValue: (header.parameters["alg"] as! String?)!) else {
            throw SigningError.notSupportedAlgorithm
        }
        
        switch algorithm {
        case .ES256K:
            guard case let (serializedSignature?, _?) = SECP256K1.ecdsaSign(hash: sha256(data: signingInput), privateKey: self.privateKey) else {
                throw SigningError.signError
            }
            return serializedSignature
        }
    }
    
}
