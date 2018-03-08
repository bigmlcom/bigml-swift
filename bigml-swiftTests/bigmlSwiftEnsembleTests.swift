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

class BigMLKitConnectorEnsembleTests: BigMLKitConnectorBaseTest {
    
    func ensemble(_ file : String) -> [String : Any] {
        
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: file, ofType:"ensemble")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        
        return (try! JSONSerialization.jsonObject(with: data,
            options: JSONSerialization.ReadingOptions.allowFragments) as? [String : Any] ?? [:])
    }
    
    func ensembleModels(_ ensemble : [String : Any]) -> [[String : Any]] {
        
        var models : [[String : Any]] = []
        let semaphore = DispatchSemaphore(value: 0)
        _ = self.ensembleModels(ensemble) { ms in
            models = ms
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return models
    }

    func ensembleModels(_ ensemble : [String : Any],
        completion : @escaping ([[String : Any]]) -> ())
        -> [[String : Any]] {
        
        var models : [[String : Any]] = []
        let m = (ensemble["models"] as? [String] ?? [])
        var remaining = m.count
        for model in (m.map{ $0.components(separatedBy: "/").last! }) {
            self.connector!.getResource(BMLResourceType.Model, uuid: model){
                (resource, error) -> Void in
                assert(error == nil, "Could not get model \(model)")
                models.append(resource?.jsonDefinition ?? [:])
                remaining -= 1
                if remaining == 0 {
                    completion(models)
                }
            }
        }
        
        return models
    }

    func localPredictionFromEnsemble(_ resId : String,
        argsByName : [String : Any],
        argsById : [String : Any],
        completion : @escaping ([String : Any], [String : Any]) -> ()) {
            
            self.connector!.getResource(BMLResourceType.Ensemble, uuid: resId) {
                (resource, error) -> Void in
                
                if let ensemble = resource {
                    
                    _ = self.ensembleModels(ensemble.jsonDefinition) { models in

                        let pModel = Ensemble(models: models)
                        
                        let prediction1 = pModel.predict(
                            argsByName,
                            options: ["byName" : true])
                        
                        let prediction2 = pModel.predict(
                            argsById,
                            options: ["byName" : false])
                        
                        completion(prediction1, prediction2)
                    }
                    
                } else {
                    completion([:], [:])
                }
            }
    }
    
    func localPredictionFromDataset(_ dataset : BMLMinimalResource,
        argsByName : [String : Any],
        argsById : [String : Any],
        completion : @escaping ([String : Any], [String : Any]) -> ()) {
            
            self.connector!.createResource(BMLResourceType.Ensemble,
                name: dataset.name,
                options: [:],
                from: dataset) { (resource, error) -> Void in
                    
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    
                    if let resource = resource {
                        
                        self.localPredictionFromEnsemble(resource.uuid,
                            argsByName: argsByName,
                            argsById: argsById) { (prediction1 : [String : Any],
                                prediction2 : [String : Any]) in
                                
                                self.connector!.deleteResource(BMLResourceType.Ensemble,
                                    uuid: resource.uuid) {
                                    (error) -> Void in
                                    XCTAssert(error == nil, "Pass")
                                    completion(prediction1, prediction2)
                                }
                        }
                        
                    } else {
                        completion([:], [:])
                    }
            }
    }
    /*
    func testStoredBaseballEnsemble() {
        
        let models = self.ensembleModels(self.ensemble("baseball"))
        let ensemble = Ensemble(models: models)
        
        let prediction1 = ensemble.predict([
            "Salary" : 3000000,
            "Team" : "Atlanta Braves"],
            options: ["byName" : true])
        
        XCTAssert(prediction1["prediction"] as! String == "Pitcher" &&
            compareDoubles(prediction1["confidence"] as! Double, d2: 0.3315))

        let prediction2 = ensemble.predict([
            "Salary" : 18000000,
            "Team" : "Atlanta Braves"],
            options: ["byName" : true, "method" : PredictionMethod.Confidence])
        
        XCTAssert(prediction2["prediction"] as! String == "Pitcher" &&
            compareDoubles(prediction2["confidence"] as! Double, d2: 0.4277))

        let prediction3 = ensemble.predict([
            "Salary" : 18000000,
            "Team" : "Atlanta Braves"],
            options: ["byName" : true,
                "method" : PredictionMethod.Threshold,
                "threshold-k" : 3,
                "threshold-category" : "Catcher"
            ])
        
        XCTAssert(prediction3["prediction"] as! String == "Pitcher" &&
            compareDoubles(prediction3["confidence"] as! Double, d2: 0.3315))

        let prediction4 = ensemble.predict([
            "Salary" : 18000000,
            "Team" : "Atlanta Braves"],
            options: ["byName" : true,
                "method" : PredictionMethod.Threshold,
                "threshold-k" : 2,
                "threshold-category" : "Catcher"
            ])
        
        XCTAssert(prediction4["prediction"] as! String == "Catcher" &&
            compareDoubles(prediction4["confidence"] as! Double, d2: 0.2745))
    }

    func testStoredWinesEnsemble() {
        
        self.runTest("testWinesEnsemble") { (exp) in

            let models = self.ensembleModels(self.ensemble("wines"))
            let ensemble = Ensemble(models: models)
            
            let prediction1 = ensemble.predict([
                "Price" : 5.8,
                "Grape" : "Pinot Grigio",
                "Rating" : 89,
                "Country" : "Italy"],
                options: ["byName" : true])
            
            XCTAssert(prediction1["prediction"] as! Double == 102.58 &&
                compareDoubles(prediction1["confidence"] as! Double, d2: 32.25))
            
            let prediction2 = ensemble.predict([
                "Price" : 5.8,
                "Grape" : "Pinot Grigio",
                "Rating" : 89,
                "Country" : "Italy"],
                options: ["byName" : true, "method" : PredictionMethod.Confidence])
            
            XCTAssert(prediction2["prediction"] as! Double == 76.9908 &&
                compareDoubles(prediction2["confidence"] as! Double, d2: 7.6897))
            
            exp.fulfill()
        }
    }
    */
    func testWinesEnsemble() {
        
        self.runTest("testWinesEnsemble") { (exp) in

            self.localPredictionFromDataset(BigMLKitConnectorBaseTest.altDataset as! BMLMinimalResource,
                argsByName: [
                    "Price" : 5.8,
                    "Grape" : "Pinot Grigio",
                    "Rating" : 89,
                    "Country" : "Italy"],
                argsById: [
                    "000004": 5.8,
                    "000001": "Pinot Grigio",
                    "000000": "Italy",
                    "000002": 89 ]) { (prediction1 : [String : Any], prediction2 : [String : Any]) in
                        
                        XCTAssert(prediction1["prediction"] as? Double != nil)
                        
                        XCTAssert(prediction2["prediction"] as? Double != nil)
                        
                        exp.fulfill()
            }
        }
    }
    
    func testRemoteEnsemble() {
        
        self.runTest("testStoredWinesEnsembleFieldImportance") { (exp) in

            self.localPredictionFromEnsemble("566954af1d5505120900bf69",
                argsByName: [
                    "Price" : 5.8,
                    "Grape" : "Pinot Grigio",
                    "Rating" : 89,
                    "Country" : "Italy"],
                argsById: [
                    "000004": 5.8,
                    "000001": "Pinot Grigio",
                    "000000": "Italy",
                    "000002": 89 ]) { (prediction1 : [String : Any],
                    prediction2 : [String : Any]) in

                        print("P1: \(prediction1)")
                        
                        exp.fulfill()
            }
        }
    }
    /*
    func testStoredWinesEnsembleFieldImportance() {
        
        self.runTest("testStoredWinesEnsembleFieldImportance") { (exp) in

            let jsonEnsemble = self.ensemble("wines")
            let models = self.ensembleModels(jsonEnsemble)
            let ensemble = Ensemble(models: models,
                maxModels: Int.max,
                distributions: jsonEnsemble["distributions"] as? [[String : Any]] ?? [])

            XCTAssert(ensemble.fieldImportance().count == 4)

            exp.fulfill()
        }
    }
    */
}
