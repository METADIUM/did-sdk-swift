//
//  MetaDelegator.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/01.
//

import UIKit
import web3swift
import Web3Core
import BigInt


public class MetaDelegator: NSObject {
    
    public var registryAddress: RegistryAddress?
    public var publicKey: String!
    public var delegatorUrl: URL!
    public var resolverUrl: String!
    
    var node: Web3!
    
    var didPrefix: String!
    var api_key: String!
    
    var timeStamp: Int!
    
    /**
     * @param  delegate Url
     * @param node Url
     * @param didPrefix
     * @param api_key
     */
    public init(delegatorUrl: String? = "https://delegator.metadium.com", nodeUrl: String? = "https://api.metadium.com/prod", resolverUrl: String? = "https://resolver.metadium.com/1.0/identifiers/", didPrefix: String? = "did:meta:", api_key: String? = "") {
        
        super.init()
        
        self.delegatorUrl = URL(string: delegatorUrl!)
        self.resolverUrl = resolverUrl
        
        self.didPrefix = didPrefix!
        self.api_key = api_key
        
        var chainID = KDefine.kMeta_Main_ChainID
        
        if nodeUrl == KDefine.kMeta_Test_Node_URL {
            chainID = KDefine.kMeta_Test_ChainID
        }
        
        let url = URL(string: nodeUrl!)
        
        self.node = Web3.init(provider: Web3HttpProvider.init(url: url!, network: .Custom(networkID: BigUInt(chainID)!)))
        
        self.getAllServiceAddress()
    }
    
    
    
    
    public func getAllServiceAddress() {
        if self.registryAddress == nil {
            
            let semaPhore = DispatchSemaphore(value: 0)
            
            self.getAllServiceAddress { (registryAddress, error) in
                
                if error != nil {
                    semaPhore.signal()
                    
                    return
                }
                
                self.registryAddress = registryAddress
                
                semaPhore.signal()
            }
            
            semaPhore.wait()
        }
    }
    
    
    
    /**
     * get registry address
     * @return registryAddress
     */
    public func getAllServiceAddress(complection: @escaping(RegistryAddress?, Error?) -> Void) {
        
        DataProvider.jsonRpcMethod(url: self.delegatorUrl, api_key: self.api_key, method: "get_all_service_addresses") { (response, data, error) in
            if error != nil {
                return complection(nil, error)
            }
            
            
            if data != nil {
                let registryAddress = RegistryAddress.init(dic: data as! Dictionary<String, Any>)
                
                return complection(registryAddress, nil)
            }
        }
    }
    
    
    
    
    
    /**
     * get time stamp
     */
    
    public func getLastBlockTimeStamp(completion: @escaping(Int) -> Void)  {
        
        Task {
            var timestamp: Int = 0
            guard let lastBlock = try? await self.node.eth.block(by: .latest) else {
                return
            }
            
            timestamp = Int(lastBlock.timestamp.timeIntervalSince1970)
            self.timeStamp = timestamp
            
            completion(timestamp)
        }
    }
    
    
    
    
    /**
     * DID 생성
     * @param signData
     * @r
     * @s
     * @v
     * @return transactionType, txID
     */
    
    public func createIdentityDelegated(signatureData: SignatureData, complection: @escaping(MetaTransactionType?, String?, Error?) -> Void) {
        
        self.getAllServiceAddress()
        
        let resolvers = self.registryAddress!.resolvers
        let providers = self.registryAddress!.providers
        
        guard let addr = MetaUtils.getAddress(publicKey: self.publicKey) else {
            return complection(.createDid, nil, nil)
        }

        let params = [["recovery_address" : addr, "associated_address": addr, "providers":providers!, "resolvers": resolvers!, "v": signatureData.v, "r": signatureData.r, "s": signatureData.s, "timestamp": self.timeStamp!]]
        
        
        DataProvider.jsonRpcMethod(url: self.delegatorUrl, api_key: self.api_key, method: "create_identity", parmas: params) {(response, result, error) in
            if error != nil {
                return complection(.createDid, nil, error)
            }
            
            if let txId = result as? String {
                
                return complection(.createDid, txId, nil)
            }
        }
    }
    
    
    
    /**
     * 퍼블릭키 추가
     * @param signData
     * @r
     * @s
     * @v
     * @return transactionType, txID
     */
    
    public func addPublicKeyDelegated(signatureData: SignatureData, complection: @escaping(MetaTransactionType?, String?, Error?) -> ()) {
        
        self.getAllServiceAddress()
        
        guard let addr = self.getAddress() else {
            return
        }
        
        let resolver_publicKey = self.registryAddress!.publicKey

        let params = [["resolver_address" : resolver_publicKey!, "associated_address": addr, "public_key": self.publicKey, "v": signatureData.v, "r": signatureData.r, "s": signatureData.s, "timestamp": self.timeStamp!]]
        
        DataProvider.jsonRpcMethod(url: self.delegatorUrl, api_key: self.api_key, method: "add_public_key_delegated", parmas: params) {(response, result, error) in
            if error != nil {
                return complection(.addWalletPublicKey, nil, error)
            }
            
            if let txId = result as? String {
                return complection(.addWalletPublicKey, txId, nil)
            }
        }
    }
    
    
    private func getAddress() -> String? {
        let publicKey = "04" + self.publicKey.noHexPrefix
        
        guard let address = MetaUtils.getAddress(publicKey: publicKey) else {
            return nil
        }
        
        print("publicKey: \(self.publicKey ?? "")")
        print("address: \(address)")
        
        return address
    }
    
    
    /**
     * 퍼블릭 키 삭제
     * @param address
     * @param signData
     * @r
     * @s
     * @v
     * @return transactionType, txID
     */
    
    public func removePublicKeyDelegated(signatureData: SignatureData, complection: @escaping(MetaTransactionType?, String?, Error?) -> Void) {
        self.getAllServiceAddress()
        
        guard let addr = self.getAddress() else {
            return
        }
        
        let resolver = self.registryAddress!.publicKey
        
        let params = [["resolver_address" : resolver!, "associated_address": addr, "v": signatureData.v, "r": signatureData.r, "s": signatureData.s, "timestamp": self.timeStamp!]]
        print(params)
        
        DataProvider.jsonRpcMethod(url: self.delegatorUrl, api_key: self.api_key, method: "remove_public_key_delegated", parmas: params) {(response, result, error) in
            if error != nil {
                return complection(.removePublicKey, nil, error)
            }
            
            if let txId = result as? String {
                
                return complection(.removePublicKey, txId, error)
            }
        }
    }
    
    
    
    /**
     * associated_address  삭제
     * @param address
     * @param signData
     * @r
     * @s
     * @v
     * @return transactionType, txID
     */
    
    public func removeAssociatedAddressDelegated(signatureData: SignatureData, complection: @escaping(MetaTransactionType?, String?, Error?) -> Void) {
        self.getAllServiceAddress()
        
        guard let addr = self.getAddress() else {
            return
        }
        
        let params = [["address_to_remove": addr, "v": signatureData.v, "r": signatureData.r, "s": signatureData.s, "timestamp": self.timeStamp!]]
        print(params)
        
        DataProvider.jsonRpcMethod(url: self.delegatorUrl, api_key: self.api_key, method: "remove_associated_address_delegated", parmas: params) {(response, result, error) in
            if error != nil {
                return complection(.removeAssociatedAddress, nil, error)
            }
            
            if let txId = result as? String {
                
                return complection(.removeAssociatedAddress, txId, error)
            }
        }
    }
    
    
    public func transactionReceipt(type: MetaTransactionType, txId: String, complection: @escaping(TransactionReceipt?) -> Void) {
        
        Task {
            let receipt = try? await self.node.eth.transactionReceipt(Data.init(hex: txId))
            
            complection(receipt)
        }
    }
}
