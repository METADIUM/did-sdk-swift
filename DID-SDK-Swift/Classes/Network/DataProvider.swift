//
//  DataProvider.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/01.
//

import UIKit

public typealias ServiceResponse = (URLResponse?, Any?, Error?) -> Void

public class DataProvider: NSObject {
    
    public class func jsonRpcMethod(url: URL, api_key: String?, method: String, parmas: [[String: Any]]? = [[:]], complection: @escaping ServiceResponse) {
        let session = URLSession.shared
        let request = NSMutableURLRequest.init(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json-rpc", forHTTPHeaderField: "Content-Type")
        
        if api_key != nil && !api_key!.isEmpty{
            request.setValue(api_key, forHTTPHeaderField: "API-KEY")
        }
        else {
            request.setValue("UNKNOWN", forHTTPHeaderField: "API-KEY")
        }
        
        
        let jsonRpc = ["jsonrpc" : "2.0", "id" : 1, "method" : method, "params" : parmas!] as [String : Any]
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: jsonRpc, options: .prettyPrinted)
        
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
            if error != nil {
                return complection(response, nil, error)
            }
            
            
            guard let result = try? JSONSerialization.jsonObject(with: data!, options: .mutableLeaves) as! NSDictionary else {
                return complection(response, nil, error)
            }
            
            if let dic = result["result"] {
                return complection(response, dic, nil)
            }
            
            return complection(response, data, nil)
            
        }
        
        task.resume()
    }
    
    
    public class func reqDidDocument(did: String, url: String, complection: @escaping ServiceResponse) {
        let session = URLSession.shared
        let req = NSMutableURLRequest(url: URL(string: url + did)!)
        req.httpMethod = "GET"
        
        let task = session.dataTask(with: req as URLRequest) { (data, response, error) in
            
            if error != nil {
                return complection(response, nil, error)
            }
            
            if let result = try? JSONSerialization.jsonObject(with: data!, options: .mutableLeaves) as? NSDictionary {
                return complection(response, result, nil)
            }
            
            if let result = try? JSONSerialization.jsonObject(with: data!, options: .mutableLeaves) as? String {
                return complection(response, result, nil)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [[String : Any]] {
                
                return complection(response, json, nil)
            }
        }
        
        task.resume()
    }
}
