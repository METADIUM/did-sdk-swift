//
//  HexExtension.swift
//  DID-SDK-Swift
//
//  Created by hanjinsik on 6/12/24.
//

import Foundation
import BigInt

public extension BigInt {
    init?(hex: String) {
        self.init(hex.noHexPrefix.lowercased(), radix: 16)
    }
}

public extension Int {
    var hexString: String {
        return "0x" + String(format: "%x", self)
    }
    
    init?(hex: String) {
        self.init(hex.noHexPrefix, radix: 16)
    }
}

extension String {
    public var noHexPrefix: String {
        if self.hasPrefix("0x") {
            let index = self.index(self.startIndex, offsetBy: 2)
            return String(self[index...])
        }
        return self
    }
    
    public var withHexPrefix: String {
        if !self.hasPrefix("0x") {
            return "0x" + self
        }
        return self
    }
    
    var stringValue: String {
        if let byteArray = try? HexUtil.byteArray(fromHex: self.noHexPrefix), let str = String(bytes: byteArray, encoding: .utf8) {
            return str
        }
        
        return self
    }
    
    var hexData: Data? {
        let noHexPrefix = self.noHexPrefix
        if let bytes = try? HexUtil.byteArray(fromHex: noHexPrefix) {
            return Data(bytes: bytes)
        }
        
        return nil
    }
    
    public init(bytes: [UInt8]) {
        self.init("0x" + bytes.map { String(format: "%02hhx", $0) }.joined())
    }
    
}
