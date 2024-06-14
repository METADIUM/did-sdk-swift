//
//  DiDDocument.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2021/06/24.
//

import UIKit

public class DiDDocument: NSObject {
    
    public var id: String?
    public var publicKey: [[String : String]]?
    public var context: String?
    public var authentication: [String]?
    public var service: [[String : String]]?
    
    private enum Codingkeys: String, CodingKey {
        case id
        case publicKey
        case context = "@context"
        case authentication
        case service
    }
    
    
    init(dic: Dictionary<String, Any>) {
        if let id = dic["id"] as? String {
            self.id = id
        }
        
        if let publicKey = dic["publicKey"] as? [[String : String]] {
            self.publicKey = publicKey
        }
        
        if let context = dic["@context"] as? String {
            self.context = context
        }
        
        if let authentication = dic["authentication"] as? [String] {
            self.authentication = authentication
        }
        
        if let service = dic["service"] as? [[String : String]] {
            self.service = service
        }
    }
}
