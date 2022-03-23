//
//  EthereumTransaction.swift
//  web3swift
//
//  Created by Julien Niset on 23/02/2018.
//  Added EIP1559 by Sungbin Lee(Coinplug) on 02/03/2022.
//  Copyright © 2018 Argent Labs Limited. All rights reserved.
//

import Foundation
import BigInt
import EthereumAddress

public protocol EthereumTransactionProtocol {
    init(from: String?, to: String, value: BigUInt?, data: Data?, nonce: Int?, maxFeePerGas: BigUInt?, maxPriorityFeePerGas: BigUInt?, gasLimit: BigUInt?, chainId: Int?)//eip1559
    init(from: String?, to: String, value: BigUInt?, data: Data?, nonce: Int?, gasPrice: BigUInt?, gasLimit: BigUInt?, chainId: Int?)
    init(from: String?, to: String, data: Data, gasPrice: BigUInt, gasLimit: BigUInt)
    init(to: String, data: Data)
    
    var raw: Data? { get }
    var hash: Data? { get }
}

//was added 1.2.0, to support eip1559
public enum EthereumTransactionType {
    case legacy
    case EIP1559
}

public struct EthereumTransaction: EthereumTransactionProtocol, Codable {
    public let from: String?
    public let to: String
    public let value: BigUInt?
    public let data: Data?
    public var nonce: Int?
    public let maxPriorityFeePerGas: BigUInt? //eip1559
    public let maxFeePerGas: BigUInt? // eip559
    public let gasPrice: BigUInt?
    public let gasLimit: BigUInt?
    public let gas: BigUInt?
    public let blockNumber: EthereumBlock?
    public private(set) var hash: Data?
    var chainId: Int? {
        didSet {
            self.hash = self.raw?.keccak256
        }
    }
    public var txType: EthereumTransactionType = .legacy // all existing transactions are legacy transactions.
    
    //was added 1.2.0, to supprot eip1559
    public init(from: String?, to: String, value: BigUInt?, data: Data?, nonce: Int?, maxFeePerGas: BigUInt?, maxPriorityFeePerGas: BigUInt?, gasLimit: BigUInt?, chainId: Int?) {
        self.from = from
        self.to = to
        self.value = value
        self.data = data ?? Data()
        self.nonce = nonce
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.maxFeePerGas = maxFeePerGas
        self.gasPrice = nil
        self.gasLimit = gasLimit
        self.chainId = chainId
        self.gas = nil
        self.blockNumber = nil
        let txArray: [Any?] = [self.chainId, self.nonce, self.maxPriorityFeePerGas, self.maxFeePerGas, self.gasLimit, to.noHexPrefix, self.value, self.data, []]
        self.hash = Data.init(bytes: [0x02]) + (RLP.encode(txArray) ?? Data())
        self.txType = .EIP1559
    }
    
    public init(from: String?, to: String, value: BigUInt?, data: Data?, nonce: Int?, gasPrice: BigUInt?, gasLimit: BigUInt?, chainId: Int?) {
        self.from = from
        self.to = to
        self.value = value
        self.data = data ?? Data()
        self.nonce = nonce
        self.maxPriorityFeePerGas = nil
        self.maxFeePerGas = nil
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.chainId = chainId
        self.gas = nil
        self.blockNumber = nil
        let txArray: [Any?] = [self.nonce, self.gasPrice, self.gasLimit, to.noHexPrefix, self.value, self.data, self.chainId, 0, 0]
        self.hash = RLP.encode(txArray)
    }
    
    public init(from: String?, to: String, data: Data, gasPrice: BigUInt, gasLimit: BigUInt) {
        self.from = from
        self.to = to
        self.value = BigUInt(0)
        self.data = data
        self.maxPriorityFeePerGas = nil
        self.maxFeePerGas = nil
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.gas = nil
        self.blockNumber = nil
        self.hash = nil
    }
    
    public init(to: String, data: Data) {
        self.from = nil
        self.to = to
        self.value = BigUInt(0)
        self.data = data
        self.maxPriorityFeePerGas = nil
        self.maxFeePerGas = nil
        self.gasPrice = BigUInt(0)
        self.gasLimit = BigUInt(0)
        self.gas = nil
        self.blockNumber = nil
        self.hash = nil
    }
    
    public var raw: Data? {
        let txArray: [Any?]
        
        if self.txType == .EIP1559 {
            txArray = [self.chainId, self.nonce, self.maxPriorityFeePerGas, self.maxFeePerGas, self.gasLimit, self.to.noHexPrefix, self.value, self.data, []]
        } else {
            txArray = [self.nonce, self.gasPrice, self.gasLimit, self.to.noHexPrefix, self.value, self.data, self.chainId, 0, 0]
        }
        
        
        let rlp = RLP.encode(txArray) ?? Data()
        
        if self.txType == .EIP1559 {
            let txHeader = Data.init([0x02]) //eip1559 tx header 02
            return txHeader + rlp
        } else {
            return rlp
        }
    }
    
    enum CodingKeys : String, CodingKey {
        case from
        case to
        case value
        case data
        case nonce
        case maxPriorityFeePerGas
        case maxFeePerGas
        case gasPrice
        case gas
        case gasLimit
        case blockNumber
        case hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.to = try container.decode(String.self, forKey: .to)
        self.from = try? container.decode(String.self, forKey: .from)
        self.data = try? container.decode(Data.self, forKey: .data)
        
        let decodeHexUInt = { (key: CodingKeys) -> BigUInt? in
            return (try? container.decode(String.self, forKey: key)).flatMap { BigUInt(hex: $0)}
        }
        
        let decodeHexInt = { (key: CodingKeys) -> Int? in
            return (try? container.decode(String.self, forKey: key)).flatMap { Int(hex: $0)}
        }
        
        self.value = decodeHexUInt(.value)
        self.maxPriorityFeePerGas = decodeHexUInt(.maxPriorityFeePerGas)
        self.maxFeePerGas = decodeHexUInt(.maxFeePerGas)
        self.gasLimit = decodeHexUInt(.gasLimit)
        self.gasPrice = decodeHexUInt(.gasPrice)
        self.gas = decodeHexUInt(.gas)
        self.nonce = decodeHexInt(.nonce)
        self.blockNumber = try? container.decode(EthereumBlock.self, forKey: .blockNumber)
        self.hash = (try? container.decode(String.self, forKey: .hash))?.hexData
        self.chainId = nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(to, forKey: .to)
        try? container.encode(from, forKey: .from)
        try? container.encode(data, forKey: .data)
        try? container.encode(value?.hexString, forKey: .value)
        try? container.encode(maxPriorityFeePerGas?.hexString, forKey: .maxPriorityFeePerGas)
        try? container.encode(maxFeePerGas?.hexString, forKey: .maxFeePerGas)
        try? container.encode(gasPrice?.hexString, forKey: .gasPrice)
        try? container.encode(gasLimit?.hexString, forKey: .gasLimit)
        try? container.encode(gas?.hexString, forKey: .gas)
        try? container.encode(nonce?.hexString, forKey: .nonce)
        try? container.encode(blockNumber, forKey: .blockNumber)
        try? container.encode(hash?.hexString, forKey: .hash)
    }
}

struct SignedTransaction {
    let transaction: EthereumTransaction
    let v: Int
    let r: Data
    let s: Data
    
    init(transaction: EthereumTransaction, v: Int, r: Data, s: Data) {
        self.transaction = transaction
        
        //v value for validation is diffrenent from legacy
        if transaction.txType == .legacy {
            self.v = v //use v as own
            
        } else {//eip 1559 (or others in future)
            if ((v % 2) == 0) {
                self.v = 1 // use 1 when v was even number
            } else {
                self.v = 0 // use 0 when v was odd number
            }
        }
        
        self.r = r.strippingZeroesFromBytes
        self.s = s.strippingZeroesFromBytes
    }
    
    var raw: Data? {
        let txArray: [Any?]
        
        if self.transaction.txType == .EIP1559 {
            txArray = [transaction.chainId, transaction.nonce, transaction.maxPriorityFeePerGas, transaction.maxFeePerGas, transaction.gasLimit, transaction.to.noHexPrefix, transaction.value, transaction.data, [], self.v, self.r, self.s]
        } else {
            txArray = [transaction.nonce, transaction.gasPrice, transaction.gasLimit, transaction.to.noHexPrefix, transaction.value, transaction.data, self.v, self.r, self.s]
        }
        
        
        let rlp = RLP.encode(txArray) ?? Data()
        
        if self.transaction.txType == .EIP1559 {
            let txHeader = Data.init([0x02])
            return txHeader + rlp
        } else {
            return rlp
        }
    }
    
    var hash: Data? {
        return raw?.keccak256
    }
}



public struct SignedData {
    let v: Int
    let r: Data
    let s: Data
    
    init(v: Int, r: Data, s: Data) {
        self.v = v
        self.r = r.strippingZeroesFromBytes
        self.s = s.strippingZeroesFromBytes
    }
}
