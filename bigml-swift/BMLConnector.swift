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
import JavaScriptCore

open class BMLConnector : NSObject {
    
    let mode : BMLMode
    let authToken : String

    var connector : BMLHTTPConnector
    
    public init(username : String, apiKey: String, mode:BMLMode = BMLMode.production) {
        
        self.mode = mode
        self.authToken = "username=\(username);api_key=\(apiKey);"

        self.connector = BMLHTTPConnector()
        super.init()
    }
    
    func serverUrl() -> String {
        
        if let url = UserDefaults.standard.string(forKey: "bigMLAPIServerUrl") {
            return url
        }
        return "https://bigml.io"
    }
    
    func authenticatedUrl(_ uri : String, arguments : [String : Any]) throws -> URL {
        
        var args = ""
        for (key, value) in arguments {
            args = "\(key)=\(value);\(args)"
        }
        let modeSelector = self.mode == BMLMode.development ? "dev/" : ""
        let serverUrl = self.serverUrl()
        guard let url =
            URL(string:"\(serverUrl)/\(modeSelector)andromeda/\(uri)?\(self.authToken)\(args)") else {
                throw NSError(info: "Could not access server",
                    code: -10100,
                    message:["Hint" : "Please review user credentials and server URL" as Any])
        }
        return url
    }
    
    fileprivate func createResourceCompletionBlock(_ result : [String : Any],
        error : NSError?,
        completion : @escaping (_ resource : BMLResource?, _ error : NSError?) -> Void) -> Void {
            
            var localError = error
            if (localError == nil) {
                if let fullUuid = result["resource"] as? String {
                    
                    let resource = BMLMinimalResource(
                        name: result["name"] as? String ?? "",
                        fullUuid: fullUuid,
                        definition: [:])
                    self.trackResourceStatus(resource, completion: completion)
                    
                } else {
                    localError = NSError(info: "Bad response format", code: -10001)
                }
            }
            if (localError != nil) {
                completion(nil, localError)
            }
    }
    
    open func createResource(
        _ type : BMLResourceType,
        name : String,
        options : [String : Any] = [:],
        from : BMLResource,
        completion :@escaping (_ resource : BMLResource?, _ error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl(type.stringValue(), arguments:[:])
                if (from.type == BMLResourceType.file) {
                    
                    if (FileManager.default.fileExists(atPath: from.uuid) &&
                        (try? Data(contentsOf: URL(fileURLWithPath: from.uuid))) != nil) {
                            
                            self.connector.upload(url,
                                filename:name,
                                filePath:from.uuid,
                                body: options) {
                                    (result : [String : Any], error : NSError?) in
                                    
                                    self.createResourceCompletionBlock(result,
                                        error: error,
                                        completion: completion)
                            }
                            
                    } else {
                        self.createResourceCompletionBlock([:],
                            error: NSError(info: "Input file not found", code:-10301),
                            completion: completion)
                    }
                    
                } else {
                    
                    var body = options
                    body.updateValue(name, forKey: "name")
                    if from.type == type && type == BMLResourceType.dataset {
                        body.updateValue(from.fullUuid, forKey: "origin_dataset")
                        
                    } else if from.type != BMLResourceType.project &&
                        from.type != BMLResourceType.whizzmlSource {
                            body.updateValue(from.fullUuid, forKey: from.type.stringValue())
                    }

                    self.connector.post(url, body: body) {
                        (result : [String : Any], error : NSError?) in
                        
                        self.createResourceCompletionBlock(result,
                            error: error,
                            completion: completion)
                    }
                }
            } catch let error as NSError {
                completion(nil, error)
            }
    }

    open func createResource(
        _ type : BMLResourceType,
        name : String,
        options : [String : Any] = [:],
        completion :@escaping (_ resource : BMLResource?, _ error : NSError?) -> Void) {
            
            do {
                
                let url = try self.authenticatedUrl(type.stringValue(), arguments:[:])
                var body = options
                body.updateValue(name, forKey: "name")
                self.connector.post(url, body: body) {
                    (result : [String : Any], error : NSError?) in
                    
                    self.createResourceCompletionBlock(result,
                        error: error,
                        completion: completion)
                }

            } catch let error as NSError {
                completion(nil, error)
            }
    }

    open func listResources(
        _ type : BMLResourceType,
        filters : [String : Any],
        completion : @escaping (_ resources : [BMLResource], _ error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl(type.stringValue(),
                    arguments: bridgedDictRep(filters))
                
                self.connector.get(url) { (jsonObject, error) in
                    
                    var localError = error;
                    var resources : [BMLResource] = []
                    if (error == nil) {
                        if let jsonDict = jsonObject as? [String : Any],
                            let jsonResources = jsonDict["objects"] as? [Any] {

                            resources = jsonResources.map {
                                if let resourceDict = $0 as? [String : Any],
                                    let resource = resourceDict["resource"] as? String {
                                    
                                    return BMLMinimalResource(
                                        name: (resourceDict["name"] as? String ?? "Unnamed resource"),
                                        fullUuid: resource,
                                        definition: resourceDict)
                                } else {
                                    localError = NSError(info:"Bad response format", code:-10001)
                                    return BMLMinimalResource(name: "Wrong Resource",
                                        fullUuid: "Wrong/Resource",
                                        definition: [:])
                                }
                            }
                        } else {
                            localError = NSError(info:"Bad response format", code:-10001)
                        }
                    }
                    completion(resources, localError)
                }
            } catch let error as NSError {
                completion([], error)
            }
    }
    
    open func deleteResource(
        _ type : BMLResourceType,
        uuid : String,
        completion : @escaping (_ error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl("\(type.stringValue())/\(uuid)", arguments: [:])
                self.connector.delete(url) { (error) in
                    completion(error)
                }
            } catch let error as NSError {
                completion(error)
            }
    }
    
    open func updateResource(
        _ type : BMLResourceType,
        uuid : String,
        values : [String : Any],
        completion : @escaping (_ error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl("\(type.stringValue())/\(uuid)", arguments: [:])
                self.connector.put(url, body: values) { (error) in
                    completion(error)
                }
            } catch let error as NSError {
                completion(error)
            }
    }
    
    func getIntermediateResource(
        _ type : BMLResourceType,
        uuid : String,
        completion :@escaping (_ resourceDict : [String : Any], _ error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl("\(type.stringValue())/\(uuid)", arguments:[:])
                self.connector.get(url) { (jsonObject, error) in
                    
                    var localError = error;
                    var resourceDict : [String : Any] = [:]
                    if let jsonDict = jsonObject as? [String : Any],
                        let code = jsonDict["code"] as? Int {
                        resourceDict = jsonDict
                            //-- Workaround to API giving 500 for resources not created correctly
                            if code != 200 &&
                                !(code == 500 && resourceDict["resource_uri"] != nil) {
                                    
                                    localError = NSError(info:"No data retrieved. Code: \(code)",
                                        code:-10002)
                            }
                    } else {
                        localError = NSError(info:"Bad response format", code:-10001)
                    }
                    completion(resourceDict, localError)
                }
            } catch let error as NSError {
                completion([:], error)
            }
    }
    
    open func getResource(
        _ type : BMLResourceType,
        uuid : String,
        completion :@escaping (_ resource : BMLResource?, _ error : NSError?) -> Void) {
            
            self.getIntermediateResource(type, uuid: uuid) { (resourceDict, error) -> Void in

                var localError = error;
                var resource : BMLResource? = nil
                if let code = resourceDict["code"] as? Int {
                    
                    if (code == 200) {
                        if let fullUuid = resourceDict["resource"] as? String {
                            resource = BMLMinimalResource(name: resourceDict["name"] as! String,
                                fullUuid: fullUuid,
                                definition: resourceDict)
                        }
                    } else {
                        localError = NSError(status: resourceDict["status"], code: code)
                    }
                }
                if (resource == nil && localError == nil) {
                    localError = NSError(info: "Bad response format", code:-10001)
                }
                completion(resource, localError)
            }
    }
    
    func trackResourceStatus(
        _ resource : BMLResource,
        completion:@escaping (_ resource : BMLResource?, _ error : NSError?) -> Void) {
    
        if (resource.type == BMLResourceType.project) {
            completion(resource, nil)
        } else {
            self.getIntermediateResource(resource.type, uuid: resource.uuid) { (resourceDict, error) -> Void in
                
                var localError = error
                if (localError == nil) {
                    if let statusDict = resourceDict["status"] as? [String : Any],
                        let statusCodeInt = statusDict["code"] as? Int {
                        let statusCode = BMLResourceStatus(integerLiteral: statusCodeInt)
                        if (statusCode < BMLResourceStatus.waiting) {
                            if let code = statusDict["error"] as? Int {
                                localError = NSError(status: statusDict as Any?, code: code)
                            }
                            resource.status = BMLResourceStatus.failed
                        } else if (statusCode < BMLResourceStatus.ended) {
                            delay(1.0) {
                                self.trackResourceStatus(resource, completion: completion)
                            }
                            if (resource.status != statusCode) {
                                resource.status = statusCode
                                if let progress = statusDict["progress"] as? Float {
                                    resource.progress = progress
                                }
                            }
                        } else if (statusCode == BMLResourceStatus.ended) {
                            resource.status = statusCode
                            resource.jsonDefinition = resourceDict
                            completion(resource, error)
                        }
                    } else {
                        localError = NSError(info: "Bad response format: no status found", code: -10001)
                    }
                }
                if (localError != nil) {
                    print("Tracking error \(localError)", terminator: "")
                    resource.status = BMLResourceStatus.failed
                    completion(nil, localError)
                }
            }
        }
    }

}
