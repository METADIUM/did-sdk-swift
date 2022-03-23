//
//  ERC20Functions.swift
//  web3swift
//
//  Created by Matt Marshall on 13/04/2018.
//  Copyright © 2018 Argent Labs Limited. All rights reserved.
//

import Foundation
import BigInt
import EthereumAddress

enum ERC20Functions {
    struct name: ABIFunction {
        static let name = "name"
        let gasPrice: BigUInt? = nil
        let gasLimit: BigUInt? = nil
        var contract: String
        let from: String? = nil
        
        func encode(to encoder: ABIFunctionEncoder) throws {
        }
    }
    
    struct symbol: ABIFunction {
        static let name = "symbol"
        let gasPrice: BigUInt? = nil
        let gasLimit: BigUInt? = nil
        var contract: String
        let from: String? = nil
        
        func encode(to encoder: ABIFunctionEncoder) throws { }
    }
    
    struct decimals: ABIFunction {
        static let name = "decimals"
        let gasPrice: BigUInt? = nil
        let gasLimit: BigUInt? = nil
        var contract: String
        let from: String? = nil
        
        func encode(to encoder: ABIFunctionEncoder) throws { }
    }
    
    struct balanceOf: ABIFunction {
        static let name = "balanceOf"
        let gasPrice: BigUInt? = nil
        let gasLimit: BigUInt? = nil
        var contract: String
        let account: String
        let from: String? = nil
        
        func encode(to encoder: ABIFunctionEncoder) throws {
            try encoder.encode(account)
        }
    }
}

