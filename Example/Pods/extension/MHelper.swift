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
import web3swift

public class MHelper {

    /*
    // getEvent
    public class func getEvent(receipt: TransactionReceipt, string: String) -> NSDictionary {
        
        let abiEvent = self.jsonStringToDictionary(string: string)! as NSDictionary
        
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
        
        let eventSignature = data?.sha3(SHA3.Variant.keccak256).toHexString().withHexPrefix
        
        for log in receipt.logs {
            if log.topics[0].toHexString().withHexPrefix == eventSignature {
                
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

    
    public static func jsonStringToDictionary(string: String?) -> [String: Any]? {
        if let jsonData = string?.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        
        return nil
    }
     */
}
