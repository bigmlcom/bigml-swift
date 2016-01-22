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

public class BMLConnector : NSObject {
    
    let mode : BMLMode
    let authToken : String

    var connector : BMLHTTPConnector
    
    public init(username : String, apiKey: String, mode:BMLMode = BMLMode.Production) {
        
        self.mode = mode
        self.authToken = "username=\(username);api_key=\(apiKey);"

        self.connector = BMLHTTPConnector()
        super.init()
    }
    
    func serverUrl() -> String {
        
        if let url = NSUserDefaults.standardUserDefaults().stringForKey("bigMLAPIServerUrl") {
            return url
        }
        return "https://bigml.io"
    }
    
    func authenticatedUrl(uri : String, arguments : [String : AnyObject]) throws -> NSURL {
        
        var args = ""
        for (key, value) in arguments {
            args = "\(key)=\(value);\(args)"
        }
        let modeSelector = self.mode == BMLMode.Development ? "dev/" : ""
        let serverUrl = self.serverUrl()
        guard let url =
            NSURL(string:"\(serverUrl)/\(modeSelector)andromeda/\(uri)?\(self.authToken)\(args)") else {
                throw NSError(info: "Could not access server",
                    code: -10100,
                    message:["Hint" : "Please review user credentials and server URL"])
        }
        return url
    }
    
    private func createResourceCompletionBlock(result : [String : AnyObject],
        error : NSError?,
        completion : (resource : BMLResource?, error : NSError?) -> Void) -> Void {
            
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
                completion(resource : nil, error : localError)
            }
    }
    
    public func createResource(
        type : BMLResourceType,
        name : String,
        options : [String : Any] = [:],
        from : BMLResource,
        completion :(resource : BMLResource?, error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl(type.stringValue(), arguments:[:])
                if (from.type == BMLResourceType.File) {
                    
                    if (NSFileManager.defaultManager().fileExistsAtPath(from.uuid) &&
                        NSData(contentsOfFile:from.uuid) != nil) {
                            
                            self.connector.upload(url,
                                filename:name,
                                filePath:from.uuid,
                                body: options) {
                                    (result : [String : AnyObject], error : NSError?) in
                                    
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
                    if from.type == type && type == BMLResourceType.Dataset {
                        body.updateValue(from.fullUuid, forKey: "origin_dataset")
                        
                    } else if from.type != BMLResourceType.Project &&
                        from.type != BMLResourceType.WhizzmlSource {
                            body.updateValue(from.fullUuid, forKey: from.type.stringValue())
                    }

                    self.connector.post(url, body: body) {
                        (result : [String : AnyObject], error : NSError?) in
                        
                        self.createResourceCompletionBlock(result,
                            error: error,
                            completion: completion)
                    }
                }
            } catch let error as NSError {
                completion(resource: nil, error: error)
            }
    }

    public func createResource(
        type : BMLResourceType,
        name : String,
        options : [String : Any] = [:],
        completion :(resource : BMLResource?, error : NSError?) -> Void) {
            
            do {
                
                let url = try self.authenticatedUrl(type.stringValue(), arguments:[:])
                var body = options
                body.updateValue(name, forKey: "name")
                self.connector.post(url, body: body) {
                    (result : [String : AnyObject], error : NSError?) in
                    
                    self.createResourceCompletionBlock(result,
                        error: error,
                        completion: completion)
                }

            } catch let error as NSError {
                completion(resource: nil, error: error)
            }
    }

    public func listResources(
        type : BMLResourceType,
        filters : [String : Any],
        completion : (resources : [BMLResource], error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl(type.stringValue(),
                    arguments: bridgedDictRep(filters))
                
                self.connector.get(url) { (jsonObject, error) in
                    
                    var localError = error;
                    var resources : [BMLResource] = []
                    if (error == nil) {
                        if let jsonDict = jsonObject as? [String : AnyObject],
                            jsonResources = jsonDict["objects"] as? [AnyObject] {

                            resources = jsonResources.map {
                                if let resourceDict = $0 as? [String : AnyObject],
                                    resource = resourceDict["resource"] as? String {
                                    
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
                    completion(resources: resources, error: localError)
                }
            } catch let error as NSError {
                completion(resources: [], error: error)
            }
    }
    
    public func deleteResource(
        type : BMLResourceType,
        uuid : String,
        completion : (error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl("\(type.stringValue())/\(uuid)", arguments: [:])
                self.connector.delete(url) { (error) in
                    completion(error: error)
                }
            } catch let error as NSError {
                completion(error: error)
            }
    }
    
    public func updateResource(
        type : BMLResourceType,
        uuid : String,
        values : [String : Any],
        completion : (error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl("\(type.stringValue())/\(uuid)", arguments: [:])
                self.connector.put(url, body: values) { (error) in
                    completion(error: error)
                }
            } catch let error as NSError {
                completion(error: error)
            }
    }
    
    func getIntermediateResource(
        type : BMLResourceType,
        uuid : String,
        completion :(resourceDict : [String : AnyObject], error : NSError?) -> Void) {
            
            do {
                let url = try self.authenticatedUrl("\(type.stringValue())/\(uuid)", arguments:[:])
                self.connector.get(url) { (jsonObject, error) in
                    
                    var localError = error;
                    var resourceDict : [String : AnyObject] = [:]
                    if let jsonDict = jsonObject as? [String : AnyObject],
                        code = jsonDict["code"] as? Int {
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
                    completion(resourceDict : resourceDict, error : localError)
                }
            } catch let error as NSError {
                completion(resourceDict: [:], error: error)
            }
    }
    
    public func getResource(
        type : BMLResourceType,
        uuid : String,
        completion :(resource : BMLResource?, error : NSError?) -> Void) {
            
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
                completion(resource : resource, error : localError)
            }
    }
    
    func trackResourceStatus(
        resource : BMLResource,
        completion:(resource : BMLResource?, error : NSError?) -> Void) {
    
        if (resource.type == BMLResourceType.Project) {
            completion(resource: resource, error: nil)
        } else {
            self.getIntermediateResource(resource.type, uuid: resource.uuid) { (resourceDict, error) -> Void in
                
                var localError = error
                if (localError == nil) {
                    if let statusDict = resourceDict["status"] as? [String : AnyObject],
                        statusCodeInt = statusDict["code"] as? Int {
                        let statusCode = BMLResourceStatus(integerLiteral: statusCodeInt)
                        if (statusCode < BMLResourceStatus.Waiting) {
                            if let code = statusDict["error"] as? Int {
                                localError = NSError(status: statusDict, code: code)
                            }
                            resource.status = BMLResourceStatus.Failed
                        } else if (statusCode < BMLResourceStatus.Ended) {
                            delay(1.0) {
                                self.trackResourceStatus(resource, completion: completion)
                            }
                            if (resource.status != statusCode) {
                                resource.status = statusCode
                                if let progress = statusDict["progress"] as? Float {
                                    resource.progress = progress
                                }
                            }
                        } else if (statusCode == BMLResourceStatus.Ended) {
                            resource.status = statusCode
                            resource.jsonDefinition = resourceDict
                            completion(resource: resource, error: error)
                        }
                    } else {
                        localError = NSError(info: "Bad response format: no status found", code: -10001)
                    }
                }
                if (localError != nil) {
                    print("Tracking error \(localError)", terminator: "")
                    resource.status = BMLResourceStatus.Failed
                    completion(resource: nil, error: localError)
                }
            }
        }
    }

}
