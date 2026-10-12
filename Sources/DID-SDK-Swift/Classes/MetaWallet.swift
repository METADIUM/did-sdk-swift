//
//  MetaWallet.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/01.
//

import UIKit
import web3swift
import Web3Core
import BigInt
import CryptoSwift
import secp256k1

public enum MetaTransactionType {
    case createDid
    case addWalletPublicKey
    case removePublicKey
    case removeAssociatedAddress
}

public enum MetaWalletError: Error {
    /// 서명에 필요한 정보(registry 주소, 키, DID)가 아직 없다.
    case notReady
    /// DID 가 없어 kid 를 만들 수 없다.
    case noDid
    /// 서명이 지갑의 키로 만들어진 것이 아니다. kid 는 지갑의 키를 가리킨다.
    case signerMismatch
    /// 개인키를 가진 지갑에 외부 서명자로 DID 를 생성하려 했다. 개인키 모드와 외부 서명자 모드는 함께 쓸 수 없다.
    case conflictingKeyMode
    /// 트랜잭션 receipt 를 받지 못했다.
    case receiptNotFound
    /// create_identity 트랜잭션에서 IdentityCreated 이벤트를 찾지 못했다.
    /// 트랜잭션은 성공했으므로 identity 가 체인에 이미 생성되었을 수 있다. DID 를 알 수 없고 되돌리지 않는다. existDid 로 확인한다.
    case eventNotFound
    /// DID(identity)는 생성됐지만 공개키 등록이 끝나지 않았다.
    case partialCreation(did: String, underlying: Error?)
}

public enum verifyError: Error {
    case networkError
    case noneDidDocument
    case failedVerify
    case noneKid
    case nonePublicKey
}

public class MetaWallet: NSObject {

    var delegator: MetaDelegator!
    var metaID: String = ""
    var did: String = ""
    var privateKey: Data?
    /// 외부 키 보관 서비스를 사용하는 경우의 서명자. 설정되면 privateKey 는 사용하지 않는다.
    var signer: MetaKeySigner?
    /// signer 의 공개키. 0x04 접두 없는 64바이트 X||Y. 지갑을 만들 때 한 번 검증해서 보관한다.
    var signerPublicKey: Data?
    var didDocument: DiDDocument!

    var transationType: MetaTransactionType!
    var tryReceiptCount: Int = 0
    
    var dispatchGroup = DispatchGroup()
    
    public init(delegator: MetaDelegator, jsonStr: String = "") {
        super.init()
        
        if !jsonStr.isEmpty {
            
            let data = jsonStr.data(using: .utf8)
            
            guard let res = try? JSONSerialization.jsonObject(with: data!, options: []),
                  let dic = res as? [String: Any] else {
                return
            }
            
            if let private_key = dic["private_key"] as? String {
                self.privateKey = Data.init(hex: private_key)
            }
            
            if let did = dic["did"] as? String {
                self.did = did
            }
        }
        
        self.configure(delegator: delegator)
    }
    
    
    /**
     외부 키 보관 서비스에 개인키가 있는 지갑.
     - Parameters:
       - delegator: MetaDelegator
       - signer: 외부 키 보관 서비스 서명자
       - did: 이미 생성된 DID. 새로 생성하는 경우에는 비워두고 createDID(signer:completion:) 를 호출한다.
     - Throws: 공개키 형식이 틀리거나 secp256k1 곡선 위의 점이 아니면 MetaKeySignerError.invalidPublicKey
     */
    public init(delegator: MetaDelegator, signer: MetaKeySigner, did: String = "") throws {
        super.init()
        
        // 공개키 형식이 틀리거나 곡선 위의 점이 아니면 지갑을 만들지 않는다.
        self.signerPublicKey = try ExternalSignatureUtils.rawPublicKey(signer.publicKey)
        self.signer = signer
        self.did = did
        
        self.configure(delegator: delegator)
    }
    
    
    private func configure(delegator: MetaDelegator) {
        self.delegator = delegator
        
        var chainID = KDefine.kMeta_Main_ChainID
        
        if self.delegator.nodeUrl == KDefine.kMeta_Test_Node_URL {
            chainID = KDefine.kMeta_Test_ChainID
        }
        
        self.delegator.getAllServiceAddress()
        
        let url = URL(string: self.delegator.nodeUrl!)
        
        self.delegator.node = Web3.init(provider: Web3HttpProvider.init(url: url!, network: .Custom(networkID: BigUInt(chainID)!)))
        
        if self.privateKey != nil || self.signer != nil, let publicKey = self.getPublicKey() {
            self.delegator.publicKey = publicKey
        }
    }
    
    
    /**
     secp256k1 지갑 키 생성
     */
    public func createDID(completion: @escaping (TransactionReceipt? , Error?) -> Void) {
        // 외부 서명자를 가진 지갑은 로컬 키를 만들지 않고 서명자로 생성한다.
        if let signer = self.signer {
            self.createDID(signer: signer, completion: completion)
            return
        }
        
        self.tryReceiptCount = 0
        
        self.generateKey()
        
        Task {
            await self.createIdentity() { receipt, error in
                
                if error != nil {
                    completion(nil, error)
                    return
                }
                
                guard let receipt = receipt else {
                    completion(nil, nil)
                    return
                }
                
                completion(receipt, nil)
            }
        }
    }
    
    
    /**
     외부 키 보관 서비스의 키로 DID 를 생성한다. 개인키는 SDK 로 전달되지 않는다.
     */
    public func createDID(signer: MetaKeySigner, completion: @escaping (TransactionReceipt? , Error?) -> Void) {
        
        // 개인키를 가진 지갑을 외부 서명자로 바꾸지 않는다.
        if self.privateKey != nil {
            Task { completion(nil, MetaWalletError.conflictingKeyMode) }
            return
        }
        
        let publicKey: Data
        
        do {
            publicKey = try ExternalSignatureUtils.rawPublicKey(signer.publicKey)
        } catch {
            Task { completion(nil, error) }
            return
        }
        
        self.tryReceiptCount = 0
        
        self.signer = signer
        self.signerPublicKey = publicKey
        self.delegator.publicKey = self.getPublicKey()
        
        Task {
            await self.createIdentity(completion: completion)
        }
    }
    
    
    public func deleteDID(completion: @escaping(TransactionReceipt?, Error?) -> Void) {
        
        Task {
            await self.deleteDID() { receipt, error in
                if error != nil {
                    completion(nil, error)
                    return
                }
                
                guard let receipt = receipt else {
                    completion(nil, nil)
                    return
                }
                
                completion(receipt, nil)
            }
        }

    }
    
    private func generateKey() {
        guard let privateKey = Web3Core.SECP256K1.generatePrivateKey() else {
            return
        }
        
        self.privateKey = privateKey
        
        self.delegator.publicKey = self.getPublicKey()
    }
    
    
    private func getPublicKeyData() -> Data? {
        if self.signer != nil {
            guard let raw = self.signerPublicKey else {
                return nil
            }
            
            return Data([0x04]) + raw
        }
        
        guard let privateKey = self.privateKey,
              let pubKeyData = Web3Core.SECP256K1.privateToPublic(privateKey: privateKey, compressed: false) else {
            return nil
        }
        
        return pubKeyData
    }
    
    
    
    /**
     privateKey로 publicKey를 가져온다.
     */
    private func getPublicKey() -> String? {
        
        if self.signer != nil {
            guard let raw = self.signerPublicKey else {
                return nil
            }
            
            return "0x" + raw.toHexString()
        }
        
        guard let privateKey = self.privateKey,
              let pubKeyData = Web3Core.SECP256K1.privateToPublic(privateKey: privateKey, compressed: false) else {
            return nil
        }
         
        var publicKey = pubKeyData.toHexString()
        
        if pubKeyData.bytes[0] == 0x04 && publicKey.hasPrefix("04") {
            publicKey = "0x" + String(publicKey.dropFirst(2))
        }
        
        return publicKey
    }
    

    /**
     DID 생성
     */
    public func createIdentity(completion: @escaping(TransactionReceipt?, Error?) -> Void) async {
        
        let signatureData: SignatureData
        
        do {
            signatureData = try self.createKeySignature()
        } catch {
            completion(nil, error)
            return
        }
        
        self.delegator.createIdentityDelegated(signatureData: signatureData) { (type, txID, error) in
            
            if error != nil {
                completion(nil, error)
                return
            }
            
            guard let txID = txID else {
                completion(nil, MetaWalletError.notReady)
                return
            }
            
            Task {
                self.transationType = type
                await self.transactionReceipt(txId: txID) { receipt in
                    guard let receipt = receipt else {
                        completion(nil, MetaWalletError.receiptNotFound)
                        return
                    }
                    
                    self.metaID = ""
                    self.did = ""
                    
                    self.getEin(receipt: receipt) { receipt, error in
                        completion(receipt, error)
                    }
                }
            }
        }
    }

    
    
    private func transactionReceipt(txId: String, completion: @escaping (TransactionReceipt?) -> Void) async {

        guard self.tryReceiptCount < 10 else {
            return completion(nil)
        }
        
        guard let receipt = try? await self.delegator.node.eth.transactionReceipt(Data(hex: txId)) else {
                
            Task {
                //1초 간격으로 호출
                try await Task.sleep(nanoseconds: 1_000_000_000)
                self.tryReceiptCount = self.tryReceiptCount + 1
                await self.transactionReceipt(txId: txId, completion: completion)
            }
            
            return
        }
                                    
        self.tryReceiptCount = 0
        
        if receipt.status == .failed {
            print("transactionReceipt_failed")
        }
        
        completion(receipt)
    }
    
    
    public func deleteDID(completion: @escaping (TransactionReceipt?, Error?) -> Void) async {
        self.tryReceiptCount = 0
        
        let signatureData: SignatureData
        
        do {
            signatureData = try self.removePublicKeySignature()
        } catch {
            completion(nil, error)
            return
        }
        
        self.delegator.removePublicKeyDelegated(signatureData: signatureData) { (type, txID, error) in
            if error != nil {
                completion(nil, error)
                return
            }
            
            guard let txID = txID else {
                completion(nil, MetaWalletError.notReady)
                return
            }
            
            self.transationType = type
            
            print("removePublicKey_txID: \(txID)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    await self.transactionReceipt(txId: txID) { receipt in
                        
                        guard let receipt = receipt else {
                            completion(nil, MetaWalletError.receiptNotFound)
                            return
                        }
                        
                        print("removeTransactionReceipt:\(receipt.status)")
                        
                        completion(receipt, nil)
                    }
                }
            }
            
        }
    }
    
    
    private func removeAssociated() {
        guard let signData = self.getRemoveAssociatedAddressSign() else {
            return
        }
        
        self.delegator.removeAssociatedAddressDelegated(signatureData: signData) { (type, txID, error) in
            
            if error != nil {
                return
            }

            self.transationType = type
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    await self.transactionReceipt(txId: txID!) { receipt in
                        
                    }
                }
            }
        }
    }

    
    private func signPersonalData(data: Data) throws -> Data {
        
        if let signer = self.signer {
            guard let hash = ExternalSignatureUtils.personalMessageHash(data) else {
                throw MetaWalletError.notReady
            }
            
            // 서명자의 오류를 그대로 전달한다.
            return try ExternalSignatureUtils.sign65(digest: hash, signer: signer)
        }
        
        guard let privateKey = self.privateKey,
              let publicKey = self.getPublicKey(),
              let keyStore = PlainKeystore(privateKey: privateKey.toHexString()),
              let address = MetaUtils.getAddress(publicKey: publicKey),
              let account = EthereumAddress(address) else {
            throw MetaWalletError.notReady
        }
        
        guard let signature = try Web3Signer.signPersonalMessage(data, keystore: keyStore, account: account, password: "web3swift") else {
            throw MetaWalletError.notReady
        }
        
        return signature
    }

    
    /**
     * 서명 오류를 던지는 버전. 서명자(키 보관 서비스)의 오류를 그대로 전달한다.
     */
    func signature(data: Data) throws -> SignatureData {
        let signature = try self.signPersonalData(data: data)
        
        let r = signature.subdata(in: 0..<32).toHexString()
        let s = signature.subdata(in: 32..<64).toHexString()
        let v = String(format: "%02x", UInt8(signature[64]))
        
        let signData = (r + s + v).data(using: .utf8)
        
        return SignatureData(signData: signData!, r: r.addHexPrefix(), s: s.addHexPrefix(), v: v.addHexPrefix())
    }
    
    
    /**
     * @param  sign data
     */
    
    public func getSignature(data: Data) -> SignatureData? {
        return try? self.signature(data: data)
    }
    
    
    /**
     * create_identity delegate sign
     */
    func createKeySignature() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw MetaWalletError.notReady
        }
        
        let resolvers = self.delegator.registryAddress!.resolvers
        let providers = self.delegator.registryAddress!.providers
        let identityRegistry = self.delegator.registryAddress!.identityRegistry?.stripHexPrefix()
        
        guard let publicKey = self.getPublicKey(),
              let addr = MetaUtils.getAddress(publicKey: publicKey) else {
            throw MetaWalletError.notReady
        }
        
        let temp = Data([0x19, 0x00])
        let identity = Data.fromHex(identityRegistry!)
        let msg = KDefine.KCreateIdentity.data(using: .utf8)
        let ass = Data.fromHex(addr)
        
        let resolverData = NSMutableData()
        for resolver in resolvers! {
            let res = resolver
            let data = Data.fromHex("0x000000000000000000000000" + res.stripHexPrefix())
            
            resolverData.append(data!)
        }
        
        
        let providerData = NSMutableData()
        for provider in providers! {
            let pro = provider
            let data = Data.fromHex("0x000000000000000000000000" + pro.stripHexPrefix())
            
            providerData.append(data!)
        }
        
        let resolData = resolverData as Data
        let proviData = providerData as Data
        
        var timeStamp: Int = 0
        
        let semaPhore = DispatchSemaphore(value: 0)
        
        self.delegator.getLastBlockTimeStamp(completion: { timestamp in
            timeStamp = timestamp
            
            semaPhore.signal()
        })
        
        semaPhore.wait()
        
        let timeData = self.getInt32Byte(int: BigUInt(Int(timeStamp)))
        
        let data = (temp + identity! + msg! + ass! + ass! + proviData + resolData + timeData).sha3(.keccak256)
        
        return try self.signature(data: data)
    }
    
    
    
    /**
     * add_public_key_delegated sign
     */

    func publicKeySignature() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw MetaWalletError.notReady
        }
        
        guard let publicKey = self.getPublicKey(),
              let address = MetaUtils.getAddress(publicKey: publicKey) else {
            throw MetaWalletError.notReady
        }
        
        let publicKeyResolverAddress = self.delegator.registryAddress!.publicKey
        let temp = Data([0x19, 0x00])

        let msg = KDefine.KAdd_PublicKey.data(using: .utf8)
        let addrdata = Data.fromHex(address)
        let publicKeyData = Data.fromHex(publicKey)

        let pubKeyData = Data.fromHex(publicKeyResolverAddress!)
        
        var timeStamp: Int = 0
        
        let semaPhore = DispatchSemaphore(value: 0)
        
        self.delegator.getLastBlockTimeStamp(completion: { timestamp in
            timeStamp = timestamp
            
            semaPhore.signal()
        })
        
        semaPhore.wait()

        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))

        let data = (temp + pubKeyData! + msg! + addrdata! + publicKeyData! + timeData).sha3(.keccak256)

        return try self.signature(data: data)
    }
    

    
    
    func removePublicKeySignature() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw MetaWalletError.notReady
        }
        
        guard let address = self.getWalletAddress() else {
            throw MetaWalletError.notReady
        }
        
        let publicKey = self.delegator.registryAddress!.publicKey
       
        let temp = Data([0x19, 0x00])
        let msg = KDefine.KRemove_PubliKey.data(using: .utf8)
        let publickeyData = Data.fromHex(publicKey!)
        
        var timeStamp: Int!
        
        let semaPhore = DispatchSemaphore(value: 0)
        
        self.delegator.getLastBlockTimeStamp(completion: { timestamp in
            timeStamp = timestamp
            
            semaPhore.signal()
        })
        
        semaPhore.wait()
        
        let associateAddrData = Data.fromHex(address)
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let data = (temp + publickeyData! + msg! + associateAddrData! + timeData).sha3(.keccak256)
        
        return try self.signature(data: data)
    }
    
    
    func removeAssociatedAddressSignature() throws -> SignatureData {
        
        if self.delegator.registryAddress == nil {
            throw MetaWalletError.notReady
        }
                
        guard let address = self.getWalletAddress() else {
            throw MetaWalletError.notReady
        }
        
        let identityRegistry = self.delegator.registryAddress!.identityRegistry
       
        let temp = Data([0x19, 0x00])
        let msg = KDefine.kRemove_Address_MyIdentity.data(using: .utf8)
        let identityRegistryData = Data.fromHex(identityRegistry!)
        
        var timeStamp: Int = 0
        
        DispatchQueue.global().sync {
            self.delegator.getLastBlockTimeStamp(completion: { timestamp in
                timeStamp = timestamp
            })
        }
        
        let associateAddrData = Data.fromHex(address)
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let ein = self.getDid().replacingOccurrences(of: self.delegator.didPrefix, with: "").addHexPrefix()
        let einData = self.getInt32Byte(int: BigUInt(ein)!)
        
        let data = (temp + identityRegistryData! + msg! + einData + associateAddrData! + timeData).sha3(.keccak256)
        
        return try self.signature(data: data)
    }
    
    

    public func getCreateKeySignature() -> SignatureData? {
        return try? self.createKeySignature()
    }
    
    
    public func getPublicKeySignature() -> SignatureData? {
        return try? self.publicKeySignature()
    }
    
    
    public func getRemovePublicKeySign() -> SignatureData? {
        return try? self.removePublicKeySignature()
    }
    
    
    public func getRemoveAssociatedAddressSign() -> SignatureData? {
        return try? self.removeAssociatedAddressSignature()
    }
    
    
    private func getEin(receipt: TransactionReceipt, completion: @escaping(TransactionReceipt?, Error?) -> Void) {
        
        let eventInputs: [ABI.Element.Event.Input] = [
            .init(name: "initiator", type: .address, indexed: true),
            .init(name: "ein", type: .uint(bits: 256), indexed: true),
            .init(name: "recoveryAddress", type: .address, indexed: false),
            .init(name: "associatedAddress", type: .address, indexed: false),
            .init(name: "providers", type: .array(type:.address, length: 0), indexed: false),
            .init(name: "resolvers", type: .array(type:.address, length: 0), indexed: false),
            .init(name: "delegated", type: .bool, indexed: false)
        ]
        
        let identityCreated = ABI.Element.Event(name: "IdentityCreated", inputs: eventInputs, anonymous: false)
        
        let decodedEvents = self.decodeEvent(identityCreated, from: receipt)
                
        //ein
        let einList = decodedEvents.compactMap { $0["ein"] as? BigUInt }
        guard let firstEIN = einList.first else {
            print("none_ein")
            completion(nil, MetaWalletError.eventNotFound)
            return
        }
    
        self.metaID = self.getInt32Byte(int: firstEIN).toHexString().addHexPrefix()
        print("ein: \(self.metaID)")
        
        // 여기서부터 identity 는 생성되어 있으므로, 실패하면 공개키 없는 identity 가 남는다. DID 를 알려준다.
        let signatureData: SignatureData
        
        do {
            signatureData = try self.publicKeySignature()
        } catch {
            completion(nil, MetaWalletError.partialCreation(did: self.getDid(), underlying: error))
            return
        }
        
        self.delegator.addPublicKeyDelegated(signatureData: signatureData) { (type, txId, error) in
            
            if error != nil {
                completion(nil, MetaWalletError.partialCreation(did: self.getDid(), underlying: error))
                
                return
            }
            
            guard let txId = txId else {
                completion(nil, MetaWalletError.partialCreation(did: self.getDid(), underlying: nil))
                return
            }
            
            Task {
                await self.transactionReceipt(txId: txId) { receipt in
                    guard let receipt = receipt else {
                        completion(nil, MetaWalletError.partialCreation(did: self.getDid(), underlying: MetaWalletError.receiptNotFound))
                        return
                    }
                    
                    completion(receipt, nil)
                }
            }
        }
    }
    
    
    public func existDid(completion: @escaping(Bool) -> Void) async {
        guard let address = self.getWalletAddress() else {
            completion(false)
            return
        }
        
        let identity = self.delegator.registryAddress?.identityRegistry
        
        let abiString = """
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
            """
        
        guard let contract = self.delegator.node.contract(abiString, at: EthereumAddress(identity!)),
              let readOperation = contract.createReadOperation("hasIdentity", parameters: [address]),
              let readed = try? await readOperation.callContractMethod() else {
                  
              completion(false)
            return
        }
        
        
        if let value = readed.values.first as? Bool {
            completion(value)
            
            return
        }
        
        completion(false)
    }
    
    static public func getDiDDocument(did: String? = "", resolverUrl: String) -> DiDDocument? {
            
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
            return nil
        }
        
        return didDocument
    }
    
    
    
    static public func verify(jwt: JWSObject, resolverUrl: String) throws -> Bool {
        
        let kid = jwt.header.kid
        
        let arr = kid?.components(separatedBy: "#")
        
        if arr!.count > 0 {
            let did = arr![0]
            
            guard let didDocument = MetaWallet.getDiDDocument(did: did, resolverUrl: resolverUrl) else {
                return false
            }
            
            let publicKey = didDocument.publicKey
            
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
        
        if let signer = self.signer {
            return try self.sign(verifiable: verifiable, nonce: nonce, claim: claim, jwsSigner: ExternalJWSSigner(signer: signer))
        }
        
        guard let privateKeyData = self.privateKey else {
            return nil
        }
        
        let privateKey = self.getInt32Byte(int: BigUInt(hex: privateKeyData.toHexString())!)
        
        return try self.signWithSigner(verifiable: verifiable, nonce: nonce, claim: claim, jwsSigner: ECDSASigner.init(privateKey: privateKey))
    }
    
    
    /**
     * Sign verifiable credential, presentation with the given JWS signer.
     * 외부 키 보관 서비스를 사용하는 경우 ExternalJWSSigner 등을 전달한다.
     * kid 는 지갑의 키를 가리키므로 서명이 지갑의 공개키로 검증되지 않으면 MetaWalletError.signerMismatch 를 던진다.
     */
    public func sign(verifiable: Verifiable, nonce: String?, claim: JWT?, jwsSigner: JWSSigner) throws -> JWSObject? {
        
        guard let jws = try self.signWithSigner(verifiable: verifiable, nonce: nonce, claim: claim, jwsSigner: jwsSigner) else {
            return nil
        }
        
        guard let publicKey = self.getPublicKeyData() else {
            throw MetaWalletError.notReady
        }
        
        guard try jws.verify(verifier: ECDSAVerifier.init(publicKey: publicKey)) else {
            throw MetaWalletError.signerMismatch
        }
        
        return jws
    }
    
    
    private func signWithSigner(verifiable: Verifiable, nonce: String?, claim: JWT?, jwsSigner: JWSSigner) throws -> JWSObject? {
        
        // DID 가 없거나 키가 없으면 kid 를 만들 수 없다.
        guard !self.getDid().isEmpty, let kid = self.getKid() else {
            throw MetaWalletError.noDid
        }
        
        if let verify = verifiable as? VerifiableCredential {
            verify.issuer = self.getDid()
            
            return try verify.sign(kid: kid, nonce: nonce, signer: jwsSigner, baseClaims: claim)
        }
        
        if let verify = verifiable as? VerifiablePresentation {
            verify.holder = self.getDid()
            
            return try verify.sign(kid: kid, nonce: nonce, signer: jwsSigner, baseClaims: claim)
        }
        
        return nil
    }
    
    
    
    /**
     * Issue verifiable credentail
     */
    public func issueCredential(types: [String], id: String?, nonce: String?, issuanceDate: Date?, expirationDate: Date?, ownerDid: String, subjects: [String: Any]) throws -> JWSObject? {
        return try self.issueCredential(types: types, id: id, nonce: nonce, issuanceDate: issuanceDate, expirationDate: expirationDate, ownerDid: ownerDid, subjects: subjects, jwsSigner: nil)
    }
    
    
    /**
     * Issue verifiable credentail with the given JWS signer
     */
    public func issueCredential(types: [String], id: String?, nonce: String?, issuanceDate: Date?, expirationDate: Date?, ownerDid: String, subjects: [String: Any], jwsSigner: JWSSigner?) throws -> JWSObject? {
        
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
        
        if let jwsSigner = jwsSigner {
            return try self.sign(verifiable: vc!, nonce: nonce, claim: nil, jwsSigner: jwsSigner)
        }
        
        return try self.sign(verifiable: vc!, nonce: nonce, claim: nil)
    }
    
    
    /**
     * Issue verifiable presentation
     */
    public func issuePresentation(types: [String], id: String?, nonce: String?, issuanceDate: Date?, expirationDate: Date?, vcList: [String]) throws -> JWSObject? {
        return try self.issuePresentation(types: types, id: id, nonce: nonce, issuanceDate: issuanceDate, expirationDate: expirationDate, vcList: vcList, jwsSigner: nil)
    }
    
    
    /**
     * Issue verifiable presentation with the given JWS signer
     */
    public func issuePresentation(types: [String], id: String?, nonce: String?, issuanceDate: Date?, expirationDate: Date?, vcList: [String], jwsSigner: JWSSigner?) throws -> JWSObject? {
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
        
        if let jwsSigner = jwsSigner {
            return try self.sign(verifiable: vp!, nonce: nonce, claim: claims, jwsSigner: jwsSigner)
        }
        
        return try self.sign(verifiable: vp!, nonce: nonce, claim: claims)
    }
    
    
    
    /**
     * did, privatekey의 json String
     */
    public func toJson() -> String? {
        
        guard let privateKey = self.privateKey else {
            return nil
        }
        
        let dic = ["did": self.getDid(), "private_key": privateKey.toHexString()]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
            
            let jsonStr = String(data: jsonData, encoding: .utf8)
            
            return jsonStr
        }
        catch {
            return nil
        }

    }
    
    
    public func getKey() -> MetadiumKey? {
        
        guard let publicKey = self.getPublicKey(),
              let address = MetaUtils.getAddress(publicKey: publicKey) else {
            return nil
        }
        
        let key = MetadiumKey()
        key.address = address
        key.privateKey = self.privateKey?.toHexString()
        key.publicKey = publicKey
        
        return key
    }
    
    
    public func getDid() -> String {
        if !self.did.isEmpty {
            return self.did
        }
        
        if !self.metaID.isEmpty {
            self.did = self.delegator.didPrefix + self.metaID.stripHexPrefix()
        }
        
        return self.did
    }
    
    
    public func getKid() -> String? {
        
        var kid = ""
        let did = getDid()
        
        guard let address = self.getWalletAddress() else {
            return nil
        }
        
        
        if !did.isEmpty {
            kid = did + "#MetaManagementKey#" + address.lowercased().stripHexPrefix()
        }
        
        return kid
    }
    
    
    private func decodeEvent(_ event: ABI.Element.Event, from receipt: TransactionReceipt) -> [[String: Any]] {
            let targetLogs = receipt.logs.filter {
                let lhs = $0.topics.first
                let rhs = event.topic
                 return lhs == rhs
            }
            let decodedLogs: [[String: Any]] = targetLogs.compactMap {
                ABIDecoder.decodeLog(event: event, eventLogTopics: $0.topics, eventLogData: $0.data)
            }
            return decodedLogs
        }
    
    
    private func getWalletAddress() -> String? {
        guard let publicKey = getPublicKey(),
              let address = MetaUtils.getAddress(publicKey: publicKey) else {
            return nil
        }
        
        return address
    }
    
    private func getInt32Byte(int: BigUInt) -> Data {
        let bytes = int.bytes
        let byte = [UInt8](repeating: 0x00, count: 32 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
    
    private func getInt16Byte(int: BigUInt) -> Data {
        let bytes = int.bytes // should be <= 20 bytes
        let byte = [UInt8](repeating: 0x00, count: 16 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
}

extension BigUInt {
    init?(hex: String) {
        self.init(hex.stripHexPrefix().lowercased(), radix: 16)
    }
    
    var hexString: String {
        return String(bytes: self.bytes)
    }
    
    var bytes: [UInt8] {
        let data = self.magnitude.serialize()
        let bytes = data.bytes
        let lastIndex = bytes.count - 1
        let firstIndex = bytes.index(where: {$0 != 0x00}) ?? lastIndex
        
        if lastIndex < 0 {
            return Array([0])
        }
        
        return Array(bytes[firstIndex...lastIndex])
    }
}
