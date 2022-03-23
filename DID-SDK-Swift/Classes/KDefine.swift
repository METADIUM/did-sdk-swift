//
//  KDefine.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/11/27.
//

import Foundation


class KDefine: NSObject {
    static let kEntropy_Length: Int = 16
    static let kMetadium_PrefixPath: String = "m/44'/916'/0'/0"
    
    static let kMeta_Test_Delegator_URL: String = "https://testdelegator.metadium.com"
    static let kMeta_Real_Delegator_URL: String = "https://delegator.metadium.com"
    static let kMeta_Test_Node_URL: String = "https://api.metadium.com/dev"
    static let kMeta_Real_Node_URL: String = "https://api.metadium.com/prod"
    static let kMeta_Test_Relover_URL: String = "https://testnetresolver.metadium.com/1.0/identifiers/"
    static let kMeta_Real_Relover_URL: String = "https://resolver.metadium.com/1.0/identifiers/"
    static let kMeta_Test_DID_prefix: String = "did:meta:testnet:"
    static let kMeta_Real_DID_prefix: String = "did:meta:"
    
    static let kPrefix: String = "\u{19}Ethereum Signed Message:\n"
    
    static let KCreateIdentity: String = "I authorize the creation of an Identity on my behalf."
    static let kAddKey: String = "I authorize the addition of a service key on my behalf."
    static let kRmovekey: String = "I authorize the removal of a service key on my behalf."
    static let KRemove_allKey: String = "I authorize the removal of all service keys on my behalf."
    static let KAdd_PublicKey: String = "I authorize the addition of a public key on my behalf."
    static let KRemove_PubliKey: String = "I authorize the removal of a public key on my behalf."
    static let kRemove_Address_MyIdentity: String = "I authorize removing this address from my Identity."
}

