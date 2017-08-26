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

class BigMLKitConnectorLogisticRegressionTests: BigMLKitConnectorBaseTest {
    
    func logisticRegression(_ file : String) -> [String : Any] {
        
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: file, ofType:"logistic")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        
        return (try! JSONSerialization.jsonObject(with: data,
            options: JSONSerialization.ReadingOptions.allowFragments) as? [String : Any] ?? [:])
    }
    
    func localPrediction(_ resId : String,
        argsByName : [String : Any],
        argsById : [String : Any],
        completion : @escaping ([String : Any], [String : Any]) -> ()) {
            
            self.connector!.getResource(BMLResourceType.logisticRegression, uuid: resId) {
                (resource, error) -> Void in
                
                if let resource = resource {
                    
                    let pModel = LogisticRegression(jsonLogReg: resource.jsonDefinition)
                    
                    let prediction1 = pModel.predict(
                        argsByName,
                        options: ["byName" : true])
                    
                    let prediction2 = pModel.predict(
                        argsById,
                        options: ["byName" : false])
                    
                    completion(prediction1, prediction2)
                    
                } else {
                    completion([:], [:])
                }
            }
    }
    
    func remotePrediction(_ fromResource : BMLResource,
        argsById : [String : Any],
        completion : @escaping ([String : Any]) -> ()) {
            
            self.connector!.createResource(BMLResourceType.prediction,
                name: fromResource.name,
                options: ["input_data" : argsById],
                from: fromResource) { (resource, error) -> Void in
                    
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    
                    if let resource = resource?.jsonDefinition {
                        completion([
                            "prediction" : resource["output"]!,
                            "probabilities" : resource["probabilities"]!,
                            "probability" : ((resource["probabilities"] as! [Any]).first as! [Any]).last!])
                    } else {
                        completion([:])
                    }
            }
    }

    func localPredictionFromDataset(_ predictionType : BMLResourceType,
        dataset : BMLMinimalResource,
        argsByName : [String : Any],
        argsById : [String : Any],
        completion : @escaping ([String : Any], [String : Any]) -> ()) {
            
            self.connector!.createResource(BMLResourceType.logisticRegression,
                name: dataset.name,
                options: [:],
                from: dataset) { (resource, error) -> Void in
                    
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    
                    if let resource = resource {
                        
                        self.localPrediction(resource.uuid,
                            argsByName: argsByName,
                            argsById: argsById) { (prediction1 : [String : Any],
                                prediction2 : [String : Any]) in
                                
                                XCTAssert(prediction1["prediction"] as! String ==
                                    prediction2["prediction"] as! String &&
                                    compareDoubles(prediction1["probability"] as! Double,
                                        d2: prediction2["probability"] as! Double))

                                self.remotePrediction(resource,
                                    argsById: argsById) { (prediction : [String : Any]) in
                                        
                                    self.connector!.deleteResource(predictionType,
                                        uuid: resource.uuid) {
                                            (error) -> Void in
                                            XCTAssert(error == nil, "Pass")
                                            completion(prediction1, prediction)
                                        }
                                }
                        }
                        
                    } else {
                        completion([:], [:])
                    }
            }
    }
    
    func testStoredIrisLogisticRegression() {
        
        let logReg = LogisticRegression(jsonLogReg: self.logisticRegression("iris"))
        
        let prediction1 = logReg.predict([
            "sepal length": 6.02,
            "sepal width": 3.15,
            "petal width": 1.51,
            "petal length": 4.07],
            options: ["byName" : true])
        
        XCTAssert(prediction1["prediction"] as! String == "Iris-versicolor" &&
            compareDoubles(prediction1["probability"] as! Double, d2: 0.6700))
    }
    
    func testIrisLogisticRegression() {
        
        self.runTest("testIrisLogisticRegression") { (exp) in
            
            self.localPredictionFromDataset(BMLResourceType.logisticRegression,
                dataset: BigMLKitConnectorBaseTest.aDataset as! BMLMinimalResource,
                argsByName: [
                    "sepal length": 6.02,
                    "sepal width": 3.15,
                    "petal length": 4.07,
                    "petal width": 1.51],
                argsById: [
                    "000000": 6.02,
                    "000001": 3.15,
                    "000002": 4.07,
                    "000003": 1.51]) {
                        (prediction1 : [String : Any], prediction2 : [String : Any]) in
                        
                        XCTAssert(prediction1["prediction"] as! String == "Iris-versicolor" &&
                            compareDoubles(prediction1["probability"] as! Double, d2: 0.6700))
                        XCTAssert(prediction2["prediction"] as! String == "Iris-versicolor" &&
                            compareDoubles(prediction2["probability"] as! Double, d2: 0.6700))

                        exp.fulfill()
            }
        }
    }
}
