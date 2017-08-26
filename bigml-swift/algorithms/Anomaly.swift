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

let DEPTH_FACTOR : Double = 0.5772156649

/**
* Tree structure for the BigML anomaly detector
*
* This class defines an auxiliary tree that is used when calculating
* anomaly scores without needing to send requests to BigML.io.
*
*/
class AnomalyTree {
    
    internal let fields : [String : Any]
    let anomaly : Anomaly
    var predicates : Predicates
    var id : String = ""
    var children : [AnomalyTree] = []
    
    init(tree : [String : Any], anomaly : Anomaly) {
        
        self.anomaly = anomaly
        self.fields = anomaly.fields
        self.predicates = Predicates(predicates: ["True" as Any])
        if let predicates = tree["predicates"] as? [[String : Any]] {
            self.predicates = Predicates(predicates: predicates as [Any])
        }
        if let id = tree["id"] as? String {
            self.id = id
        }
        if let children = tree["children"] as? [[String : Any]] {
            self.children = children.map {
                AnomalyTree(tree: $0, anomaly: anomaly)
            }
        }
    }
    
    /**
    *
    * Returns the depth of the tree that the input data "verifies"
    * and the associated set of rules.
    *
    * If a node has any child whose predicates are all true for the given
    * input, then the depth is incremented and we flow through.
    * If the node has no children or no children with all valid predicates,
    * then it outputs the depth of the node.
    *
    * @return
    */
    func depth(_ input : [String : Any], path : [String] = [], depth : Int = 0) -> (Int, [String]) {
        
        var depth = depth
        if depth == 0 {
            if !self.predicates.apply(input, fields: self.fields) {
                return (depth, path)
            }
            depth += 1
        }
        var path = path
        for child in self.children {
            if self.anomaly.stopped {
                return (0, [])
            }
            if child.predicates.apply(input, fields: self.fields) {
                path.append(child.predicates.rule(self.fields))
                return child.depth(input, path: path, depth: depth+1)
            }
        }
        return (depth, path)
    }
}

open class Anomaly : FieldedResource {
    
    let sampleSize : Double?
    let inputFields : [String]?
    var meanDepth : Double?
    var expectedMeanDepth : Double? = .none
    var iforest : [AnomalyTree?]?
    internal var stopped : Bool = false
    var anomalyCount : Int = 0
    
    public init(anomaly : BMLResource) {
        
        assert(anomaly.type == BMLResourceType.anomaly, "Wrong resource passed in -- anomaly expected")
        //        println("RESOURCE \(anomaly.jsonDefinition)")
        if let sampleSize = anomaly.jsonDefinition["sample_size"] as? Double,
            let inputFields = anomaly.jsonDefinition["input_fields"] as? [String] {
                
                self.sampleSize = sampleSize
                self.inputFields = inputFields
                
        } else {
            
            self.sampleSize = .none
            self.inputFields = .none
        }
        if let model = anomaly.jsonDefinition["model"] as? [String : Any],
            let fields = model["fields"] as? [String : AnyObject] {
                
                if let _ = model["top_anomalies"] as? [Any] {
                    
                    super.init(fields: fields)
                    
                    self.meanDepth = model["mean_depth"] as? Double
                    if let status = anomaly.jsonDefinition["status"] as? [String : Any],
                        let intCode = status["code"] as? Int {
                            
                            let code = BMLResourceStatus(integerLiteral: intCode)
                            if (code == BMLResourceStatus.ended) {
                                if let sampleSize = self.sampleSize, let meanDepth = self.meanDepth {
                                    let defaultDepth = 2 * (DEPTH_FACTOR + log(sampleSize - 1) - ((sampleSize - 1) / sampleSize))
                                    self.expectedMeanDepth = min(meanDepth, defaultDepth)
                                } else {
                                    assert(false, "Could not create anomaly instance");
                                }
                                if let iforest = model["trees"] as? [Any] {
                                    self.iforest = iforest.map {
                                        if let tree = $0 as? [String : Any],
                                            let root = tree["root"] as? [String : Any] {
                                                return AnomalyTree(tree: root, anomaly: self)
                                        } else {
                                            return .none
                                        }
                                    }
                                }
                            } else {
                                assert(false, "Could not create anomaly instance");
                            }
                    }
                } else {
                    self.meanDepth = 0
                    super.init(fields: fields)
                }
        } else {
            self.meanDepth = 0
            super.init(fields: [:])
        }
    }
    
    open func score(_ input : [String : Any], byName : Bool = true) -> Double {
        
        self.stopped = false
        assert(self.iforest != nil, "Could not find forest info. The anomaly was possibly not completely created")
        if let iforest = self.iforest {
            let inputData = self.filteredInputData(input, byName: byName)
            let depthSum = iforest.reduce(0) {
                if let tree = $1 {
                    return $0 + (self.stopped ? 0 : tree.depth(inputData).0)
                }
                assert(false, "Should not be here: non-tree found in forest!")
                return 0
            }
            let observedMeanDepth = Double(depthSum) / Double(iforest.count)
            return pow(2.0, -observedMeanDepth / self.expectedMeanDepth!)
        }
        return 0
    }
    
    open func stop() {
        self.stopped = true
    }
    
    open func unstop() {
        self.stopped = false
    }
    
    open func isStopped() -> Bool {
        return self.stopped
    }
}
