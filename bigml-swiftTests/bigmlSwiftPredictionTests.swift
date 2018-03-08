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

class BigMLKitConnectorPredictionTests: BigMLKitConnectorBaseTest {

    func localPredictionFromModel(_ modelId : String,
        args : [String : Any],
        options : [String : Any],
        completion : @escaping ([String : Any]) -> ()) {
        
        self.connector!.getResource(BMLResourceType.Model, uuid: modelId) {
            (resource, error) -> Void in
            
            if let model = resource {
                let pModel = Model(jsonModel: model.jsonDefinition)
                completion(pModel.predict(
                    args,
                    options: options))
                
            } else {
                completion([:])
            }
        }
    }
    
    func localPredictionFromDataset(_ dataset : BMLResource,
        args : [String : Any],
        options : [String : Any],
        completion : @escaping ([String : Any]) -> ()) {
            
            self.connector!.createResource(BMLResourceType.Model,
                name: dataset.name,
                options: [:],
                from: dataset) { (resource, error) -> Void in
                    if let error = error {
                        print("Error: \(error)")
                    }
                    XCTAssert(resource != nil && error == nil)
                    
                    if let resource = resource {
                        
                        self.localPredictionFromModel(resource.uuid,
                            args: args,
                            options: options) { (prediction : [String : Any]) in
                                    
                                self.connector!.deleteResource(BMLResourceType.Model,
                                    uuid: resource.uuid) {
                                        (error) -> Void in
                                        XCTAssert(error == nil, "Pass")
                                        completion(prediction)
                                }
                        }
                        
                    } else {
                        completion([:])
                    }
            }
    }
    
    func localPredictionFromCSV(_ csv : String,
        name : String,
        args : [String : Any],
        options : [BMLResourceType : [String : Any]],
        completion : @escaping ([String : Any]) -> ()) {
            
            self.runTest(name) { (exp) in
                
                let filePath = Bundle.pathForResource(csv)
                let resource = BMLMinimalResource(name:name,
                    type:BMLResourceType.File,
                    uuid:filePath!)
                
                self.connector!.createResource(BMLResourceType.Source,
                    name: name,
                    options: options[BMLResourceType.Source] ?? [:],
                    from: resource) { (resource, error) -> Void in
                        XCTAssert(resource != nil && error == nil, "Pass")
                        self.connector!.createResource(BMLResourceType.Dataset,
                            name: name,
                            options: options[BMLResourceType.Dataset] ?? [:],
                            from: resource!) { (resource, error) -> Void in
                                XCTAssert(resource != nil && error == nil, "Pass")
                                var opt = [String : Any]()
                                for (k, v) in options[BMLResourceType.Prediction] ?? [:] {
                                    opt.updateValue(v as Any, forKey: k)
                                }
                                self.localPredictionFromDataset(resource as! BMLMinimalResource,
                                    args: args,
                                    options: opt) { (prediction : [String : Any]) in
                                        completion(prediction)
                                        exp.fulfill()
                                }
                        }
                }
            }
    }
    
    func testStoredIrisModel() {
        
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "iris", ofType:"model")
        let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
        let model = try! JSONSerialization.jsonObject(with: data,
            options: JSONSerialization.ReadingOptions.allowFragments)
        
        let prediction = Model(jsonModel: model as! [String : Any]).predict([
            "sepal length": 6.02,
            "sepal width": 3.15,
            "petal width": 1.51,
            "petal length": 4.07],
            options: ["byName" : true])
        
        XCTAssert(prediction["prediction"] as! String == "Iris-versicolor" &&
            compareDoubles(prediction["confidence"] as! Double, d2: 0.92444))
    }
    
    func testWinePrediction() {
        
        self.localPredictionFromCSV("wines.csv",
            name: "testWinesPrediction",
            args: [
                "Price": 32.0,
                "Grape": "Cabernet Sauvignon",
                "Country": "France",
                "Rating": 90],
            options: [BMLResourceType.Prediction : ["byName": true]]) {
                (prediction : [String : Any]) in
                
                XCTAssert(
                    compareDoubles(prediction["prediction"] as! Double,
                        d2: 78.5714) &&
                        compareDoubles(prediction["confidence"] as! Double,
                            d2: 17.496))
        }
    }
    
    func testSpecialIrisPrediction() {
        
        self.localPredictionFromCSV("iris-sp-chars.csv",
            name: "testSpecialIrisPrediction",
            args: [
                "pétal.length": 4,
                "pétal&width": 1.5],
            options: [BMLResourceType.Prediction : ["byName": true]]) {
                (prediction : [String : Any]) in
                
                XCTAssert(
                    prediction["prediction"] as! String == "Iris-versicolor" &&
                        compareDoubles(prediction["confidence"] as! Double, d2: 0.403))
        }
    }
    
    func execTests(_ dataset : BMLResource,
        tests : [(args : [String : Any], p : Any, c : Double)],
        options : [String : Any]) {
        
        for (args, p, c) in tests {

            let semaphore = DispatchSemaphore(value: 0)
            self.localPredictionFromDataset(dataset,
                args: args,
                options: options) {
                    (prediction : [String : Any]) in
                    
                    semaphore.signal()
                    print("Message: \(p) -- ", prediction["prediction"] ?? "NONE")
                    print("Confidence: \(c) -- ", prediction["confidence"] ?? "NONE")
                    if let p = p as? String {
                        XCTAssert(prediction["prediction"] as! String == p)
                    } else if let p = p as? Double {
                        XCTAssert(prediction["prediction"] as! Double == p)
                    }
                    XCTAssert(compareDoubles(prediction["confidence"] as! Double, d2: c))
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
    
    func runTestPrediction(_ file : String,
        tests : [(args : [String : Any], p : Any, c : Double)],
        options : [BMLResourceType : [String : Any]]) {
        
            self.runTest(name!) { (exp) in
                
                let dataset = self.createDataset(file, options: options)!
                self.execTests(dataset,
                    tests: tests,
                    options: options[BMLResourceType.Prediction] ?? [:])
                
                self.connector!.deleteResource(dataset.type,
                    uuid: dataset.uuid) {
                        (error) -> Void in
                        exp.fulfill()
                }
            }
    }
    /*
    func testTextPrediction1() {
        
        self.runTestPrediction("spam.csv",
            tests: [
                    (["Message" : "Mobile calls"], "ham", 0.993),
                    (["Message": "I'll call you tomorrow morning."], "ham", 0.993),
                    (["Message": "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"], "spam", 0.206)
                ],
            options: [
                 BMLResourceType.Source : [
                    "fields" : [
                        "000001" : [
                            "optype" : "text",
                            "term_analysis" : [
                                "enabled" : true,
                                "case_sensitive" : true,
                                "stem_words" : true,
                                "use_stopwords" : false,
                                "language" : "en"]]]],
                BMLResourceType.Prediction : [
                    "byName" : true]])
    }
    */
    func testTextPrediction2() {
        
        self.runTestPrediction("spam.csv",
            tests: [
                (["Message" : "Mobile call"], "spam", 0.701),
                (["Message": "I'll call you tomorrow morning."], "ham", 0.904),
                (["Message": "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"], "spam", 0.796)
            ],
            options: [
                BMLResourceType.Source : [
                    "fields" : [
                        "000001" : [
                            "optype" : "text",
                            "term_analysis" : [
                                "enabled" : true,
                                "case_sensitive" : false,
                                "stem_words" : true,
                                "use_stopwords" : true,
                                "language" : "en"]]]],
                BMLResourceType.Prediction : [
                    "byName" : true]])
    }
    
    func testTextPrediction3() {
        
        self.runTestPrediction("spam.csv",
            tests: [
                (["Message" : "Mobile calls"], "spam", 0.206),
                (["Message": "I'll call you tomorrow morning."], "ham", 0.893),
                (["Message": "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"], "spam", 0.609)
            ],
            options: [
                BMLResourceType.Source : [
                    "fields" : [
                        "000001" : [
                            "optype" : "text",
                            "term_analysis" : [
                                "enabled" : true,
                                "case_sensitive" : false,
                                "stem_words" : false,
                                "use_stopwords" : false,
                                "language" : "en"]]]],
                BMLResourceType.Prediction : [
                    "byName" : true]])
    }
    
    func testTextPrediction4() {
        
        self.runTestPrediction("spam.csv",
            tests: [
                (["Message" : "Mobile calls"], "ham", 0.9933),
                (["Message": "I'll call you tomorrow morning."], "ham", 0.9933),
                (["Message": "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"], "spam", 0.2065)
            ],
            options: [
                BMLResourceType.Source : [
                    "fields" : [
                        "000001" : [
                            "optype" : "text",
                            "term_analysis" : [
                                "enabled" : true,
                                "token_mode" : "full_terms_only",
                                "language" : "en"]]]],
                BMLResourceType.Prediction : [
                    "byName" : true]])
    }
    
    func testProportionalWithMissingPrediction1() {
        
        self.runTestPrediction("iris.csv",
            tests: [([
                "sepal length": 6.02,
                "sepal width": 3.15], "Iris-setosa", 0.2629)
            ],
            options: [
                BMLResourceType.Prediction : [
                    "missing_strategy" : MissingStrategy.proportional,
                    "byName" : true]])
    }

    func testItemsPrediction() {
        
        self.runTest(name!) { (exp) in
            
            let dataset = self.createDataset("movies.csv",
                options: [BMLResourceType.Source : [
                    "fields" : [
                        "000007" : [
                            "optype" : "items",
                            "item_analysis" : [
                                "separator" : "$"]]]]])!
            
            self.execTests(dataset,
                tests: [
                    (["genres" : "Mobile calls",
                        "timestamp" : 993906291,
                        "occupation" : "K-12 student"], 3.93064, 0.993)
                ],
                options: ["byName" : true])
            
            exp.fulfill()
        }
    }
    
    func testIrisPredictionVersicolor() {
        
        self.runTest("testIrisPrediction") { (exp) in
            
            self.localPredictionFromDataset(BigMLKitConnectorBaseTest.aDataset as! BMLMinimalResource,
                args:[
                    "sepal width": 3.15,
                    "petal length": 4.07,
                    "petal width": 1.51],
                options:["byName": true]) {
                    (prediction : [String : Any]) in
                    
                    XCTAssert(prediction["prediction"] as! String == "Iris-versicolor" &&
                        compareDoubles(prediction["confidence"] as! Double, d2: 0.92444))
                    
                    self.localPredictionFromDataset(BigMLKitConnectorBaseTest.aDataset as! BMLMinimalResource,
                        args:[
                            "000001": 3.15,
                            "000002": 4.07,
                            "000003": 1.51],
                        options:["byName": false]) {
                            (prediction2 : [String : Any]) in
                            
                            XCTAssert(prediction2["prediction"] as! String == "Iris-versicolor" &&
                                compareDoubles(prediction2["confidence"] as! Double, d2: 0.92444))
                            
                            exp.fulfill()
                    }
            }
        }
    }
    
    func testIrisPredictionSetosa() {
        
        self.runTest("testIrisPrediction") { (exp) in
            
            self.localPredictionFromDataset(BigMLKitConnectorBaseTest.aDataset as! BMLMinimalResource,
                args:["petal width": 0.5],
                options:["byName": true]) {
                    (prediction : [String : Any]) in
                    
                    XCTAssert(prediction["prediction"] as! String == "Iris-setosa" &&
                        compareDoubles(prediction["confidence"] as! Double, d2: 0.262))
                    
                    exp.fulfill()
            }
        }
    }
    
    func testIrisPredictionVirginica() {
        
        self.runTest("testIrisPrediction") { (exp) in
            
            self.localPredictionFromDataset(BigMLKitConnectorBaseTest.aDataset as! BMLMinimalResource,
                args:["petal length": 6, "petal width": 2],
                options:["byName": true]) {
                    (prediction : [String : Any]) in
                    
                    XCTAssert(prediction["prediction"] as! String == "Iris-virginica" &&
                        compareDoubles(prediction["confidence"] as! Double, d2: 0.917))
                    
                    exp.fulfill()
            }
        }
    }
    
}
