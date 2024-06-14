//
//  JOSEObject.swift
//  JWS
//
//  Created by 전영배 on 13/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// JOSE Object error
///
/// - NotSignedYet: cause serializing not signed JWS
enum JOSEObjectError: Error {
    case NotSignedYet
}



/// JOSE
public protocol JOSEObject {
    var payload: Data { get set }
    
    func serialize() throws -> String
}
