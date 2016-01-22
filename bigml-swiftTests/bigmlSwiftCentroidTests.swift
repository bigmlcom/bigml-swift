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

class BigMLKitConncetorCentroidTests: BigMLKitConnectorBaseTest {
    
    func localCentroidFromCluster(modelId : String,
        argsByName : [String : AnyObject],
        argsById : [String : AnyObject],
        completion : (CentroidInfo, CentroidInfo) -> ()) {
            
            self.connector!.getResource(BMLResourceType.Cluster, uuid: modelId) {
                (resource, error) -> Void in
                
                if let model = resource {
                    let pCluster = Cluster(jsonCluster: model.jsonDefinition)
                    let prediction1 = pCluster.centroid(
                        argsByName,
                        byName: true)
                    
                    let prediction2 = pCluster.centroid(
                        argsById,
                        byName: false)
                    
                    completion(prediction1, prediction2)
                    
                } else {
                    completion(CentroidInfo(0, "", Double.NaN), CentroidInfo(0, "", Double.NaN))
                }
            }
    }
    
    func localCentroidFromDataset(dataset : BMLMinimalResource,
        argsByName : [String : AnyObject],
        argsById : [String : AnyObject],
        completion : (CentroidInfo, CentroidInfo) -> ()) {
            
            self.connector!.createResource(BMLResourceType.Cluster,
                name: dataset.name,
                options: [:],
                from: dataset) { (resource, error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    
                    if let resource = resource {
                        
                        self.localCentroidFromCluster(resource.uuid,
                            argsByName: argsByName,
                            argsById: argsById) {
                                (prediction1 : CentroidInfo, prediction2 : CentroidInfo) in
                                
                                self.connector!.deleteResource(BMLResourceType.Cluster, uuid: resource.uuid) {
                                    (error) -> Void in
                                    XCTAssert(error == nil, "Pass")
                                    completion(prediction1, prediction2)
                                }
                        }
                        
                    } else {
                        completion(CentroidInfo(0, "", Double.NaN), CentroidInfo(0, "", Double.NaN))
                    }
            }
    }

    func testIrisCentroid() {
        
        self.runTest("testIrisCentroid") { (exp) in
            
            self.localCentroidFromDataset(BigMLKitConnectorBaseTest.aDataset as! BMLMinimalResource,
                argsByName: [
                    "sepal length": 6.02,
                    "sepal width": 3.15,
                    "petal length": 4.07,
                    "petal width": 1.51,
                    "species": "Iris-setosa"],
                argsById: [
                    "000000": 6.02,
                    "000001": 3.15,
                    "000002": 4.07,
                    "000003": 1.51,
                    "000004": "Iris-setosa"]) {
                        (centroid1 : CentroidInfo, centroid2 : CentroidInfo) in
                        
                        XCTAssert(centroid1.centroidName == "Cluster 0" &&
                            compareDoubles(centroid1.centroidDistance, d2: 0.207))
                        
                        XCTAssert(centroid2.centroidName == "Cluster 0" &&
                            compareDoubles(centroid2.centroidDistance, d2: 20.207))
                        
                        exp.fulfill()
            }
        }
    }
    
    func testSalariesCentroid() {
        
        self.runTest("testWinesCentroid") { (exp) in
            
            self.localCentroidFromDataset(BigMLKitConnectorBaseTest.altDataset as! BMLMinimalResource,
                argsByName: [
                    "Price" : 5.8,
                    "Grape" : "Pinot Grigio",
                    "Rating" : 89,
                    "Country" : "Italy",
                    "Total Sales" : 50.0],
                argsById: [
                    "000004": 5.8,
                    "000001": "Pinot Grigio",
                    "000000": "Italy",
                    "000002": 89,
                    "000005" : 50.0 ]) {
//                argsByName:[
//                    "Team": "Atlanta Braves",
//                    "Salary": 1000000,
//                    "Position": "Pitcher"],
//                argsById:[
//                    "000000": "Atlanta Braves",
//                    "000001": 3000000000,
//                    "000002": "Shortstop" ]) {
                        (centroid1 : CentroidInfo, centroid2 : CentroidInfo) in
                        
                        XCTAssert(centroid1.centroidName == "Cluster 0" &&
                            compareDoubles(centroid1.centroidDistance, d2: 1.1455))
                        
                        XCTAssert(centroid2.centroidName == "Cluster 0" &&
                            compareDoubles(centroid2.centroidDistance, d2: 1.1455))
                        
                        exp.fulfill()
            }
        }
    }
    
}
