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

class BigMLKitConnectorTests: BigMLKitConnectorBaseTest {
    
    func test0Create1Datasource() {
        
        self.runTest("testCreateDatasource") { (exp) in
            
            let filePath = Bundle.pathForResource("wines.csv")
            let resource = BMLMinimalResource(name:"testCreateDatasource",
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: "testCreateDatasource",
                options: [:],
                from: resource) { (resource, error) -> Void in
                    
                XCTAssert(resource != nil && error == nil)
                exp.fulfill()
            }
        }
    }
    
    func test0Create1RemoteDatasource() {
        
        self.runTest("testCreateRemoteDatasource") { (exp) in
            
            self.connector!.createResource(BMLResourceType.Source,
                name: "testCreateRemoteDatasource",
                options: ["remote" : "s3://bigml-public/csv/iris.csv"]) {
                    (resource, error) -> Void in
                    
                    XCTAssert(resource != nil && error == nil)
                    exp.fulfill()
            }
        }
    }
    
    func test0Create3Anomaly() {
        
        self.runTest("testCreateAnomaly") { (exp) in
            self.connector!.createResource(BMLResourceType.Anomaly,
                name: "testCreateAnomaly",
                options: [:],
                from: BigMLKitConnectorBaseTest.aDataset!) { (resource, error) -> Void in
                    XCTAssert(resource != nil && error == nil)
                    exp.fulfill()
            }
        }
    }
    
    func testCreateDatasourceWithOptions1() {
        
        self.runTest("testCreateDatasourceWithOptions1") { (exp) in
            
            let filePath = Bundle.pathForResource("iris.csv")
            let resource = BMLMinimalResource(name:"testCreateDatasourceWithOptions1",
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: "testCreateDatasourceWithOptions1",
                options: ["source_parser" : ["header" : false, "missing_tokens" : ["x"]],
                    "term_analysis" : ["enabled" : false]],
                from: resource) { (resource, error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    exp.fulfill()
            }
        }
    }
    
    func testCreateDatasourceWithOptions2() {
        
        self.runTest("testCreateDatasourceWithOptions2") { (exp) in
            
            let filePath = Bundle.pathForResource("spam.csv")
            let resource = BMLMinimalResource(name:"testCreateDatasourceWithOptions2",
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: "testCreateDatasourceWithOptions2",
                options: ["term_analysis" : ["case_sensitive" : true,
                    "enabled" : true, "stem_words" : false]],
                from: resource) { (resource, error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    exp.fulfill()
            }
        }
    }
    
    func testCreateDatasourceWithOptions3() {
        
        self.runTest("testCreateDatasourceWithOptions3") { (exp) in
            
            let filePath = Bundle.pathForResource("spam.csv")
            let resource = BMLMinimalResource(name:"testCreateDatasourceWithOptions3",
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Source,
                name: "testCreateDatasourceWithOptions3",
                options: [:],
                from: resource) { (resource, error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    if let resource = resource {
                        self.connector!.updateResource(resource.type,
                            uuid: resource.uuid,
                            values: [
                                "fields" : [
                                    "000001" : [
                                        "optype" : "text",
                                        "term_analysis" : [
                                            "case_sensitive" : true,
                                            "stem_words" : true,
                                            "use_stopwords" : false,
                                            "language" : "en"]]]]) { error -> Void in
                                                
                                                XCTAssert(error == nil)
                                                self.connector!.getIntermediateResource(
                                                    resource.type,
                                                    uuid: resource.uuid) {
                                                        (resourceDict, error) -> Void in
                                                        XCTAssert(error == nil)
                                                        exp.fulfill()
                                                }
                        }
                    }
                    XCTAssert(resource != nil && error == nil)
            }
        }
    }
    
    func testCreateDatasourceFail() {
        
        self.runTest("testCreateDatasourceFail") { (exp) in
            
            let filePath = Bundle.pathForResource("iris.csv")
            let resource = BMLMinimalResource(name:"testCreateDatasourceFail",
                type:BMLResourceType.File,
                uuid:filePath!)
            self.connector!.createResource(BMLResourceType.Dataset,
                name: "testCreateDatasourceFail",
                options: [:],
                from: resource) {
                    (resource, error) -> Void in
                    exp.fulfill()
                    XCTAssert(error != nil)
            }
        }
    }

    func test1Create1DatasetWithOptions() {
        
        self.runTest("testCreateDatasetWithOptions") { (exp) in
            self.connector!.createResource(BMLResourceType.Dataset,
                name: "testCreateDatasetWithOptions",
                options: ["size" : 400,
                    "fields" : ["000001" : ["name" : "field_1"]]],
                from: BigMLKitConnectorBaseTest.aSource!) { (resource, error) -> Void in
                    exp.fulfill()
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
            }
        }
    }
    
    func test1Clone1DatasetWithOptions() {
        
        self.runTest("testCloneDatasetWithOptions") { (exp) in
            self.connector!.createResource(BMLResourceType.Dataset,
                name: "testCloneDatasetWithOptions",
                options: ["size" : 400,
                    "fields" : ["000001" : ["name" : "field_1"]]],
                from: BigMLKitConnectorBaseTest.aSource!) {
                    (resource, error) -> Void in
                    
                    self.connector!.createResource(BMLResourceType.Dataset,
                        name: "clonedDataset",
                        options: ["sample_rate" : 0.8],
                        from: resource!) { (resource, error) -> Void in

                            if let error = error {
                                print("Error: \(error)")
                            }
                            XCTAssert(resource != nil && error == nil)
                            exp.fulfill()
                    }
            }
        }
    }
    
    func test1Create1DatasetWithOptionsFail() {
        
        self.runTest("testCreateDatasetWithOptionsFail") { (exp) in
            self.connector!.createResource(BMLResourceType.Dataset,
                name: "testCreateDatasetWithOptionsFail",
                options: ["size" : "400",
                    "fields" : ["000001" : ["name" : "field_1"]]],
                from: BigMLKitConnectorBaseTest.aSource!) { (resource, error) -> Void in
                    exp.fulfill()
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource == nil && error != nil)
            }
        }
    }
    
    func testCreateDatasetFromCSVFail() {
        
        self.runTest("testCreateDatasetFromCSVFail") { (exp) in
            let resource = BMLMinimalResource(name: "testCreateDatasetFromCSVFail",
                type: BMLResourceType.File, uuid:Bundle.pathForResource("iris.csv")!)
            self.connector!.createResource(BMLResourceType.Dataset,
                name: "testCreateDatasetFromCSVFail",
                options: [:],
                from: resource) { (resource, error) -> Void in

                    XCTAssert(resource == nil && error?.code == 400)
                    exp.fulfill()
            }
        }
    }
    
    func testCreateDatasetFromCluster() {
        
        self.runTest("testCreateDatasetFromCluster") { (exp) in

            self.connector!.createResource(BMLResourceType.Cluster,
                name: "testCreateDatasetFromCluster",
                from: BigMLKitConnectorBaseTest.aDataset!) { (resource, error) -> Void in
                    
                    self.connector!.createResource(BMLResourceType.Dataset,
                        name: "testCreateDatasetFromCluster",
                        from: resource!) { (resource, error) -> Void in
                            
                            XCTAssert(resource == nil && error?.code == 500)
                            exp.fulfill()
                    }
            }
        }
    }
    
    func testCreateProject() {
        
        self.runTest("testCreateProject") { (exp) in
            let resource = BMLMinimalResource(name:"testCreateProject",
                type:BMLResourceType.Project,
                uuid:"")
            self.connector!.createResource(BMLResourceType.Project,
                name: "testCreateProject",
                options: ["description" : "This is a test project", "tags" : ["a", "b", "c"]],
                from: resource) { (resource, error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    print("Project: \(resource?.uuid)")
                    XCTAssert(resource != nil && error == nil)
                    exp.fulfill()
            }
        }
    }
    
    func testUpdateProject() {
        
        self.runTest("testUpdateProject") { (exp) in
            let resource = BMLMinimalResource(name:"testCreateProject",
                type:BMLResourceType.Project, uuid:"")
            self.connector!.createResource(BMLResourceType.Project,
                name: "testCreateProject",
                options: ["description" : "This is a test project", "tags" : ["a", "b", "c"]],
                from: resource) { (resource, error) -> Void in
                    if let resource = resource {
                        self.connector!.updateResource(BMLResourceType.Project,
                            uuid: resource.uuid,
                            values: ["name" : "testUpdateProject"]) { (error) -> Void in
                                if (error == nil) {
                                    self.connector!.getResource(BMLResourceType.Project,
                                        uuid: resource.uuid) {
                                            (resource, error) -> Void in
                                            XCTAssert(error != nil &&
                                                resource?.name == "testUpdateProject")
                                    }
                                } else {
                                    XCTAssert(false)
                                }
                                exp.fulfill()
                        }
                    } else {
                        print("Error: \(error)")
                        XCTAssert(resource != nil && error == nil)
                        exp.fulfill()
                    }
            }
        }
    }
    
    func testDeleteProject() {
        
        self.runTest("testDeleteProject") { (exp) in
            self.connector!.listResources(BMLResourceType.Project,
                filters: ["limit" : 5]) {
                    (resources, error) -> Void in
                    self.connector!.deleteResource(BMLResourceType.Project,
                        uuid: resources[0].uuid) {
                            (error) -> Void in
                            
                            if (error == nil) {
                                self.connector!.getResource(BMLResourceType.Project,
                                    uuid: resources[0].uuid) {
                                        (resource, error) -> Void in
                                        
                                        XCTAssert(error != nil)
                                        exp.fulfill()
                                }
                            } else {
                                XCTAssert(false)
                                exp.fulfill()
                            }
                    }
            }
        }
    }
    
    func testListDataset() {
        
        self.runTest("testListDataset") { (exp) in
            self.connector!.listResources(BMLResourceType.Dataset,
                filters: ["limit" : 5]) {
                    (resources, error) -> Void in
                    XCTAssert(resources.count == 5 && error == nil)
                    exp.fulfill()
            }
        }
    }
    
    func testGetDataset() {
        
        self.runTest("testGetDataset") { (exp) in
            let source = BigMLKitConnectorBaseTest.aDataset!
            self.connector!.getResource(source.type, uuid: source.uuid) {
                (resource, error) -> Void in
                XCTAssert(error == nil && resource != nil)
                exp.fulfill()
            }
        }
    }
    
    func testDeleteDataset() {
        
        self.runTest("testDeleteDataset") { (exp) in
            self.connector!.listResources(BMLResourceType.Dataset,
                filters: ["limit" : 5]) {
                    (resources, error) -> Void in
                    self.connector!.deleteResource(BMLResourceType.Dataset,
                        uuid: resources[0].uuid) {
                            (error) -> Void in
                            if (error == nil) {
                                self.connector!.getResource(BMLResourceType.Source,
                                    uuid: resources[0].uuid) {
                                        (resource, error) -> Void in
                                        XCTAssert(error != nil)
                                }
                            } else {
                                XCTAssert(false)
                            }
                            exp.fulfill()
                    }
            }
        }
    }
    
    func testDeleteDatasetFail() {
        
        self.runTest("testDeleteDatasetFail") { (exp) in
            self.connector!.deleteResource(BMLResourceType.Source,
                uuid: "testDeleteDatasetFail") {
                    (error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(error != nil)
                    exp.fulfill()
            }
        }
    }
    
    func testUpdateDataset() {
        
        self.runTest("testUpdateDataset") { (exp) in
            self.connector!.listResources(BMLResourceType.Dataset,
                filters: ["limit" : 5]) {
                    (resources, error) -> Void in
                    self.connector!.updateResource(BMLResourceType.Dataset,
                        uuid: resources[0].uuid,
                        values: ["name" : "testUpdateDataset"]) { (error) -> Void in
                            if (error == nil) {
                                self.connector!.getResource(BMLResourceType.Source,
                                    uuid: resources[0].uuid) {
                                        (resource, error) -> Void in
                                        XCTAssert(error == nil &&
                                            resource?.name == "testUpdateDataset")
                                        exp.fulfill()
                                }
                            } else {
                                XCTAssert(false)
                                exp.fulfill()
                            }
                    }
            }
        }
    }
    
    func testUpdateDatasetFail() {
        
        self.runTest("testUpdateDatasetFail") { (exp) in
            self.connector!.listResources(BMLResourceType.Dataset,
                filters: ["limit" : 5]) {
                    (resources, error) -> Void in
                    self.connector!.updateResource(BMLResourceType.Dataset,
                        uuid: resources[0].uuid,
                        values: [:]) { (error) -> Void in
                            
                            XCTAssert(error != nil)
                            exp.fulfill()
                    }
            }
        }
    }
    
    func testGetDatasetFail() {
        
        self.runTest("testGetDatasetFail") { (exp) in
            self.connector!.getResource(BMLResourceType.Source,
                uuid: "no-uuid") {
                    (resource, error) -> Void in
                    XCTAssert(error != nil && resource == nil)
                    exp.fulfill()
            }
        }
    }
    
    func testRunScoreTest() {
        
        self.runTest("testRunScoreTest") { (exp) in
            
            
            self.connector!.createResource(BMLResourceType.Anomaly,
                name: "testCreateAnomaly",
                options: [:],
                from: BigMLKitConnectorBaseTest.altDataset!) {
                    (resource, error) -> Void in
                    XCTAssert(resource != nil && error == nil)
                    let anAnomaly = resource
                    self.connector!.getResource(anAnomaly!.type,
                        uuid: anAnomaly!.uuid) {
                            (resource, error) -> Void in
                            
                            XCTAssert(error == nil && resource != nil)
                            let a = Anomaly(anomaly: resource!)
                            let _ = a.score(["Country" : "France",
                                "Price" : 20,
                                "Total Sales" : 133])
                            
                            exp.fulfill()
                    }
            }
        }
    }
    
    func testCreatePrediction() {
        
        self.runTest("testCreatePrediction") { (exp) in
            
            self.connector!.createResource(BMLResourceType.Model,
                name: "testCreatePrediction",
                from: BigMLKitConnectorBaseTest.aDataset!) { (resource, error) -> Void in

                    self.connector!.createResource(BMLResourceType.Prediction,
                        name: "testCreatePrediction",
                        options: ["input_data" : ["sepal length" : 5,
                            "sepal width" : 2.5]],
                        from: resource!) { (resource, error) -> Void in

                            XCTAssert(error == nil && resource != nil)
                            exp.fulfill()
                    }
            }
        }
    }
}
