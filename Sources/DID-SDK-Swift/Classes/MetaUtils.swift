//
//  MetaUtils.swift
//  DID-SDK-Swift
//
//  Created by hanjinsik on 6/12/24.
//

import Foundation
import Web3Core

class MetaUtils {
    public static func getAddress(publicKey: String) -> String? {
        let pubKeyData = Data.init(hex: publicKey)
        
        guard let address = Web3Core.Utilities.publicToAddressString(pubKeyData) else {
            return nil
        }
        
        return address
    }

}

