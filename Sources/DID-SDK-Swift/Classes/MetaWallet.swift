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
        
        self.delegator = delegator
        
        if self.privateKey != nil {
            self.delegator.publicKey = self.getPublicKey()!
        }
    }
    
    
    /**
     secp256k1 지갑 키 생성
     */
    public func createDID(completion: @escaping () -> Void) {
        self.tryReceiptCount = 0
        
        self.generateKey()
        
        Task {
            await self.createIdentity() { receipt in
                guard let receipt = receipt else {
                    return
                }
                
                if receipt.status == .ok {
                    completion()
                }
            }
        }
    }
    
    
    public func deleteDID(completion: @escaping() -> Void) {
        
        Task {
            await self.deleteDID() { receipt in
                guard let receipt = receipt else {
                    return
                }
                
                if receipt.status == .ok {

                    completion()
                }
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
    public func createIdentity(completion: @escaping(TransactionReceipt?) -> Void) async {
        
        guard let signatureData = self.getCreateKeySignature() else {
            return
        }
        
        self.delegator.createIdentityDelegated(signatureData: signatureData) { (type, txID, error) in
            
            if error != nil {
                completion(nil)
                return
            }
            
            Task {
                self.transationType = type
                await self.transactionReceipt(txId: txID!) { receipt in
                    guard let receipt = receipt else {
                        return
                    }
                    
                    self.metaID = ""
                    self.did = ""
                    
                    self.getEin(receipt: receipt) { receipt in
                        completion(receipt)
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
    
    
    public func deleteDID(completion: @escaping (TransactionReceipt?) -> Void) async {
        self.tryReceiptCount = 0
        
        guard let signatureData = self.getRemovePublicKeySign() else {
            return
        }
        
        self.delegator.removePublicKeyDelegated(signatureData: signatureData) { (type, txID, error) in
            if error != nil {
                return
            }
            
            self.transationType = type
            
            print("removePublicKey_txID: \(txID ?? "")")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    await self.transactionReceipt(txId: txID!) { receipt in
                        
                        guard let receipt = receipt else {
                            return
                        }
                        
                        print("removeTransactionReceipt:\(receipt.status)")
                        
                        completion(receipt)
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

    
    private func signPersonalData(data: Data) -> Data? {
        
        guard let privateKey = self.privateKey,
              let keyStore = PlainKeystore(privateKey: privateKey.toHexString()),
              let address = MetaUtils.getAddress(publicKey: self.getPublicKey()!),
              let account = EthereumAddress(address) else {
            return nil
        }
        
        guard let signature = try? Web3Signer.signPersonalMessage(data, keystore: keyStore, account: account, password: "web3swift") else {
            return nil
        }
        
        return signature
    }

    
    /**
     * @param  sign data
     */
    
    public func getSignature(data: Data) -> SignatureData? {
        guard let signature = self.signPersonalData(data: data) else {
            return nil
        }
        
        let r = signature.subdata(in: 0..<32).toHexString()
        let s = signature.subdata(in: 32..<64).toHexString()
        let v = String(format: "%02x", UInt8(signature[64]))
        
        let signData = (r + s + v).data(using: .utf8)
        
        let signatureData = SignatureData(signData: signData!, r: r.addHexPrefix(), s: s.addHexPrefix(), v: v.addHexPrefix())
        
        return signatureData
    }
    
    
    /**
     * create_identity delegate sign
     */
    public func getCreateKeySignature() -> SignatureData? {
        
        if self.delegator.registryAddress == nil {
            return nil
        }
        
        let resolvers = self.delegator.registryAddress!.resolvers
        let providers = self.delegator.registryAddress!.providers
        let identityRegistry = self.delegator.registryAddress!.identityRegistry?.stripHexPrefix()
        
        guard let publicKey = self.getPublicKey(),
              let addr = MetaUtils.getAddress(publicKey: publicKey) else {
            return nil
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
        
        guard let signature = self.getSignature(data: data) else {
            return nil
        }
        
        return signature
    }
    
    
    
    /**
     * add_public_key_delegated sign
     */

    public func getPublicKeySignature() -> SignatureData? {
        
        if self.delegator.registryAddress == nil {
            return nil
        }
        
        guard let publicKey = self.getPublicKey(),
              let address = MetaUtils.getAddress(publicKey: publicKey) else {
            return nil
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

        guard let signature = self.getSignature(data: data) else {
            return nil
        }
        
        return signature
    }
    

    
    
    public func getRemovePublicKeySign() -> SignatureData? {
        
        if self.delegator.registryAddress == nil {
            return nil
        }
        
        guard let address = self.getWalletAddress() else {
            return nil
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
        
        guard let signature = self.getSignature(data: data) else {
            return nil
        }
        
        return signature
    }
    
    
    public func getRemoveAssociatedAddressSign() -> SignatureData? {
        
        if self.delegator.registryAddress == nil {
            return nil
        }
                
        guard let address = self.getWalletAddress() else {
            return nil
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
        
        guard let signature = self.getSignature(data: data) else {
            return nil
        }
        
        return signature
    }
    
    

    private func getEin(receipt: TransactionReceipt, completion: @escaping(TransactionReceipt?) -> Void) {
        
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
            return
        }
    
        self.metaID = self.getInt32Byte(int: firstEIN).toHexString().addHexPrefix()
        print("ein: \(self.metaID)")
        
        guard let signatureData = self.getPublicKeySignature() else {
            return
        }
        
        self.delegator.addPublicKeyDelegated(signatureData: signatureData) { (type, txId, error) in
            
            if error != nil {
                return
            }
            
            Task {
                await self.transactionReceipt(txId: txId!) { receipt in
                    completion(receipt)
                }
            }
        }
    }
    
    /*
    public func existDid() throws -> Bool {
        guard let address = self.getWalletAddress() else {
            return nil
        }
        
        var isEin: Bool = false
        
        let semaPhore = DispatchSemaphore(value: 0)
        
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
        
        let contract = Web3.Contract(abiString: abiString, at: EthereumAddress(identity))
        
        guard let readOperation = contract.createReadOperation("hasIdentity", parameters: [address]),
              let readed = try? await readOperation?.callContractMethod() else {
            return
        }
        
        let value = readed.values.first
        print(value)
        
        
        
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
    */
    
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
        
        guard let privateKeyData = self.privateKey else {
            return nil
        }
        
        if let verify = verifiable as? VerifiableCredential {
            verify.issuer = self.getDid()
            
            let privateKey = self.getInt32Byte(int: BigUInt(hex: privateKeyData.toHexString())!)
            
            let jwsObj = try verify.sign(kid: self.getKid()!, nonce: nonce, signer: ECDSASigner.init(privateKey: privateKey), baseClaims: claim)
            
            return jwsObj
        }
        
        if let verify = verifiable as? VerifiablePresentation {
            verify.holder = self.getDid()
            
            
            let privateKey = self.getInt32Byte(int: BigUInt(hex: privateKeyData.toHexString())!)
            
            return try verify.sign(kid: self.getKid()!, nonce: nonce, signer: ECDSASigner.init(privateKey: privateKey), baseClaims: claim)
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
