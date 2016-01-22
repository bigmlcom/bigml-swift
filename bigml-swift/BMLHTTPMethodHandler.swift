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

extension NSHTTPURLResponse {
    
    func isStrictlyValid() -> Bool {
        return self.statusCode >= 200 && self.statusCode <= 206
    }
}

struct BMLHTTPMethodHandler {
    
    private let session : NSURLSession
    let method : String
    let expectedCode : Int
    let contentType : String
    
    private static func initializeSession() -> NSURLSession {
        
        let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        configuration.HTTPAdditionalHeaders = [ "Content-Type": "application/json" ];
        
        return NSURLSession(configuration : configuration)
    }
    
    init(method : String,
        expectedCode : Int,
        contentType : String = "application/json; charset=utf-8") {
            
            self.method = method
            self.expectedCode = expectedCode
            self.contentType = contentType
            self.session = BMLHTTPMethodHandler.initializeSession()
    }
    
    func run(url : NSURL,
        bodyData : NSData,
        completion : (result : [String : AnyObject], error : NSError?) -> Void) {
            
            do {
                try self.handleDataRequest(self.method, url: url, bodyData: bodyData) {
                    (data, error) in
                    
                    var localError = error;
                    var jsonObject : [String : AnyObject]
                    do {
                        jsonObject = try self.processedResponse(data, expectedCode: self.expectedCode)
                    } catch let error as NSError {
                        localError = error
                        jsonObject = [:]
                    }
                    completion(result: jsonObject, error: localError)
                }
            } catch let err as NSError {
                completion(result: [:], error: err)
            }
    }
    
    func run(url : NSURL,
        body : [String : Any],
        completion : (result : [String : AnyObject], error : NSError?) -> Void) {
            
            let bodyData : NSData?
            if (body.count > 0) {
                
                bodyData = try? NSJSONSerialization.dataWithJSONObject(
                    bridgedDictRep(body),
                    options: [])
                
                if (bodyData == nil) {
                    completion(result: [:], error: NSError(
                        info:"Could not convert data to JSON: \(body)",
                        code:-10201))
                    return
                }
            } else {
                bodyData = nil
            }
            self.run(url, bodyData: bodyData ?? NSData(), completion: completion)
    }
    
    private func optionsToString(options : [String : String]) {
        
        var result = ""
        for (_, value) in options {
            if (value.characters.count > 0) {
                let trimmedOption = value.substringWithRange(Range<String.Index>(
                    start: value.startIndex.advancedBy(1), end: value.endIndex.advancedBy(-1)))
                result = "\(result), \(trimmedOption)"
            }
        }
    }
    
    private func dataWithRequest(request : NSURLRequest,
        completion:(data : NSData!, error : NSError!) -> Void) {
            
            let task = self.session.dataTaskWithRequest(request) {
                (data : NSData?, response : NSURLResponse?, error : NSError?) in
                var localError : NSError? = error;
                if (error == nil) {
                    if let response = response as? NSHTTPURLResponse {
                        
                        if !response.isStrictlyValid() {
                            
                            let code = response.statusCode
                            localError = NSError(
                                status: try? NSJSONSerialization.JSONObjectWithData(data!,
                                    options:NSJSONReadingOptions.AllowFragments)
                                    ?? [:],
                                code:code)
                        }
                    } else {
                        let url = response?.URL?.absoluteString ?? ""
                        localError = NSError(info:"Bad response format for URL: \(url)",
                            code:-10001)
                    }
                }
                completion(data: data, error: localError)
            }
            task.resume()
    }
    
    func request(method : String, url : NSURL, bodyData : NSData) throws
        -> NSMutableURLRequest {
            
            let request = NSMutableURLRequest(URL:url)
            request.HTTPBody = bodyData
            request.HTTPMethod = method;
            request.setValue(self.contentType, forHTTPHeaderField: "Content-Type")
            return request
    }
    
    private func handleDataRequest(method : String,
        url : NSURL,
        bodyData : NSData,
        handler : (data : NSData, error : NSError?) -> Void) throws
        -> Void {
            
            let request = try self.request(method, url: url, bodyData: bodyData)
            self.dataWithRequest(request) { (data, error) in
                handler(data: data, error: error)
            }
    }
    
    private func processedResponse(data : NSData, expectedCode : Int) throws
        -> [String : AnyObject] {
            
            var result : [String : AnyObject] = [:]
            if data.length > 0 {
                let jsonObject = try NSJSONSerialization.JSONObjectWithData(
                    data,
                    options: NSJSONReadingOptions.AllowFragments)
                
                if let jsonDict = jsonObject as? [String : AnyObject] {
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
