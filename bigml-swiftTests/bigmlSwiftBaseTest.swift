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
#if os(iOS)
    import bigmlSwift
#else
    import bigmlSwift_macOS
#endif

extension Bundle {
    
    class func pathForResource(_ resource : String) -> String? {
        
        for bundle in Bundle.allBundles {
            if let filePath = bundle.path(forResource: resource, ofType:.none) {
                return filePath
            }
        }
        return nil
    }
}

class BigMLKitTestCredentials {
    
    class func credentials() -> NSDictionary {
        return NSDictionary.init(contentsOfFile:Bundle.pathForResource("credentials.plist")!)!
    }
    
    class func username() -> String {
        return self.credentials()["username"] as! String
    }
    
    class func apiKey() -> String {
        return self.credentials()["apiKey"] as! String
    }
}

class BigMLKitConnectorBaseTest: XCTestCase {
    
    private func __once() {

        BigMLKitConnectorBaseTest.aSource = self.createDatasource("iris.csv")
        BigMLKitConnectorBaseTest.aDataset = self.createDataset("iris.csv")
        BigMLKitConnectorBaseTest.altDataset = self.createDataset("wines.csv")
    }
    
    static var token : Int = 0
    static var aSource : BMLResource? = nil
    static var aDataset : BMLResource? = nil
    static var altDataset : BMLResource? = nil
    
    var connector : BMLConnector?
    
    func createDatasource(_ file : String,
        options : [BMLResourceType : [String : Any]] = [:])
        -> BMLResource? {
            
            var result : BMLResource? = nil
            let semaphore = DispatchSemaphore(value: 0)
            let filePath = Bundle.pathForResource(file)
            let resource = BMLMinimalResource(name:file,
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: file,
                options: options[BMLResourceType.Source] ?? [:],
                from: resource) { (resource, error) -> Void in
                    
                    XCTAssert(resource != nil)
                    result = resource
                    semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            return result
    }

    func createDataset(_ datasource : BMLResource,
        options : [BMLResourceType : [String : Any]] = [:])
        -> BMLResource? {
        
            var result : BMLResource? = nil
            let semaphore = DispatchSemaphore(value: 0)
            self.connector!.createResource(BMLResourceType.Dataset,
                name: datasource.name,
                options: options[BMLResourceType.Dataset] ?? [:],
                from: datasource) { (resource, error) -> Void in
                    
                    XCTAssert(resource != nil && error == nil)
                    result = resource
                    semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            return result
    }
    
    func createDataset(_ file : String,
        options : [BMLResourceType : [String : Any]] = [:])
        -> BMLResource? {
            
            var result : BMLResource? = nil
            let semaphore = DispatchSemaphore(value: 0)
            let filePath = Bundle.pathForResource(file)
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
                                        semaphore.signal()
                                }
                        }
                    } else {
                        
                        self.connector!.createResource(BMLResourceType.Dataset,
                            name: file,
                            options: options[BMLResourceType.Dataset] ?? [:],
                            from: resource!) { (resource, error) -> Void in
                                XCTAssert(resource != nil && error == nil)
                                result = resource
                                semaphore.signal()
                        }
                    }
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            return result
    }

    override func setUp() {
        super.setUp()
        
        self.connector = BMLConnector(username:BigMLKitTestCredentials.username(),
            apiKey:BigMLKitTestCredentials.apiKey(),
            mode:BMLMode.Production)
        
        self.__once()
    }
    
    func runTest(_ name : String, test : (XCTestExpectation) -> Void) {
        
        let exp = self.expectation(description: name)
        test(exp)
        self.waitForExpectations(timeout: 360) { (error) in
            if error != nil {
                print("Expect error \(error)")
            }
        }
    }
}

