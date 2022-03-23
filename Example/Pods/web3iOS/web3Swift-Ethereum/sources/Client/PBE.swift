//
//  BIP39BackupFile.swift
//  BIP39BackupFile
//
//  Created by 전영배 on 2020/05/26.
//  Copyright © 2020 전영배. All rights reserved.
//
import Foundation
import CryptoSwift

public struct ScryptKdfParams: Decodable, Encodable {
    var salt: String
    var dklen: Int
    var n: Int?
    var p: Int?
    var r: Int?
}

public struct CipherParams: Decodable, Encodable {
    var iv: String
}

public struct CryptoParams: Decodable, Encodable {
    var ciphertext: String
    var cipherparams: CipherParams
    var kdfparams: ScryptKdfParams
    var mac: String
}

//func scrypt (password: String, salt: Data, length: Int, N: Int, R: Int, P: Int) -> Data? {
//    guard let passwordData = password.data(using: .utf8) else {return nil}
//    guard let deriver = try? Scrypt(password: passwordData.bytes, salt: salt.bytes, dkLen: length, N: N, r: R, p: P) else {return nil}
//    guard let result = try? deriver.calculate() else {return nil}
//    return Data(result)
//}

public enum PBEError: Error {
    case noEntropyError
    case keyDerivationError
    case aesError
    case invalidAccountError
    case invalidPasswordError
    case encryptionError(String)
}


public class PBE {
    public var cryptoParams: CryptoParams?

    public func decrypt(password: String) throws -> Data? {
        return try self.decryptData(password)
    }
        
    public convenience init?(_ jsonString: String) throws {
        guard let jsonData = jsonString.data(using: .utf8) else {return nil}
        try self.init(jsonData)
    }
        
    public convenience init?(_ jsonData: Data) throws {
        let cryptoParams = try JSONDecoder().decode(CryptoParams.self, from: jsonData)
        self.init(cryptoParams)
    }
        
    public init?(_ cryptoParams: CryptoParams) {
        self.cryptoParams = cryptoParams
    }
        
    public init? (data: Data, password: String = "web3swift") throws {
        try encryptDataToStorage(password, data: data)
    }
        
        
    fileprivate func encryptDataToStorage(_ password: String, data: Data?, dkLen: Int=32, N: Int = 4096, R: Int = 6, P: Int = 1) throws {
        if (data == nil) {
            throw PBEError.encryptionError("Encryption without key data")
        }
        let saltLen = 32;
        guard let saltData = Data.randomBytes(length: saltLen) else {
            throw PBEError.noEntropyError
        }
        guard let derivedKey = scrypt(password: password, salt: saltData, length: dkLen, N: N, R: R, P: P) else {
            throw PBEError.keyDerivationError
        }
        let last16bytes = Data(derivedKey[(derivedKey.count - 16)...(derivedKey.count-1)])
        let encryptionKey = Data(derivedKey[0...15])
        guard let IV = Data.randomBytes(length: 16) else {
            throw PBEError.noEntropyError
        }
        let aesCipher = try? AES(key: encryptionKey.bytes, blockMode: CBC(iv: IV.bytes), padding: .pkcs5)
        if aesCipher == nil {
            throw PBEError.aesError
        }
        guard let encryptedKey = try aesCipher?.encrypt(data!.bytes) else {
            throw PBEError.aesError
        }
        let encryptedKeyData = Data(encryptedKey)
        
        var dataForMAC = Data()
        dataForMAC.append(last16bytes)
        dataForMAC.append(encryptedKeyData)
        let mac = dataForMAC.sha3(.keccak256)
        let kdfparams = ScryptKdfParams(salt: saltData.base64EncodedString(), dklen: dkLen, n: N, p: P, r: R)
        let cipherparams = CipherParams(iv: IV.base64EncodedString())
        let crypto = CryptoParams(ciphertext: encryptedKeyData.base64EncodedString(), cipherparams: cipherparams, kdfparams: kdfparams, mac: mac.base64EncodedString())
        
        self.cryptoParams = crypto
    }
        
    fileprivate func decryptData(_ password: String) throws -> Data? {
        guard let cryptoParams = self.cryptoParams else {
            return nil
        }
        guard let saltData = Data(base64Encoded: cryptoParams.kdfparams.salt) else {return nil}
        let derivedLen = cryptoParams.kdfparams.dklen
        var passwordDerivedKey:Data?
        guard let N = cryptoParams.kdfparams.n else {return nil}
        guard let P = cryptoParams.kdfparams.p else {return nil}
        guard let R = cryptoParams.kdfparams.r else {return nil}
        passwordDerivedKey = scrypt(password: password, salt: saltData, length: derivedLen, N: N, R: R, P: P)
        guard let derivedKey = passwordDerivedKey else {return nil}
        var dataForMAC = Data()
        let derivedKeyLast16bytes = Data(derivedKey[(derivedKey.count - 16)...(derivedKey.count - 1)])
        dataForMAC.append(derivedKeyLast16bytes)
        guard let cipherText = Data(base64Encoded: cryptoParams.ciphertext) else {return nil}
        dataForMAC.append(cipherText)
        let mac = dataForMAC.sha3(.keccak256)
        guard let calculatedMac = Data(base64Encoded: cryptoParams.mac), mac.constantTimeComparisonTo(calculatedMac) else {return nil}
        let decryptionKey = derivedKey[0...15]
        guard let IV = Data(base64Encoded: cryptoParams.cipherparams.iv) else {return nil}
        var decryptedPK:Array<UInt8>?
        guard let aesCipher = try? AES(key: decryptionKey.bytes, blockMode: CBC(iv: IV.bytes), padding: .pkcs5) else {return nil}
        decryptedPK = try? aesCipher.decrypt(cipherText.bytes)
        guard decryptedPK != nil else {return nil}
        return Data(decryptedPK!)
    }
    
    public func serialize() throws -> Data? {
        guard let params = self.cryptoParams else {return nil}
        let data = try JSONEncoder().encode(params)
        return data
    }
}
