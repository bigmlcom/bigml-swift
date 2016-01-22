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

import XCTest
import bigmlSwift

extension NSBundle {
    
    class func pathForResource(resource : String) -> String? {
        
        for bundle in NSBundle.allBundles() {
            if let filePath = bundle.pathForResource(resource, ofType:.None) {
                return filePath
            }
        }
        return nil
    }
}

class BigMLKitTestCredentials {
    
    class func credentials() -> NSDictionary {
        return NSDictionary.init(contentsOfFile:NSBundle.pathForResource("credentials.plist")!)!
    }
    
    class func username() -> String {
        return self.credentials()["username"] as! String
    }
    
    class func apiKey() -> String {
        return self.credentials()["apiKey"] as! String
    }
}

class BigMLKitConnectorBaseTest: XCTestCase {
    
    static var token : dispatch_once_t = 0
    static var aSource : BMLResource? = nil
    static var aDataset : BMLResource? = nil
    static var altDataset : BMLResource? = nil
    
    var connector : BMLConnector?
    
    func createDatasource(file : String,
        options : [BMLResourceType : [String : Any]] = [:])
        -> BMLResource? {
            
            var result : BMLResource? = nil
            let semaphore = dispatch_semaphore_create(0)
            let filePath = NSBundle.pathForResource(file)
            let resource = BMLMinimalResource(name:file,
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: file,
                options: options[BMLResourceType.Source] ?? [:],
                from: resource) { (resource, error) -> Void in
                    
                    XCTAssert(resource != nil)
                    result = resource
                    dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            return result
    }

    func createDataset(datasource : BMLResource,
        options : [BMLResourceType : [String : Any]] = [:])
        -> BMLResource? {
        
            var result : BMLResource? = nil
            let semaphore = dispatch_semaphore_create(0)
            self.connector!.createResource(BMLResourceType.Dataset,
                name: datasource.name,
                options: options[BMLResourceType.Dataset] ?? [:],
                from: datasource) { (resource, error) -> Void in
                    
                    XCTAssert(resource != nil && error == nil)
                    result = resource
                    dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            return result
    }
    
    func createDataset(file : String,
        options : [BMLResourceType : [String : Any]] = [:])
        -> BMLResource? {
            
            var result : BMLResource? = nil
            let semaphore = dispatch_semaphore_create(0)
            let filePath = NSBundle.pathForResource(file)
            let resource = BMLMinimalResource(name:file,
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: file,
                options: [:],
                from: resource) { (resource, error) -> Void in
                    
                    XCTAssert(resource != nil)
                    BigMLKitConnectorBaseTest.aSource = resource

                    if let opts = options[BMLResourceType.Source] {
                        self.connector!.updateResource(resource!.type,
                            uuid: resource!.uuid,
                            values: opts) { error -> Void in

                                self.connector!.createResource(BMLResourceType.Dataset,
                                    name: file,
                                    options: options[BMLResourceType.Dataset] ?? [:],
                                    from: resource!) { (resource, error) -> Void in
                                        XCTAssert(resource != nil && error == nil)
                                        result = resource
                                        dispatch_semaphore_signal(semaphore)
                                }
                        }
                    } else {
                        
                        self.connector!.createResource(BMLResourceType.Dataset,
                            name: file,
                            options: options[BMLResourceType.Dataset] ?? [:],
                            from: resource!) { (resource, error) -> Void in
                                XCTAssert(resource != nil && error == nil)
                                result = resource
                                dispatch_semaphore_signal(semaphore)
                        }
                    }
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            return result
    }

    override func setUp() {
        super.setUp()
        
        self.connector = BMLConnector(username:BigMLKitTestCredentials.username(),
            apiKey:BigMLKitTestCredentials.apiKey(),
            mode:BMLMode.Production)
        
        dispatch_once(&BigMLKitConnectorBaseTest.token) {

            BigMLKitConnectorBaseTest.aSource = self.createDatasource("iris.csv")
            BigMLKitConnectorBaseTest.aDataset = self.createDataset("iris.csv")
            BigMLKitConnectorBaseTest.altDataset = self.createDataset("wines.csv")
        }
    }
    
    func runTest(name : String, test : XCTestExpectation -> Void) {
        
        let exp = self.expectationWithDescription(name)
        test(exp)
        self.waitForExpectationsWithTimeout(360) { (error) in
            if error != nil {
                print("Expect error \(error)")
            }
        }
    }
}

