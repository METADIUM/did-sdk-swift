//
//  SECP256K1+ECDSA.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation
import secp256k1_swift


// MARK: - SECP256K1 extension. from secp256k1_swift
extension SECP256K1 {
    static let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN|SECP256K1_CONTEXT_VERIFY))
    
    
    /// sign with ecdsa
    ///
    /// - Parameters:
    ///   - hash: hashed data to sign. need 32 bytes
    ///   - privateKey: to sign.
    ///   - useExtraEntropy: whether use extra entropy
    /// - Returns: if signing success, return signature else return nil
    ///   - serializedSignature: R+S compressed signature format
    ///   - rawSignature: raw signature
    public static func ecdsaSign(hash: Data, privateKey: Data, useExtraEntropy: Bool = false) -> (serializedSignature: Data?, rawSignature: Data?) {
        if (hash.count != 32 || privateKey.count != 32) {return (nil, nil)}
        if !SECP256K1.verifyPrivateKey(privateKey: privateKey) {
            return (nil, nil)
        }
        
        guard var signature = SECP256K1.sign(hash: hash, privateKey: privateKey, useExtraEntropy: useExtraEntropy) else {
            return (nil, nil)
        }
        
        guard let serializedSignature = SECP256K1.serializeSignature(signature: &signature) else {
            return (nil, nil)
        }
        
        let rawSignature = Data(toByteArray(signature))
        
        return (serializedSignature, rawSignature)
    }
    
    
    /// verify with ecdsa
    ///
    /// - Parameters:
    ///   - hash: hashed data to verify
    ///   - signature: compressed signature to verify
    ///   - publicKey: to verify
    /// - Returns: verify result
    public static func ecdsaVerify(hash: Data, signature: Data, publicKey: Data) -> Bool {
        guard hash.count == 32, signature.count == 64 else { return false }

        guard var parsedSignature: secp256k1_ecdsa_signature = parseECDSASignature(signature: signature) else {
            return false;
        }

        guard var parsedPublicKey: secp256k1_pubkey = SECP256K1.parsePublicKey(serializedKey: publicKey) else {
            return false;
        }

        guard hash.withUnsafeBytes ({ secp256k1_ecdsa_verify(context!, &parsedSignature, $0, &parsedPublicKey) }) == 1 else {
            return false
        }
        return true;
    }
    
    
    internal static func sign(hash: Data, privateKey: Data, useExtraEntropy: Bool = false) -> secp256k1_ecdsa_signature? {
        if (hash.count != 32 || privateKey.count != 32) {
            return nil
        }
        if !SECP256K1.verifyPrivateKey(privateKey: privateKey) {
            return nil
        }
        var signature: secp256k1_ecdsa_signature = secp256k1_ecdsa_signature();
        guard let extraEntropy = SECP256K1.randomBytes(length: 32) else {return nil}
        
        let result = hash.withUnsafeBytes { (hashPointer:UnsafePointer<UInt8>) -> Int32 in
            privateKey.withUnsafeBytes { (privateKeyPointer:UnsafePointer<UInt8>) -> Int32 in
                extraEntropy.withUnsafeBytes { (extraEntropyPointer:UnsafePointer<UInt8>) -> Int32 in
                    withUnsafeMutablePointer(to: &signature, { (recSignaturePtr: UnsafeMutablePointer<secp256k1_ecdsa_signature>) -> Int32 in
                        let res = secp256k1_ecdsa_sign(context!, recSignaturePtr, hashPointer, privateKeyPointer, nil, useExtraEntropy ? extraEntropyPointer : nil)
                        return res
                    })
                }
            }
        }
        if result == 0 {
            print("Failed to sign!")
            return nil
        }
        return signature
    }
    
    internal static func serializeSignature(signature: inout secp256k1_ecdsa_signature) -> Data? {
        var serializedSignature = Data(repeating: 0x00, count: 64)
        let result = serializedSignature.withUnsafeMutableBytes { (serSignaturePointer:UnsafeMutablePointer<UInt8>) -> Int32 in
            withUnsafePointer(to: &signature) { (signaturePointer:UnsafePointer<secp256k1_ecdsa_signature>) -> Int32 in
                    let res = secp256k1_ecdsa_signature_serialize_compact(context!, serSignaturePointer, signaturePointer)
                    return res
            }
        }
        if result == 0 {
            return nil
        }
        return Data(serializedSignature)
    }
    
    internal static func parseECDSASignature(signature: Data) -> secp256k1_ecdsa_signature? {
        guard signature.count == 64 else {return nil}
        var sign: secp256k1_ecdsa_signature = secp256k1_ecdsa_signature()
        let serializedSignature = Data(signature[0..<64])
        let result = serializedSignature.withUnsafeBytes{ (serPtr: UnsafePointer<UInt8>) -> Int32 in
            withUnsafeMutablePointer(to: &sign, { (signaturePointer:UnsafeMutablePointer<secp256k1_ecdsa_signature>) -> Int32 in
                let res = secp256k1_ecdsa_signature_parse_compact(context!, signaturePointer, serPtr)
                if res == 1 {
                    // h-form to l-form. secp256k1_ecdsa_sign is only supported l-form
                    secp256k1_ecdsa_signature_normalize(context!, signaturePointer, signaturePointer)
                }
                return res
            })
        }
        if result == 0 {
            return nil
        }
        return sign
    }
    
    internal static func parsePublicKey(serializedKey: Data) -> secp256k1_pubkey? {
        guard serializedKey.count == 33 || serializedKey.count == 65 else {
            return nil
        }
        let keyLen: Int = Int(serializedKey.count)
        var publicKey = secp256k1_pubkey()
        let result = serializedKey.withUnsafeBytes { (serializedKeyPointer:UnsafePointer<UInt8>) -> Int32 in
            let res = secp256k1_ec_pubkey_parse(context!, UnsafeMutablePointer<secp256k1_pubkey>(&publicKey), serializedKeyPointer, keyLen)
            return res
        }
        if result == 0 {
            return nil
        }
        return publicKey
    }
    
    
    internal static func randomBytes(length: Int) -> Data? {
        for _ in 0...1024 {
            var data = Data(repeating: 0, count: length)
            let result = data.withUnsafeMutableBytes {
                (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
                SecRandomCopyBytes(kSecRandomDefault, 32, mutableBytes)
            }
            if result == errSecSuccess {
                return data
            }
        }
        return nil
    }
    
    internal static func toByteArray<T>(_ value: T) -> [UInt8] {
        var value = value
        return withUnsafeBytes(of: &value) { Array($0) }
    }
    
    internal static func fromByteArray<T>(_ value: [UInt8], _: T.Type) -> T {
        return value.withUnsafeBytes {
            $0.baseAddress!.load(as: T.self)
        }
    }
}
