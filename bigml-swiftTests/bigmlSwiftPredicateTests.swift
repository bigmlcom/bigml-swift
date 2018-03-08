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
import XCTest
#if os(iOS)
    import bigmlSwift
#else
    import bigmlSwift_macOS
#endif

class BigMLKitConnectorPredicateTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreatePredicate1() {
        
        _ = Predicate(op: "A", field: "F1", value: 1, term:"T")
        XCTAssert(true, "Pass")
    }
    
    func testCreateNumPredicateEval() {
        
        var p = Predicate(op: ">", field: "F1", value: 1, term:.none)
        var res = p.apply(["F1" : 0.5], fields: ["F1" : [:]])
        XCTAssert(!res, "Pass")

        p = Predicate(op: ">", field: "F1", value: 1, term:.none)
        res = p.apply(["F1" : 100], fields: ["F1" : [:]])
        XCTAssert(res, "Pass")
        
        p = Predicate(op: ">=", field: "F1", value: 1, term:.none)
        res = p.apply(["F1" : 1], fields: ["F1" : [:]])
        XCTAssert(res, "Pass")
        
        p = Predicate(op: "<=", field: "F1", value: 1, term:.none)
        res = p.apply(["F1" : 0.5], fields: ["F1" : [:]])
        XCTAssert(res, "Pass")
        
        p = Predicate(op: "=", field: "F1", value: 5, term:.none)
        res = p.apply(["F1" : 5], fields: ["F1" : [:]])
        XCTAssert(res, "Pass")
        
    }
    
    func testCreatePredicateFullTerm() {
        
        let p = Predicate(op: "A", field: "F1", value: 1, term:"T.T")
        let fields = ["F1" : ["term_analysis" : [ "token_mode" : "all" ]]]
        XCTAssert(p.isFullTerm(fields), "Pass")
    }

    func testCreatePredicateNonFullTerm() {
        
        let p = Predicate(op: "A", field: "F1", value: 1, term:"TT")
        let fields = ["F1" : ["term_analysis" : [ "token_mode" : "all" ]]]
        XCTAssert(!p.isFullTerm(fields), "Pass")
    }

    func testCreatePredicateRule() {
        
        let test = { (term : String, fields : [String : Any]) -> Bool in
         
            var p = Predicate(op: ">=", field: "F1", value: 1, term: term)
            var rule = p.rule(fields)
            print("Predicate: \(rule)", terminator: "")
            
            p = Predicate(op: ">", field: "F1", value: 1, term: term)
            rule = p.rule(fields)
            print("Predicate: \(rule)", terminator: "")
            
            p = Predicate(op: ">", field: "F1", value: 0, term: term)
            rule = p.rule(fields)
            print("Predicate: \(rule)", terminator: "")
            
            p = Predicate(op: "<=", field: "F1", value: 0, term: term)
            rule = p.rule(fields)
            print("Predicate: \(rule)", terminator: "")
            
            return true
        }
        
        _ = test("T.T", ["F1" : ["name": "f1", "term_analysis" : [ "token_mode" : "all" ]]])
        _ = test("T", ["F1" : ["a" : "b", "name" : "F1"]])
        _ = test("A.A", ["F1" : ["a" : "b", "name" : "F1"]])
        _ = test("A.A", ["F2" : ["a" : "b", "name" : "F1"]])
        
        XCTAssert(true, "Pass")
    }

    func testNumPredicatesEval() {
        
        let ps = Predicates(predicates: [
            "TRUE",
            ["op" : ">=", "field" : "F1", "value" : 1.1, "term" : ""],
            ["op" : ">=*", "field" : "F1", "value" : 1.1, "term" : ""],
            ["op" : "<=", "field" : "F2", "value" : 1.0, "term" : ""]])
        
        let result = ps.apply(["F1" : 5, "F2" : 1], fields: ["F1" : [:], "F2" : [:]])
        XCTAssert(result, "Pass")
    }
    
    func testInclusionPredicatesEval() {
        
        let p = Predicate(op: "in", field: "F0", value: ["a", "b"])
        XCTAssert(p.apply(["F0" : "a"], fields: ["F0" : [:], "F2" : [:]]))
        XCTAssert(!p.apply(["F0" : "c"], fields: ["F0" : [:], "F2" : [:]]))
        XCTAssert(!p.apply(["F0" : "a"], fields: ["F1" : [:], "F2" : [:]]))
        
        let ps = Predicates(predicates: [
            "TRUE",
            ["op" : "in", "field" : "F0", "value" : [["a", "b"], "c"], "term" : ""],
            ["op" : ">=*", "field" : "F1", "value" : 1.1, "term" : ""],
            ["op" : "<=", "field" : "F2", "value" : 1.0, "term" : ""]])
        
        XCTAssert(ps.apply(["F0" : ["a", "b"], "F1" : 5, "F2" : 1],
            fields: ["F0" : [:], "F1" : [:], "F2" : [:]]))
        
        XCTAssert(!ps.apply(["F0" : ["a", "c"], "F1" : 5, "F2" : 1],
            fields: ["F0" : [:], "F1" : [:], "F2" : [:]]))
    }
    
    func testNumPredicatesEvalFail() {
        
        let ps = Predicates(predicates: [
            "TRUE",
            ["op" : ">=", "field" : "F1", "value" : 1.2, "term" : ""],
            ["op" : "<=*", "field" : "F1", "value" : 1.1, "term" : ""],
            ["op" : ">", "field" : "F2", "value" : 1, "term" : ""]])
        
        let result = ps.apply(["F1" : 5, "F2" : 1.1], fields: ["F1" : [:], "F2" : [:]])
        XCTAssert(!result)
    }
    
    func testAlphaPredicatesRule() {
        
        let term1 = "T"
        let term2 = "T.T"
        let ps = Predicates(predicates: [
            "TRUE",
            ["op" : ">=", "field" : "F1", "value" : 1, "term" : term1],
            ["op" : ">", "field" : "F1", "value" : 1, "term" : term1],
            ["op" : ">", "field" : "F1", "value" : 0, "term" : term1],
            ["op" : "<=", "field" : "F1", "value" : 0, "term" : term1],
            ["op" : ">=", "field" : "F2", "value" : 1, "term" : term2],
            ["op" : ">", "field" : "F2", "value" : 1, "term" : term2],
            ["op" : ">", "field" : "F2", "value" : 0, "term" : term2],
            ["op" : "<=", "field" : "F2", "value" : 0, "term" : term2]])
        
        print(ps.rule(["F1" : ["a" : "b", "name" : "F1"],
            "F2" : ["name": "f2", "term_analysis" : [ "token_mode" : "all" ]]]), terminator: "")
    }
}
