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

extension HTTPURLResponse {
    
    func isStrictlyValid() -> Bool {
        return self.statusCode >= 200 && self.statusCode <= 206
    }
}

struct BMLHTTPMethodHandler {
    
    fileprivate let session : URLSession
    let method : String
    let expectedCode : Int
    let contentType : String
    
    fileprivate static func initializeSession() -> URLSession {
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [ "Content-Type": "application/json" ];
        
        return URLSession(configuration : configuration)
    }
    
    init(method : String,
        expectedCode : Int,
        contentType : String = "application/json; charset=utf-8") {
            
            self.method = method
            self.expectedCode = expectedCode
            self.contentType = contentType
            self.session = BMLHTTPMethodHandler.initializeSession()
    }
    
    func run(_ url : URL,
        bodyData : Data,
        completion : @escaping (_ result : [String : Any], _ error : NSError?) -> Void) {
            
            do {
                try self.handleDataRequest(self.method, url: url, bodyData: bodyData) {
                    (data, error) in
                    
                    var localError = error;
                    var jsonObject : [String : Any]
                    do {
                        jsonObject = try self.processedResponse(data, expectedCode: self.expectedCode)
                    } catch let error as NSError {
                        localError = error
                        jsonObject = [:]
                    }
                    completion(jsonObject, localError)
                }
            } catch let err as NSError {
                completion([:], err)
            }
    }
    
    func run(_ url : URL,
        body : [String : Any],
        completion : @escaping (_ result : [String : Any], _ error : NSError?) -> Void) {
            
            let bodyData : Data?
            if (body.count > 0) {
                
                bodyData = try? JSONSerialization.data(
                    withJSONObject: bridgedDictRep(body),
                    options: [])
                
                if (bodyData == nil) {
                    completion([:], NSError(
                        info:"Could not convert data to JSON: \(body)",
                        code:-10201))
                    return
                }
            } else {
                bodyData = nil
            }
            self.run(url, bodyData: bodyData ?? Data(), completion: completion)
    }
    
    fileprivate func optionsToString(_ options : [String : String]) {
        
        var result = ""
        for (_, value) in options {
            if (value.characters.count > 0) {
                let trimmedOption = value.substring(with: (value.characters.index(value.startIndex, offsetBy: 1) ..< value.characters.index(value.endIndex, offsetBy: -1)))
                result = "\(result), \(trimmedOption)"
            }
        }
    }
    
    fileprivate func dataWithRequest(_ request : URLRequest,
        completion:@escaping (_ data : Data?, _ error : NSError?) -> Void) {
            
            let task = self.session.dataTask(with: request, completionHandler: {
                (data : Data?, response : URLResponse?, error : NSError?) in
                var localError : NSError? = error;
                if (error == nil) {
                    if let response = response as? HTTPURLResponse {
                        
                        if !response.isStrictlyValid() {
                            
                            let code = response.statusCode
                            localError = NSError(
                                status: try! JSONSerialization.jsonObject(with: data!,
                                    options:JSONSerialization.ReadingOptions.allowFragments) as Any?,
                                code:code)
                        }
                    } else {
                        let url = response?.url?.absoluteString ?? ""
                        localError = NSError(info:"Bad response format for URL: \(url)",
                            code:-10001)
                    }
                }
                completion(data, localError)
            } as! (Data?, URLResponse?, Error?) -> Void) 
            task.resume()
    }
    
    func request(_ method : String, url : URL, bodyData : Data) throws
        -> NSMutableURLRequest {
            
            let request = NSMutableURLRequest(url:url)
            request.httpBody = bodyData
            request.httpMethod = method;
            request.setValue(self.contentType, forHTTPHeaderField: "Content-Type")
            return request
    }
    
    fileprivate func handleDataRequest(_ method : String,
        url : URL,
        bodyData : Data,
        handler : @escaping (_ data : Data, _ error : NSError?) -> Void) throws
        -> Void {
            
            let request = try self.request(method, url: url, bodyData: bodyData)
            self.dataWithRequest(request as URLRequest) { (data, error) in
                handler(data!, error)
            }
    }
    
    fileprivate func processedResponse(_ data : Data, expectedCode : Int) throws
        -> [String : Any] {
            
            var result : [String : Any] = [:]
            if data.count > 0 {
                let jsonObject = try JSONSerialization.jsonObject(
                    with: data,
                    options: JSONSerialization.ReadingOptions.allowFragments)
                
                if let jsonDict = jsonObject as? [String : Any] {
                    //-- code, if present, must match expectedCode argument
                    if let code = jsonDict["code"] as? Int {
                        if (code != expectedCode) {
                            throw NSError(status:jsonDict["status"], code: code)
                        }
                    }
                    result = jsonDict
                } else {
                    throw NSError(info: "Bad response format", code:-10001)
                }
            }
            return result
    }
}
