//
//  RegistryAddress.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/01.
//

import UIKit

public class RegistryAddress: NSObject {
    
    public var identityRegistry: String?
    public var providers: [String]?
    public var publicKey: String?
    public var publicKeyAll: [String]?
    public var resolvers: [String]?
    public var serviceKey: String?
    public var serviceKeyAll: [String]?
    
    
    init(dic: Dictionary<String, Any>) {
        if let identityRegistry = dic["identity_registry"] as? String {
            self.identityRegistry = identityRegistry
        }
        
        if let providers = dic["providers"] as? [String] {
            self.providers = providers
        }
        
        if let publicKey = dic["public_key"] as? String {
            self.publicKey = publicKey
        }
        
        if let publicKeyAll = dic["public_key_all"] as? [String] {
            self.publicKeyAll = publicKeyAll
        }
        
        if let resolvers = dic["resolvers"] as? [String] {
            self.resolvers = resolvers
        }
        
        if let serviceKey = dic["service_key"] as? String {
            self.serviceKey = serviceKey
        }
        
        if let serviceKeyAll = dic["service_key_all"] as? [String] {
            self.serviceKeyAll = serviceKeyAll
        }
    }
}
