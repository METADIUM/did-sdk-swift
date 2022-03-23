//
//  MHelper.swift
//  MetaID_II
//
//  Created by hanjinsik on 19/11/2018.
//  Copyright © 2018 coinplug. All rights reserved.
//

import Foundation
import CryptoSwift
import BigInt
import EthereumAddress

public class MHelper {

    // getEvent
    public class func getEvent(receipt: EthereumTransactionReceipt, string: String) -> NSDictionary {
        
        let abiEvent = Web3Utils.jsonStringToDictionary(string: string)! as NSDictionary
        
        let name = abiEvent.object(forKey: "name") as! String
        
        let types = abiEvent.object(forKey: "inputs") as! NSArray
        
        let mArr = NSMutableArray()
        let mNoneIdex = NSMutableArray()
        
        for obj in types {
            let dic = obj as! NSDictionary
            let type = dic.object(forKey: "type") as! String
            mArr.add(type)
            
            let indexed = dic.object(forKey: "indexed") as! Bool
            
            if indexed == false {
                mNoneIdex.add(type)
            }
        }
        
        let eventName = NSMutableString()
    
        eventName.append(name)
        eventName.append("(")
        
        
        for typeStr in mArr {
            let str = typeStr as! String
            eventName.append(str)
            eventName.append(",")
        }
        
        eventName.deleteCharacters(in: NSRange(location: eventName.length-1, length: 1))
        eventName.append(")")
        
        
        let tempStr = eventName as String
        let data = tempStr.data(using: .utf8)
        
        let eventSignature = data?.sha3(SHA3.Variant.keccak256).toHexString().addHexPrefix()
        
        for log in receipt.logs {
            if log.topics[0] == eventSignature {
                
                do {
                    let retrunValue = NSMutableDictionary()
                    
                    let decoded = try ABIDecoder.decodeData(log.data, types: mNoneIdex as! [String]) as NSArray
                    print(decoded)
                    
                    let inputs = abiEvent.object(forKey: "inputs") as! NSArray
                    
                    var topicCount = 1
                    var dataCount = 0
                    
                    for obj in inputs {
                        let dic = obj as! NSDictionary
                        let indexed = dic.object(forKey:"indexed") as! Bool
                        
                        if indexed {
                            let temp = log.topics[topicCount]
                            
                            retrunValue[dic.object(forKey: "name")!] = temp
                            topicCount = topicCount + 1
                        }
                        else {
                            let obj = decoded[dataCount]
                            
                            if ((obj as? Array<String>) != nil) {
                                retrunValue[dic.object(forKey: "name")!] = decoded[dataCount] as! Array<String>
                            }
                            else {
                                retrunValue[dic.object(forKey: "name")!] = decoded[dataCount] as! String
                            }
                            
                            dataCount = dataCount + 1
                        }
                    }
                    
                    return retrunValue
                    
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        }
        
        return [:]
    }
    
    
    
    
    class func get32Byte(string: String) -> Data {
        let bytes = string.bytes
        let byte = [UInt8](repeating: 0x00, count: 32 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
    
    
    
    
    class func getInt32Byte(int: BigUInt) -> Data {
        let bytes = int.bytes // should be <= 32 bytes
        let byte = [UInt8](repeating: 0x00, count: 32 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
    
    
    
    class func getContractEncodedData(contract: EthereumJSONContract, args: [String]) -> Data {
        let encodedData = try? contract.data(function: (contract.functions[0]), args: args)
        
        return encodedData!
    }
    
    
    
    
    class func signOfAccount(account: EthereumAccount, orignData: Data) -> String {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        let prefixData = (prefix + String(orignData.count)).data(using: .ascii)!
        let signature = try? account.sign(data: prefixData + orignData).hexString.withHexPrefix
        
        return signature!
    }

    
    class func getAddClaimContract(address: String) -> EthereumJSONContract {
        let contract = EthereumJSONContract.init(json:
            """
                                                        [{
                                                      "constant": false,
                                                      "inputs": [
                                                        {
                                                          "name": "_topic",
                                                          "type": "uint256"
                                                        },
                                                        {
                                                          "name": "_scheme",
                                                          "type": "uint256"
                                                        },
                                                        {
                                                          "name": "issuer",
                                                          "type": "address"
                                                        },
                                                        {
                                                          "name": "_signature",
                                                          "type": "bytes"
                                                        },
                                                        {
                                                          "name": "_data",
                                                          "type": "bytes"
                                                        },
                                                        {
                                                          "name": "_uri",
                                                          "type": "string"
                                                        }
                                                      ],
                                                      "name": "addClaim",
                                                      "outputs": [
                                                        {
                                                          "name": "claimRequestId",
                                                          "type": "uint256"
                                                        }
                                                      ],
                                                      "payable": false,
                                                      "stateMutability": "nonpayable",
                                                      "type": "function"
                                                    }]
                                                    """, address: EthereumAddress(address)!)
        
        return contract!
    }
    
    
    class func getTransactionCountContract(address: String) -> EthereumJSONContract {
        let contract = EthereumJSONContract.init(json: """
        [{
            "constant": true,
            "inputs": [],
            "name": "getTransactionCount",
            "outputs": [
            {
            "name": "",
            "type": "uint256"
            }
            ],
            "payable": false,
            "stateMutability": "view",
            "type": "function"
        }]
        """, address: EthereumAddress(address)!)
        
        return contract!
    }
    
    
    class func getClaimContract(address: String) -> EthereumJSONContract {
        let contract = EthereumJSONContract.init(json: """
                                                        [{
                                                        "constant": true,
                                                        "inputs": [
                                                        {
                                                        "name": "_claimId",
                                                        "type": "bytes32"
                                                        }
                                                        ],
                                                        "name": "getClaim",
                                                        "outputs": [
                                                        {
                                                        "name": "topic",
                                                        "type": "uint256"
                                                        },
                                                        {
                                                        "name": "scheme",
                                                        "type": "uint256"
                                                        },
                                                        {
                                                        "name": "issuer",
                                                        "type": "address"
                                                        },
                                                        {
                                                        "name": "signature",
                                                        "type": "bytes"
                                                        },
                                                        {
                                                        "name": "data",
                                                        "type": "bytes"
                                                        },
                                                        {
                                                        "name": "uri",
                                                        "type": "string"
                                                        }
                                                        ],
                                                        "payable": false,
                                                        "stateMutability": "view",
                                                        "type": "function"
                                                        }]
                                                        """, address: EthereumAddress(address)!)
        
        return contract!
    }
    
    
    class func ownerOfContract(address: String) -> EthereumJSONContract {
        let contract = EthereumJSONContract.init(json:"""
                                                        [{
                                                        "constant": true,
                                                        "inputs": [
                                                        {
                                                        "name": "_tokenId",
                                                        "type": "uint256"
                                                        }
                                                        ],
                                                        "name": "ownerOf",
                                                        "outputs": [
                                                        {
                                                        "name": "",
                                                        "type": "address"
                                                        }
                                                        ],
                                                        "payable": false,
                                                        "stateMutability": "view",
                                                        "type": "function"
                                                        }]
                                                        """, address: EthereumAddress(address)!)
        
        return contract!
    }
    
    
    class func requestAchievementContract(address: String) -> EthereumJSONContract {
        let contract = EthereumJSONContract.init(json:
                                                """
                                                [{
                                                    "constant": false,
                                                    "inputs": [
                                                    {
                                                    "name": "_achievementId",
                                                    "type": "bytes32"
                                                    }
                                                    ],
                                                    "name": "requestAchievement",
                                                    "outputs": [
                                                    {
                                                    "name": "success",
                                                    "type": "bool"
                                                    }
                                                    ],
                                                    "payable": false,
                                                    "stateMutability": "nonpayable",
                                                    "type": "function"
                                                }]
                                                """, address: EthereumAddress(address)!)
        
        return contract!
    }
    
    
    class func approveExecuteId(address: String) -> EthereumJSONContract  {
        let contract = EthereumJSONContract.init(json:
                                                        """
                                                        [{
                                                        "constant": false,
                                                        "inputs": [
                                                        {
                                                        "name": "_id",
                                                        "type": "uint256"
                                                        },
                                                        {
                                                        "name": "_approve",
                                                        "type": "bool"
                                                        }
                                                        ],
                                                        "name": "approve",
                                                        "outputs": [
                                                        {
                                                        "name": "success",
                                                        "type": "bool"
                                                        }
                                                        ],
                                                        "payable": false,
                                                        "stateMutability": "nonpayable",
                                                        "type": "function"
                                                        }]
                                                    """, address: EthereumAddress(address)!)
        
        return contract!
    }
    
    
    class func destoryAndSendContract(address: String) -> EthereumJSONContract {
        let contract = EthereumJSONContract.init(json: """
                                                        [{
                                                          "constant": false,
                                                          "inputs": [
                                                            {
                                                              "name": "_recipient",
                                                              "type": "address"
                                                            }
                                                          ],
                                                          "name": "destroyAndSend",
                                                          "outputs": [],
                                                          "payable": false,
                                                          "stateMutability": "nonpayable",
                                                          "type": "function"
                                                        }]
                                                    """, address: EthereumAddress(address)!)
        
        return contract!
    }
}
