//
//  BytesExtensions.swift
//  DID-SDK-Swift
//
//  Created by hanjinsik on 6/14/24.
//

import Foundation
import BigInt
/*
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
*/

extension Data {
    public var bytes: [UInt8] {
        var sigBytes = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &sigBytes, count: self.count)
        return sigBytes
    }
    
    var strippingZeroesFromBytes: Data {
        var bytes = self.bytes
        while bytes.first == 0 {
            bytes.removeFirst()
        }
        return Data.init(bytes: bytes)
    }
}

extension String {
    var bytes: [UInt8] {
        return [UInt8](self.utf8)
    }
    
    public init(hexFromBytes bytes: [UInt8]) {
        self.init("0x" + bytes.map() { String(format: "%02x", $0) }.reduce("", +))
    }
}

extension Int {
    public var hexString: String {
        return "0x" + String(format: "%x", self)
    }
    
    public init?(hex: String) {
        self.init(hex.stripHexPrefix(), radix: 16)
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
    
    
    public init(bytes: [UInt8]) {
        self.init("0x" + bytes.map { String(format: "%02hhx", $0) }.joined())
    }
    
}
