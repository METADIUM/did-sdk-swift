//
//  MetaWallet.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/01.
//

import UIKit
import web3Swift
import BigInt
import CryptoSwift
import JOSESwift
import JWTsSwift
import VerifiableSwift
import EthereumAddress

public typealias TransactionRecipt = (EthereumClientError?, EthereumTransactionReceipt?) -> Void

public enum MetaTransactionType {
    case createDid
    case addWalletPublicKey
    case removePublicKey
    case removeAssociatedAddress
}

public class MetaWallet: NSObject {
    
    public enum WalletError: Error {
        case noneRegistryAddress(String)
    }
    
    public enum verifyError: Error {
        case networkError
        case noneDidDocument
        case failedVerify
        case noneKid
        case nonePublicKey
    }
    
    var account: EthereumAccount!
    var delegator: MetaDelegator!
    var metaID: String!
    var keyStore: EthereumKeystoreV3?
    var did: String! = ""
    var privateKey: String? = ""
    var didDocument: DiDDocument!

    var transationType: MetaTransactionType!
    
    let dispatchGroup = DispatchGroup()
    
    
    public init(delegator: MetaDelegator, jsonStr: String? = "") {
        super.init()
        
        if !jsonStr!.isEmpty {
            
            let data = jsonStr!.data(using: .utf8)
            
            if let dic = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String : Any] {
                if let private_key = dic!["private_key"] as? String {
                    self.privateKey = private_key
                }
                
                if let did = dic!["did"] as? String {
                    self.did = did
                }
            }
        }
        
        
        self.delegator = delegator
        
        /**
         * 로컬에 저장되어 있는 privateKey로 keystore를 가져온다.
         */
        if !privateKey!.isEmpty {
            do {
                self.keyStore = try EthereumKeystoreV3.init(privateKey: Data.init(hex: privateKey!))
                self.account = try? EthereumAccount.init(keyStore: self.keyStore!)
                
                self.delegator.keyStore = self.keyStore
                
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    
    /**
     secp256k1 지갑 키 생성
     */
    public func createDID() {
        
        do {
            self.keyStore = try EthereumKeystoreV3.init()
            self.account = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            self.delegator.keyStore = self.keyStore!
            
            self.createIdentity()
            
        } catch  {
            print(error.localizedDescription)
        }
    }
    

    /**
     DID 생성
     */
    public func createIdentity() {
        
        if self.keyStore == nil {
            return
        }
        
        let signatureData = try! self.getCreateKeySignature()
        
        self.dispatchGroup.enter()
    
        self.delegator.createIdentityDelegated(signatureData: signatureData) { (type, txID, error) in
            
            if error != nil {
                self.dispatchGroup.leave()
                
                return
            }
            
            self.transationType = .createDid
            
            Thread.sleep(forTimeInterval: 1.2)
            
            self.transactionReceipt(txId: txID!)
        }
        
        self.dispatchGroup.wait()
    }
    
    
    private func transactionReceipt(txId: String) {
        
        self.delegator.ethereumClient.eth_getTransactionReceipt(txHash: txId) { (error, receipt) in
            if error != nil {
                self.dispatchGroup.leave()
                
                return
            }
            
            if receipt == nil {
                self.transactionReceipt(txId: txId)
                
                return
            }
            
            
            if receipt!.status.rawValue == 0 {
                self.dispatchGroup.leave()
                
                return
            }
            
            if self.transationType == .createDid {
                self.metaID = ""
                self.did = ""
                
                self.getEin(receipt: receipt!)
            }
            else if self.transationType == .addWalletPublicKey {
                self.dispatchGroup.leave()
            }
            else if self.transationType == .removePublicKey {
                self.removeAssociated()
            }
            else if self.transationType == .removeAssociatedAddress {
                self.dispatchGroup.leave()
            }
        }
    }
    
    
    public func deleteDID() {
        
        let signatureData = try! self.getRemovePublicKeySign()
        
        self.dispatchGroup.enter()
        
        self.delegator.removePublicKeyDelegated(signatureData: signatureData) { (type, txID, error) in
            if error != nil {
                return
            }
            
            Thread.sleep(forTimeInterval: 0.7)
            
            self.transationType = .removePublicKey
            
            self.transactionReceipt(txId: txID!)
        }
    }
    
    
    
    private func removeAssociated() {
        
        let signData = try! self.getRemoveAssociatedAddressSign()
        
        self.delegator.removeAssociatedAddressDelegated(signatureData: signData) { (type, txID, error) in
            
            if error != nil {
                return
            }
            
            Thread.sleep(forTimeInterval: 0.7)

            self.transationType = .removeAssociatedAddress
            
            self.transactionReceipt(txId: txID!)
        }
    }

    
    /**
     * @param  sign data
     */
    
    public func getSignature(data: Data) -> SignatureData? {
        
        if self.keyStore != nil {
            let account:EthereumAccount! = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            let signature = try? account.sign(data: data)
            
            let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
            let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
            let v = UInt8(signature![64]) + 27
            
            let vStr = String(format: "0x%02x", v)
            print(vStr)
            
            let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
            
            let signatureData = SignatureData(signData: signData!, r: r, s: s, v: vStr)
            
            return signatureData
        }
        
        return nil
    }
    
    
    /**
     * create_identity delegate sign
     */
    public func getCreateKeySignature() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let resolvers = self.delegator.registryAddress!.resolvers
        let providers = self.delegator.registryAddress!.providers
        let identityRegistry = self.delegator.registryAddress!.identityRegistry?.noHexPrefix
        
        let addr = self.keyStore!.addresses?.first?.address
        
        let temp = Data([0x19, 0x00])
        let identity = Data.fromHex(identityRegistry!)
        let msg = KDefine.KCreateIdentity.data(using: .utf8)
        let ass = Data.fromHex(addr!)
        
        let resolverData = NSMutableData()
        for resolver in resolvers! {
            let res = resolver
            let data = Data.fromHex("0x000000000000000000000000" + res.noHexPrefix)
            
            resolverData.append(data!)
        }
        
        
        let providerData = NSMutableData()
        for provider in providers! {
            let pro = provider
            let data = Data.fromHex("0x000000000000000000000000" + pro.noHexPrefix)
            
            providerData.append(data!)
        }
        
        let resolData = resolverData as Data
        let proviData = providerData as Data
        
        
        var timeStamp: Int!
        
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        
        let timeData = self.getInt32Byte(int: BigUInt(Int(timeStamp)))
        
        let data = (temp + identity! + msg! + ass! + ass! + proviData + resolData + timeData).keccak256
        
        self.delegator.signData = data
        
        
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        let signature = try? account?.sign(data: prefixData! + data)
        
        let r = signature!!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature!![64]) + 27
        
        let vStr = String(format: "0x%02x", v)
        print(vStr)
        
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        let signatureData = SignatureData(signData: signData!, r: r, s: s, v: vStr)
        
        return signatureData
    }
    
    
    
    /**
     * add_public_key_delegated sign
     */

    public func getPublicKeySignature() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let publicKeyResolverAddress = self.delegator.registryAddress!.publicKey

        let temp = Data([0x19, 0x00])

        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let address = account?.address
        let publicKey = account?.publicKey

        let msg = KDefine.KAdd_PublicKey.data(using: .utf8)
        let addrdata = Data.fromHex(address!)
        let publicKeyData = Data.fromHex(publicKey!)

        let pubKeyData = Data.fromHex(publicKeyResolverAddress!)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }

        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))

        let data = (temp + pubKeyData! + msg! + addrdata! + publicKeyData! + timeData).keccak256

        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        let signature = try? account!.sign(data: prefixData! + data)

        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27

        let vStr = String(format: "0x%02x", v)
        print(vStr)
        
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        let signatureData = SignatureData(signData: signData!, r: r, s: s, v: vStr)
        
        return signatureData
    }
    

    
    
    public func getRemovePublicKeySign() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let publicKey = self.delegator.registryAddress!.publicKey
       
        let temp = Data([0x19, 0x00])
        let msg = KDefine.KRemove_PubliKey.data(using: .utf8)
        let publickeyData = Data.fromHex(publicKey!)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        let associateAddrData = Data.fromHex((self.keyStore!.addresses?.first!.address)!)
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let data = (temp + publickeyData! + msg! + associateAddrData! + timeData).keccak256
        
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let signature = try? account!.sign(data: prefixData! + data)
       
        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27
        let vStr = String(format: "0x%02x", v)
       
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        let signatureData = SignatureData(signData: signData!, r: r, s: s, v: vStr)
        
        return signatureData
    }
    
    
    public func getRemoveAssociatedAddressSign() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let identityRegistry = self.delegator.registryAddress!.identityRegistry
       
        let temp = Data([0x19, 0x00])
        let msg = KDefine.kRemove_Address_MyIdentity.data(using: .utf8)
        let identityRegistryData = Data.fromHex(identityRegistry!)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        let associateAddrData = Data.fromHex((self.keyStore!.addresses?.first!.address)!)
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let ein = self.getDid().replacingOccurrences(of: self.delegator.didPrefix, with: "").withHexPrefix
        let einData = self.getInt32Byte(int: BigUInt(hex: ein)!)
        
        let data = (temp + identityRegistryData! + msg! + einData + associateAddrData! + timeData).keccak256
        
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let signature = try? account!.sign(data: prefixData! + data)
       
        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27
        let vStr = String(format: "0x%02x", v)
       
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        let signatureData = SignatureData(signData: signData!, r: r, s: s, v: vStr)
        
        return signatureData
    }
    
    
    
    
    private func getEin(receipt: EthereumTransactionReceipt) {
        
        let result = MHelper.getEvent(receipt: receipt, string: "{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"initiator\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"ein\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"recoveryAddress\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"associatedAddress\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"providers\",\"type\":\"address[]\"},{\"indexed\":false,\"name\":\"resolvers\",\"type\":\"address[]\"},{\"indexed\":false,\"name\":\"delegated\",\"type\":\"bool\"}],\"name\":\"IdentityCreated\",\"type\":\"event\"}")
        
        if (result.object(forKey: "ein") as! String).count > 0 {
            
            let ein = BigUInt(hex: (result.object(forKey: "ein") as? String)!)
            self.metaID = self.getInt32Byte(int: ein!).toHexString().withHexPrefix
            
            print(self.metaID)
            
            let signatureData = try! self.getPublicKeySignature()
            
            self.delegator.addPublicKeyDelegated(signatureData: signatureData) { (type, txId, error) in
                
                if error != nil {
                    self.dispatchGroup.leave()
                    
                    return
                }
                
                Thread.sleep(forTimeInterval: 0.7)
                
                self.transationType = .addWalletPublicKey
                self.transactionReceipt(txId: txId!)
            }
        }
    }
    
    
    public func existDid() throws -> Bool {
        
        var isEin: Bool = false
        
        let semaPhore = DispatchSemaphore(value: 0)
        
        let identity = self.delegator.registryAddress?.identityRegistry
        let contract = EthereumJSONContract.init(json:
            """
            [{
                  "constant": true,
                  "inputs": [
                    {
                      "name": "_address",
                      "type": "address"
                    }
                  ],
                  "name": "hasIdentity",
                  "outputs": [
                    {
                      "name": "",
                      "type": "bool"
                    }
                  ],
                  "payable": false,
                  "stateMutability": "view",
                  "type": "function"
                }]
            """, address: (EthereumAddress(identity!)!))
        
        let transaction = try? contract!.transaction(function: "hasIdentity", args: [(self.keyStore?.addresses?.first!.address)!])
        
        self.delegator.ethereumClient!.eth_call(transaction!) { (error, data) in
            //id data가 없을 경우
            if data == nil || data!.isEqual("0x") {
                NSLog("NO ID DATA ERROR")
                
                return
            }
            
            do {
                let decoded = try ABIDecoder.decodeData(data!, types: ["bool"]) as! [String]
                print(decoded)

                let status = decoded[0]
                
                //id data가 있을 경우
                if status.isEqual("0x01") {
                    isEin = true
                    
                } else {
                    NSLog("NO EIN ERROR")

                }
            } catch let error {
                
                print(error.localizedDescription)
            }
            
            semaPhore.signal()
        }
        
        semaPhore.wait()
        
        return isEin
    }
    
    
    
    static public func getDiDDocument(did: String? = "", resolverUrl: String) throws -> DiDDocument? {
            
        let semaPhore = DispatchSemaphore(value: 0)
        
        var didDocument: DiDDocument?
        
        MetaWallet.reqDiDDocument(did: did!, resolverUrl: resolverUrl) { (document, error) in
            if error != nil {
                semaPhore.signal()
                
                return
            }
            
            didDocument = document
            
            semaPhore.signal()
        }
        
        semaPhore.wait()
        
        if didDocument == nil {
            throw verifyError.noneDidDocument
        }
        
        return didDocument
    }
    
    
    
    static public func verify(jwt: JWSObject, resolverUrl: String) throws -> Bool {
        
        let kid = jwt.header.kid
        
        let arr = kid?.components(separatedBy: "#")
        
        if arr!.count > 0 {
            let did = arr![0]
            
            let didDocument = try! MetaWallet.getDiDDocument(did: did, resolverUrl: resolverUrl)
            
            if didDocument == nil {
                throw verifyError.noneDidDocument
            }
            
            let publicKey = didDocument!.publicKey
            
            guard let publicKeyHex = (publicKey![0] as NSDictionary)["publicKeyHex"] as? String else {
                throw verifyError.nonePublicKey
            }
            
            let pubKey = Data.fromHex(publicKeyHex)
            
            do {
                let verified = try jwt.verify(verifier: ECDSAVerifier.init(publicKey: pubKey!))
                
                return verified
            }
            catch {
                throw verifyError.failedVerify
            }
            
        }
        
        throw verifyError.noneKid
    }
    
    
    /**
     * Get didDocument
     */
    static func reqDiDDocument(did: String, resolverUrl: String, complection: @escaping(DiDDocument?, Error?) -> Void) {
        
        DataProvider.reqDidDocument(did: did, url: resolverUrl) { (response, result, error) in
            if error != nil {
                return complection(nil, error)
            }
            
            if let dic = result as? NSDictionary {
                
                if let dicDocu = dic["didDocument"] as? Dictionary<String, Any> {
                    
                    let didDocument = DiDDocument.init(dic: dicDocu)
                    
                    return complection(didDocument, nil)
                }
                
                
                return complection(nil, nil)
            }
        }
    }
    
    

    
    /**
     * Sign verifiable credential, presntation
     */
    public func sign(verifiable: Verifiable, nonce: String?, claim: JWT?) throws -> JWSObject? {
        
        if let verify = verifiable as? VerifiableCredential {
            verify.issuer = self.getDid()
            
            let privateKey = self.getInt32Byte(int: BigUInt(hex:self.account.privateKey)!)
            
            let jwsObj = try verify.sign(kid: self.getKid(), nonce: nonce, signer: ECDSASigner.init(privateKey: privateKey), baseClaims: claim)
            
            return jwsObj
        }
        
        if let verify = verifiable as? VerifiablePresentation {
            verify.holder = self.getDid()
            
            let privateKey = self.getInt32Byte(int: BigUInt(hex:self.account.privateKey)!)
            
            return try verify.sign(kid: self.getKid(), nonce: nonce, signer: ECDSASigner.init(privateKey: privateKey), baseClaims: claim)
        }
        
        return nil
    }
    
    
    
    /**
     * Issue verifiable credentail
     */
    public func issueCredential(types: [String], id: String?, nonce: String?, issuanceDate: Date?, expirationDate: Date?, ownerDid: String, subjects: [String: Any]) throws -> JWSObject? {
        
        let vc = try? VerifiableCredential.init()
        vc!.addTypes(types: types)
        
        if id != nil {
            vc!.id = id
        }
        
        if issuanceDate != nil {
            vc?.issuanceDate = issuanceDate
        }
        
        if expirationDate != nil {
            vc?.expirationDate = expirationDate
        }
        
        let credentialSubject = NSMutableDictionary.init(dictionary: subjects)
        credentialSubject.setValue(ownerDid, forKey: "id")
        
        vc?.credentialSubject = credentialSubject
        
        return try self.sign(verifiable: vc!, nonce: nonce, claim: nil)
    }
    
    
    /**
     * Issue verifiable presentation
     */
    public func issuePresentation(types: [String], id: String?, nonce: String?, issuanceDate: Date?, expirationDate: Date?, vcList: [String]) throws -> JWSObject? {
        let vp = try? VerifiablePresentation.init()
        vp?.addTypes(types: types)
        
        if id != nil {
            vp?.id = id
        }
        
        for vc in vcList {
            vp?.addVerifiableCredential(verifiableCredential: vc)
        }
        
        let claims = JWT()
        
        if issuanceDate != nil {
            claims.notBeforeTime = issuanceDate
            claims.issuedAt = issuanceDate
        }
        
        if expirationDate != nil {
            claims.expirationTime = expirationDate
        }
        
        return try self.sign(verifiable: vp!, nonce: nonce, claim: claims)
    }
    
    
    
    /**
     * did, privatekey의 json String
     */
    public func toJson() -> String? {
        
        if self.keyStore != nil {
            
            let account = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            let dic = ["did": self.getDid(), "private_key": account!.privateKey]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                
                let jsonStr = String(data: jsonData, encoding: .utf8)
                
                return jsonStr
            }
            catch {
                return nil
            }
        }
        
        return nil
    }
    
    
    
    
    public func getKey() -> MetadiumKey? {
        
        guard let keyStore = self.keyStore else {
            return nil
        }
        
        let account = try? EthereumAccount.init(keyStore: keyStore)
        
        let key = MetadiumKey()
        key.address = account?.address
        key.privateKey = account?.privateKey
        key.publicKey = account?.publicKey
        
        return key
    }
    
    
    public func getDid() -> String {
        
        if !self.did.isEmpty {
            return self.did
        }
        
        if self.metaID != nil && !self.metaID.isEmpty {
            
            self.did = self.delegator.didPrefix + self.metaID.noHexPrefix
            
            print(self.did)
            
            return self.did
        }
        
        return self.did
    }
    
    
    public func getKid() -> String {
        
        var kid = ""
        let did = getDid()
        
        if !did.isEmpty {
            kid = did + "#MetaManagementKey#" + self.getAddress().lowercased().noHexPrefix
        }
        
        return kid
    }
    
    
    public func getAddress() -> String {
        
        var address: String = ""
        
        
        if self.keyStore != nil  {
            address = (self.keyStore?.addresses?.first!.address)!
        }
        
        return address
    }
    
    
    
    private func getInt32Byte(int: BigUInt) -> Data {
        let bytes = int.bytes // should be <= 32 bytes
        let byte = [UInt8](repeating: 0x00, count: 32 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
    
}
