//
//  EthereumAccount.swift
//  web3swift
//
//  Created by Julien Niset on 15/02/2018.
//  Copyright © 2018 Argent Labs Limited. All rights reserved.
//

import Foundation

protocol EthereumAccountProtocol {
    var address: String { get }
    
    // For Keystore handling
//    init?(keyStorage: EthereumKeyStorageProtocol, keystorePassword: String) throws
//    static func create(keyStorage: EthereumKeyStorageProtocol, keystorePassword password: String) throws -> EthereumAccount
//
//    // For non-Keystore formats. This is not recommended, however some apps may wish to implement their own storage.
//    init(keyStorage: EthereumKeyStorageProtocol) throws
    
    init(keyStore: EthereumKeystoreV3) throws
    
    func sign(data: Data) throws -> Data
    func sign(hash: String) throws -> Data
    func sign(hex: String) throws -> Data
    func sign(message: Data) throws -> Data
    func sign(message: String) throws -> Data
    func sign(msgData: Data) throws -> SignedData
    
    func sign(_ transaction: EthereumTransaction) throws -> SignedTransaction
}

public enum EthereumAccountError: Error {
    case createAccountError
    case loadAccountError
    case signError
}

public class EthereumAccount: EthereumAccountProtocol {
    private let privateKeyData: Data
    private let publicKeyData: Data
    
    
    
    public lazy var privateKey: String = {
        return self.privateKeyData.hexString
    }()
    
    public lazy var publicKey: String = {
        return self.publicKeyData.hexString
    }()
    
    public lazy var address: String = {
        return KeyUtil.generateAddress(from: self.publicKeyData)
    }()
    
    required public init(keyStorage: EthereumKeyStorageProtocol, keystorePassword password: String) throws {
        
        do {
            let data = try keyStorage.loadPrivateKey()
            if let decodedKey = try? KeystoreUtil.decode(data: data, password: password) {
                self.privateKeyData = decodedKey
                self.publicKeyData = try KeyUtil.generatePublicKey(from: decodedKey)
            } else {
                print("Error decrypting key data")
                throw EthereumAccountError.loadAccountError
            }
        } catch {
           throw EthereumAccountError.loadAccountError
        }
    }
    
    required public init(keyStore: EthereumKeystoreV3) throws {
        
        do {
            let privateKey = try keyStore.UNSAFE_getPrivateKeyData(password: "web3swift", account: keyStore.addresses!.first!)
            
            self.privateKeyData = privateKey
            self.publicKeyData = try KeyUtil.generatePublicKey(from: privateKey)
            
        } catch {
            throw EthereumAccountError.loadAccountError
        }
    }
    
    /*
    required public init(keyStorage: EthereumKeyStorageProtocol) throws {
        do {
            let data = try keyStorage.loadPrivateKey()
            self.privateKeyData = data
            self.publicKeyData = try KeyUtil.generatePublicKey(from: data)
        } catch {
            throw EthereumAccountError.loadAccountError
        }
    }
    
    public static func create(keyStorage: EthereumKeyStorageProtocol, keystorePassword password: String) throws -> EthereumAccount {
        guard let privateKey = KeyUtil.generatePrivateKeyData() else {
            throw EthereumAccountError.createAccountError
        }
        
        do {
            let encodedData = try KeystoreUtil.encode(privateKey: privateKey, password: password)
            try keyStorage.storePrivateKey(key: encodedData)
            return try self.init(keyStorage: keyStorage, keystorePassword: password)
        } catch {
            throw EthereumAccountError.createAccountError
        }
    }
 */
    
    public func sign(data: Data) throws -> Data {
        return try KeyUtil.sign(message: data, with: self.privateKeyData, hashing: true)
    }
    
    public func sign(hex: String) throws -> Data {
        if let data = Data.init(hex: hex) {
            return try KeyUtil.sign(message: data, with: self.privateKeyData, hashing: true)
        } else {
            throw EthereumAccountError.signError
        }
    }
    
    public func sign(hash: String) throws -> Data {
        if let data = hash.hexData {
            return try KeyUtil.sign(message: data, with: self.privateKeyData, hashing: false)
        } else {
            throw EthereumAccountError.signError
        }
    }
    
    public func sign(message: Data) throws -> Data {
        return try KeyUtil.sign(message: message, with: self.privateKeyData, hashing: false)
    }
    
    public func sign(message: String) throws -> Data {
        if let data = message.data(using: .utf8) {
            return try KeyUtil.sign(message: data, with: self.privateKeyData, hashing: true)
        } else {
            throw EthereumAccountError.signError
        }
    }
    
    
    public func sign(msgData: Data) throws -> SignedData {
        let signature = try KeyUtil.sign(message: msgData, with: self.privateKeyData, hashing: false)
        
        let r = signature.subdata(in: 0..<32)
        let s = signature.subdata(in: 32..<64)
        
        let v = Int(signature[64])
        
        return SignedData(v: v, r: r, s: s)
    }
}
