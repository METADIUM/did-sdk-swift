//
//  SECP256K1+ECDSA.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation
import secp256k1

public struct SECP256K1 {
    public struct UnmarshaledSignature{
        public var v: UInt8 = 0
        public var r = Data(repeating: 0, count: 32)
        public var s = Data(repeating: 0, count: 32)
        
        public init(v: UInt8, r: Data, s: Data) {
            self.v = v
            self.r = r
            self.s = s
        }
    }
}

// MARK: - SECP256K1 extension. from secp256k1_swift
extension SECP256K1 {
    static let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN|SECP256K1_CONTEXT_VERIFY))
    
    public static func signForRecovery(hash: Data, privateKey: Data, useExtraEntropy: Bool = false) -> (serializedSignature:Data?, rawSignature: Data?) {
        if (hash.count != 32 || privateKey.count != 32) {return (nil, nil)}
        if !SECP256K1.verifyPrivateKey(privateKey: privateKey) {
            return (nil, nil)
        }
        for _ in 0...1024 {
            guard var recoverableSignature = SECP256K1.recoverableSign(hash: hash, privateKey: privateKey, useExtraEntropy: useExtraEntropy) else {
                continue
            }
            guard let truePublicKey = SECP256K1.privateKeyToPublicKey(privateKey: privateKey) else {continue}
            guard let recoveredPublicKey = SECP256K1.recoverPublicKey(hash: hash, recoverableSignature: &recoverableSignature) else {continue}
            if !SECP256K1.constantTimeComparison(Data(toByteArray(truePublicKey.data)), Data(toByteArray(recoveredPublicKey.data))) {
                continue
            }
            guard let serializedSignature = SECP256K1.serializeSignature(recoverableSignature: &recoverableSignature) else {continue}
            let rawSignature = Data(toByteArray(recoverableSignature))
            return (serializedSignature, rawSignature)
        }
        return (nil, nil)
    }
    
    public static func privateToPublic(privateKey: Data, compressed: Bool = false) -> Data? {
        if (privateKey.count != 32) {return nil}
        guard var publicKey = SECP256K1.privateKeyToPublicKey(privateKey: privateKey) else {return nil}
        guard let serializedKey = serializePublicKey(publicKey: &publicKey, compressed: compressed) else {return nil}
        return serializedKey
    }
    
    public static func combineSerializedPublicKeys(keys: [Data], outputCompressed: Bool = false) -> Data? {
        let numToCombine = keys.count
        guard numToCombine >= 1 else { return nil}
        var storage = ContiguousArray<secp256k1_pubkey>()
        let arrayOfPointers = UnsafeMutablePointer< UnsafePointer<secp256k1_pubkey>? >.allocate(capacity: numToCombine)
        defer {
            arrayOfPointers.deinitialize(count: numToCombine)
            arrayOfPointers.deallocate()
        }
        for i in 0 ..< numToCombine {
            let key = keys[i]
            guard let pubkey = SECP256K1.parsePublicKey(serializedKey: key) else {return nil}
            storage.append(pubkey)
        }
        for i in 0 ..< numToCombine {
            withUnsafePointer(to: &storage[i]) { (ptr) -> Void in
                arrayOfPointers.advanced(by: i).pointee = ptr
            }
        }
        let immutablePointer = UnsafePointer(arrayOfPointers)
        var publicKey: secp256k1_pubkey = secp256k1_pubkey()
        let result = withUnsafeMutablePointer(to: &publicKey) { (pubKeyPtr: UnsafeMutablePointer<secp256k1_pubkey>) -> Int32 in
            let res = secp256k1_ec_pubkey_combine(context!, pubKeyPtr, immutablePointer, numToCombine)
            return res
        }
        if result == 0 {
            return nil
        }
        let serializedKey = SECP256K1.serializePublicKey(publicKey: &publicKey, compressed: outputCompressed)
        return serializedKey
    }
    
    
    internal static func recoverPublicKey(hash: Data, recoverableSignature: inout secp256k1_ecdsa_recoverable_signature) -> secp256k1_pubkey? {
        guard hash.count == 32 else {return nil}
        var publicKey: secp256k1_pubkey = secp256k1_pubkey()
        let result = hash.withUnsafeBytes { (hashPointer:UnsafePointer<UInt8>) -> Int32 in
            withUnsafePointer(to: &recoverableSignature, { (signaturePointer:UnsafePointer<secp256k1_ecdsa_recoverable_signature>) -> Int32 in
                withUnsafeMutablePointer(to: &publicKey, { (pubKeyPtr: UnsafeMutablePointer<secp256k1_pubkey>) -> Int32 in
                    let res = secp256k1_ecdsa_recover(context!, pubKeyPtr,
                                                      signaturePointer, hashPointer)
                    return res
                })
            })
        }
        if result == 0 {
            return nil
        }
        return publicKey
    }
    
    internal static func privateKeyToPublicKey(privateKey: Data) -> secp256k1_pubkey? {
        if (privateKey.count != 32) {return nil}
        var publicKey = secp256k1_pubkey()
        let result = privateKey.withUnsafeBytes { (privateKeyPointer:UnsafePointer<UInt8>) -> Int32 in
            let res = secp256k1_ec_pubkey_create(context!, UnsafeMutablePointer<secp256k1_pubkey>(&publicKey), privateKeyPointer)
            return res
        }
        if result == 0 {
            return nil
        }
        return publicKey
    }
    
    public static func serializePublicKey(publicKey: inout secp256k1_pubkey, compressed: Bool = false) -> Data? {
        var keyLength = compressed ? 33 : 65
        var serializedPubkey = Data(repeating: 0x00, count: keyLength)
        let result = serializedPubkey.withUnsafeMutableBytes { (serializedPubkeyPointer:UnsafeMutablePointer<UInt8>) -> Int32 in
            withUnsafeMutablePointer(to: &keyLength, { (keyPtr:UnsafeMutablePointer<Int>) -> Int32 in
                withUnsafeMutablePointer(to: &publicKey, { (pubKeyPtr:UnsafeMutablePointer<secp256k1_pubkey>) -> Int32 in
                    let res = secp256k1_ec_pubkey_serialize(context!,
                                                            serializedPubkeyPointer,
                                                            keyPtr,
                                                            pubKeyPtr,
                                                            UInt32(compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED))
                    return res
                })
            })
        }
        
        if result == 0 {
            return nil
        }
        return Data(serializedPubkey)
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
    
    public static func parseSignature(signature: Data) -> secp256k1_ecdsa_recoverable_signature? {
        guard signature.count == 65 else {return nil}
        var recoverableSignature: secp256k1_ecdsa_recoverable_signature = secp256k1_ecdsa_recoverable_signature()
        let serializedSignature = Data(signature[0..<64])
        let v = Int32(signature[64])
        let result = serializedSignature.withUnsafeBytes{ (serPtr: UnsafePointer<UInt8>) -> Int32 in
            withUnsafeMutablePointer(to: &recoverableSignature, { (signaturePointer:UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>) -> Int32 in
                let res = secp256k1_ecdsa_recoverable_signature_parse_compact(context!, signaturePointer, serPtr, v)
                return res
            })
        }
        if result == 0 {
            return nil
        }
        return recoverableSignature
    }
    
    internal static func serializeSignature(recoverableSignature: inout secp256k1_ecdsa_recoverable_signature) -> Data? {
        var serializedSignature = Data(repeating: 0x00, count: 64)
        var v: Int32 = 0
        let result = serializedSignature.withUnsafeMutableBytes { (serSignaturePointer:UnsafeMutablePointer<UInt8>) -> Int32 in
            withUnsafePointer(to: &recoverableSignature) { (signaturePointer:UnsafePointer<secp256k1_ecdsa_recoverable_signature>) -> Int32 in
                withUnsafeMutablePointer(to: &v, { (vPtr: UnsafeMutablePointer<Int32>) -> Int32 in
                    let res = secp256k1_ecdsa_recoverable_signature_serialize_compact(context!, serSignaturePointer, vPtr, signaturePointer)
                    return res
                })
            }
        }
        if result == 0 {
            return nil
        }
        if (v == 0) {
            serializedSignature.append(0x00)
        } else if (v == 1) {
            serializedSignature.append(0x01)
        } else {
            return nil
        }
        return Data(serializedSignature)
    }
    
    internal static func recoverableSign(hash: Data, privateKey: Data, useExtraEntropy: Bool = false) -> secp256k1_ecdsa_recoverable_signature? {
        if (hash.count != 32 || privateKey.count != 32) {
            return nil
        }
        if !SECP256K1.verifyPrivateKey(privateKey: privateKey) {
            return nil
        }
        var recoverableSignature: secp256k1_ecdsa_recoverable_signature = secp256k1_ecdsa_recoverable_signature();
        guard let extraEntropy = SECP256K1.randomBytes(length: 32) else {return nil}
        let result = hash.withUnsafeBytes { (hashPointer:UnsafePointer<UInt8>) -> Int32 in
            privateKey.withUnsafeBytes { (privateKeyPointer:UnsafePointer<UInt8>) -> Int32 in
                extraEntropy.withUnsafeBytes { (extraEntropyPointer:UnsafePointer<UInt8>) -> Int32 in
                    withUnsafeMutablePointer(to: &recoverableSignature, { (recSignaturePtr: UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>) -> Int32 in
                        let res = secp256k1_ecdsa_sign_recoverable(context!, recSignaturePtr, hashPointer, privateKeyPointer, nil, useExtraEntropy ? extraEntropyPointer : nil)
                        return res
                    })
                }
            }
        }
        if result == 0 {
            print("Failed to sign!")
            return nil
        }
        return recoverableSignature
    }
    
    public static func recoverPublicKey(hash: Data, signature: Data, compressed: Bool = false) -> Data? {
        guard hash.count == 32, signature.count == 65 else {return nil}
        guard var recoverableSignature = parseSignature(signature: signature) else {return nil}
        guard var publicKey = SECP256K1.recoverPublicKey(hash: hash, recoverableSignature: &recoverableSignature) else {return nil}
        guard let serializedKey = SECP256K1.serializePublicKey(publicKey: &publicKey, compressed: compressed) else {return nil}
        return serializedKey
    }
    
    
    public static func verifyPrivateKey(privateKey: Data) -> Bool {
        if (privateKey.count != 32) {return false}
        let result = privateKey.withUnsafeBytes { (privateKeyPointer:UnsafePointer<UInt8>) -> Int32 in
            let res = secp256k1_ec_seckey_verify(context!, privateKeyPointer)
            return res
        }
        return result == 1
    }
    
    public static func generatePrivateKey() -> Data? {
        for _ in 0...1024 {
            guard let keyData = SECP256K1.randomBytes(length: 32) else {
                continue
            }
            guard SECP256K1.verifyPrivateKey(privateKey: keyData) else {
                continue
            }
            return keyData
        }
        return nil
    }
    
    public static func unmarshalSignature(signatureData:Data) -> UnmarshaledSignature? {
        if (signatureData.count != 65) {return nil}
        let v = signatureData[64]
        let r = Data(signatureData[0..<32])
        let s = Data(signatureData[32..<64])
        return UnmarshaledSignature(v: v, r: r, s: s)
    }
    
    public static func marshalSignature(v: UInt8, r: [UInt8], s: [UInt8]) -> Data? {
        guard r.count == 32, s.count == 32 else {return nil}
        var completeSignature = Data(bytes: r)
        completeSignature.append(Data(bytes: s))
        completeSignature.append(Data(bytes: [v]))
        return completeSignature
    }
    
    public static func marshalSignature(v: Data, r: Data, s: Data) -> Data? {
        guard r.count == 32, s.count == 32 else {return nil}
        var completeSignature = Data(r)
        completeSignature.append(s)
        completeSignature.append(v)
        return completeSignature
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
    
    internal static func constantTimeComparison(_ lhs: Data, _ rhs:Data) -> Bool {
        guard lhs.count == rhs.count else {return false}
        var difference = UInt8(0x00)
        for i in 0..<lhs.count { // compare full length
            difference |= lhs[i] ^ rhs[i] //constant time
        }
        return difference == UInt8(0x00)
    }
    
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
}
