// Copyright 2015-2016 BigML
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License. You may obtain
// a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.

import Foundation

struct BMLHTTPConnector {
    
    static let boundary = "---------------------------14737809831466499882746641449"
    
    let getter = BMLHTTPMethodHandler(method: "GET", expectedCode: 200)
    let poster = BMLHTTPMethodHandler(method: "POST", expectedCode: 201)
    let putter = BMLHTTPMethodHandler(method: "PUT", expectedCode: 202)
    let deleter = BMLHTTPMethodHandler(method: "DELETE", expectedCode: 204)
    let uploader = BMLHTTPMethodHandler(method: "POST",
        expectedCode: 201,
        contentType:"multipart/form-data; boundary=\(boundary)")
    
    func get(_ url : URL,
        body: [String : Any] = [:],
        completion:@escaping (_ jsonObject : AnyObject?, _ error : NSError?) -> Void) {
            
            self.getter.run(url, body: body) {
                (result : [String : AnyObject], error : NSError?) in
                completion(result as AnyObject?, error)
            }
    }
    
    func delete(_ url : URL, completion:@escaping (_ error : NSError?) -> Void) {
        
        self.deleter.run(url, body: [:]) {
            (result : [String : AnyObject], error : NSError?) in
            completion(error)
        }
    }
    
    func put(_ url : URL,
        body : [String : Any],
        completion:@escaping (_ error : NSError?) -> Void) {
        
            self.putter.run(url, body: body) {
                (result : [String : AnyObject], error : NSError?) in
                completion(error)
            }
    }
    
    func post(_ url : URL,
        body: [String : Any],
        completion:@escaping (_ result : [String : AnyObject], _ error : NSError?) -> Void) {
        
            self.poster.run(url, body: body, completion: completion)
    }
    
    func upload(_ url : URL,
        filename: String,
        filePath: String,
        body: [String : Any],
        completion:@escaping (_ result : [String : AnyObject], _ error : NSError?) -> Void) {
            
            let bodyData : NSMutableData = NSMutableData()
            for (name, value) in body {
//                if let value = value as? Any {
                    let fieldData = try? JSONSerialization.data(withJSONObject: value, options: [])
                    if let fieldData = fieldData, let value = NSString(data: fieldData,
                        encoding:String.Encoding.utf8.rawValue) {
                            bodyData.appendString("\r\n--\(BMLHTTPConnector.boundary)\r\n")
                            bodyData.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n")
                            bodyData.appendString("\r\n\(value)")
                    }  else {
                        assert(false, "Could not convert body field: \(value)")
                    }
  //              }
            }
            bodyData.appendString("\r\n--\(BMLHTTPConnector.boundary)\r\n")
            bodyData.appendString("Content-Disposition: form-data; name=\"userfile\"; filename=\"\(filename)\"\r\n")
            bodyData.appendString("Content-Type: application/octet-stream\r\n\r\n")
            bodyData.append(try! Data(contentsOf: URL(fileURLWithPath: filePath)))
            bodyData.appendString("\r\n--\(BMLHTTPConnector.boundary)--\r\n")

            self.uploader.run(url, bodyData: bodyData as Data, completion: completion)
    }    
}
