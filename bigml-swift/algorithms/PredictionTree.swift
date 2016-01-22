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

let BINS_LIMIT = 32

func arrayToDistribution(array : [[AnyObject]]) -> [(value : AnyObject, dist : Int)] {
    
    return array.map{ (value: $0[0], dist: $0[1] as? Int ?? -1) }
}

func splitNodes(nodes : [PredictionTree]) -> String {
    let set = Set(nodes.filter{ !$0.isPredicate }.map{ $0.predicate.field })
    return set.count == 1 ? (set.first ?? "") : ""
}

/**
  * A tree-like predictive model.
  */
internal class PredictionTree {
    
    let nodeId : Int
    let parentId : Int
    let predicate : Predicate
    let count : Int
    var children : [PredictionTree] = []
    
    let isPredicate : Bool

    var output : AnyObject
    var confidence : Double
    var maximum : Double
    var minimum : Double
    var median : Double = Double.NaN
    var distribution : [(value : AnyObject, dist : Int)] = []
    var distributionUnit : String = ""
    var impurity : Double = Double.NaN
    var regression : Bool = false
    
    let fields : [String : AnyObject]
    let objectiveFields : [String]
    let rootDistribution : [String : AnyObject]

    required init(tree : [String : AnyObject],
        fields : [String : AnyObject],
        objectiveFields : [String],
        rootDistribution : [String : AnyObject],
        parentId : Int,
        inout idsMap : [Int : AnyObject],
        isSubtree : Bool,
        inout treeInfo : [String : AnyObject]) {

            self.fields = fields
            self.objectiveFields = objectiveFields
            self.output = tree["output"] ?? Double.NaN
            self.confidence = tree["confidence"] as? Double ?? Double.NaN
            self.rootDistribution = rootDistribution
            self.confidence = tree["confidence"] as? Double ?? Double.NaN
            self.maximum = Double.NaN
            self.minimum = Double.NaN
            
            if let pDict = tree["predicate"] as? [String : AnyObject],
                op = pDict["operator"] as? String,
                field = pDict["field"] as? String,
                value : AnyObject = pDict["value"] {
                    
                    if let term = pDict["term"] as? String {
                        self.predicate = Predicate(op: op, field: field, value: value, term: term)
                    } else {
                        self.predicate = Predicate(op: op, field: field, value: value)
                    }
                    self.isPredicate = false
            } else if let pPred = tree["predicate"] as? Bool {
                self.isPredicate = pPred
                self.predicate = Predicate(op: "TRUE", field: "", value: "")
            } else {
                assert(false, "PredictionTree init (1): Bad things happen")
                self.predicate = Predicate(op: "FALSE", field: "", value: "")
                self.isPredicate = false
            }
            
            if let nid = tree["id"] as? Int {
                self.nodeId = nid
                self.parentId = parentId
            } else {
                self.nodeId = 0
                self.parentId = 0
                assert(false, "PredictionTree init (2): Bad things happen")
            }
            
            self.count = tree["count"] as? Int ?? 0
            if let nodes = tree["children"] as? [[String : AnyObject]] {
                var childrenArray = [PredictionTree]()
                for node in nodes {
                    childrenArray.append(PredictionTree(tree: node,
                        fields: fields,
                        objectiveFields: objectiveFields,
                        rootDistribution: [:],
                        parentId: self.nodeId,
                        idsMap: &idsMap,
                        isSubtree: isSubtree,
                        treeInfo: &treeInfo))
                }
                self.children = childrenArray

//-- alternative implementation: this will cause BAD_ACCESS due to memory
//-- corruption (too large a stack?) -- still it would be good to test with 
//-- some later version of Xcode.
//                self.children = nodes.map {
//                    PredictionTree(tree: $0,
//                        fields: fields,
//                        objectiveFields: objectiveFields,
//                        rootDistribution: [:],
//                        parentId: self.nodeId,
//                        idsMap: &idsMap,
//                        isSubtree: isSubtree,
//                        treeInfo: &treeInfo)
//                }
            } else {
                self.children = []
            }
            
            self.regression = !(self.output is String) &&
                self.children.reduce(true) { $0 && !($1.output is String) }
            
            let summary : [String : AnyObject]
            if let distributionObject = tree["distribution"] as? [(value : AnyObject, dist : Int)] {
                self.distribution = distributionObject
                self.distributionUnit = ""
                summary = [:]
            } else {
                summary = tree["objective_summary"] as? [String : AnyObject] ?? rootDistribution
                if let bins = summary["bins"] as? [[AnyObject]] {
                    self.distribution = arrayToDistribution(bins)
                    self.distributionUnit = "bins"
                } else if let counts = summary["counts"] as? [[AnyObject]] {
                    self.distribution = arrayToDistribution(counts)
                    self.distributionUnit = "counts"
                } else if let categories = summary["categories"] as? [[AnyObject]] {
                    self.distribution = arrayToDistribution(categories)
                    self.distributionUnit = "categories"
                } else {
                    self.distribution = []
                    self.distributionUnit = ""
                }
            }
            
            if (self.regression) {
                treeInfo["maxBins"] = max(treeInfo["maxBins"] as? Int ?? 0, self.distribution.count)
                self.median = (summary["median"] as? Double) ??
                    medianOfDistribution(self.distribution, instances: self.count)
                self.maximum = summary["maximum"] as? Double ??
                    self.distribution.map {
                        $0.value as? Double ?? Double.NaN
                    }.maxElement() ?? Double.NaN
                self.minimum = summary["minimum"] as? Double ??
                    self.distribution.map {
                        $0.value as? Double ?? Double.NaN
                    }.minElement() ?? Double.NaN
            }
            self.impurity = (!self.regression && self.distribution.count > 0) ?
                self.giniImpurity() : Double.NaN
            
            idsMap.updateValue(self, forKey: self.nodeId)
    }
    
    required convenience init(tree : [String : AnyObject],
        fields : [String : AnyObject],
        objectiveField : String,
        rootDistribution : [String : AnyObject],
        parentId : Int,
        inout idsMap : [Int : AnyObject],
        isSubtree : Bool,
        inout treeInfo : [String : AnyObject]) {
            
            self.init(tree: tree,
                fields: fields,
                objectiveFields: [objectiveField],
                rootDistribution: rootDistribution,
                parentId: parentId,
                idsMap: &idsMap,
                isSubtree: isSubtree,
                treeInfo: &treeInfo)
    }
    
    /**
     ** Returns the gini impurity score associated to the distribution in the node
     */
    func giniImpurity() -> Double {
        if (self.distribution.count == 0) {
            return Double.NaN
        }
        let d = self.distribution.map { Double($0.dist) ?? Double.NaN }
        let purity = d.reduce(0.0) {
            $0 + ($1/Double(self.count)) * ($1/Double(self.count))
        }
        return (1 - purity) / 2
    }
    
    /**
    * Checks if the node's value is a category
    *
    * @param node the node to be checked
    * @return true if the node's value is a category
    */
    func isClassification() -> Bool {
        return self.output is String
    }
    
    /**
    * Check if any node has a missing-valued predicate
    *
    * @param children
    * @return
    */
    func missingBranch(nodes : [PredictionTree]) -> Bool {
        return nodes.reduce(false) { $0 || $1.predicate.missing }
    }
    
    /**
    * Check if any node has a null-valued predicate
    *
    * @param nodes
    * @return
    */
    func noneValue(nodes : [PredictionTree]) -> Bool {
        for node in nodes {
            if let _ = node.predicate.value as? NSNull {
                return true
            }
        }
        return false
    }
    
    /**
     * Check if there's only one branch to be followed
     */
    func isOneBranch(nodes : [PredictionTree], arguments : [String : AnyObject]) -> Bool {
        let missing = arguments.keys.contains(splitNodes(nodes))
        return missing || self.missingBranch(nodes) || self.noneValue(nodes)
    }
    
    /**
    * Checks if the subtree structure can be a regression
    *
    * @return true if it's a regression or false if it's a classification
    */
    func isRegression() -> Bool {
        return !self.isClassification() &&
            self.children.reduce(true, combine : { $0 && !$1.isClassification() })
    }
    
    /**
    * Makes a prediction based on a number of field values averaging
    *  the predictions of the leaves that fall in a subtree.
    *
    * Each time a splitting field has no value assigned, we consider
    *  both branches of the split to be true, merging their predictions.
    *  The function returns the merged distribution and the last node
    *  reached by a unique path.
    *
    * @param arguments
    * @param lastNpode
    * @param path
    * @param missingFound
    * @return
    */
    func predictProportional(arguments : [String : AnyObject],
        var path : [String] = [],
        missingFound : Bool,
        median : Bool)
        -> (distribution : [(value : AnyObject, dist : Int)],
        minimum : Double,
        maximum : Double,
        lastNode : PredictionTree) {
            
            if self.children.count == 0 {
                return (distribution: self.distribution,
                    minimum: self.minimum,
                    maximum: self.maximum,
                    lastNode: self)
            }
            if self.isOneBranch(self.children, arguments: arguments) {
                for child in children {
                    if child.predicate.apply(arguments, fields: self.fields) {
                        let newRule = child.predicate.rule(self.fields)
                        if !path.contains(newRule) && !missingFound {
                            path.append(newRule)
                        }
                        return child.predictProportional(arguments,
                            path:path,
                            missingFound: missingFound,
                            median: median)
                    }
                }
            } else {
                
                var finalDistribution : [(value : AnyObject, dist : Int)] = []
                var mins : [Double] = []
                var maxs : [Double] = []
                for child in self.children {
                    
                    let (d, mi, ma, _) = child.predictProportional(arguments,
                        path:path,
                        missingFound: true,
                        median: median)
                    
                    finalDistribution = mergeDistributions(finalDistribution,
                        distribution: d)
                    mins.append(mi)
                    maxs.append(ma)
                }
                return (finalDistribution,
                    mins.minElement() ?? Double.NaN,
                    maxs.maxElement() ?? Double.NaN,
                    self)
            }
            assert(false, "PredictionTree predictProportional: Should not be here")
            return ([], Double.NaN, Double.NaN, self)
    }
    
    func instanceCount(distribution : [(value : AnyObject, dist : Int)]) -> Int {
        return distribution.reduce(0) { $0 + $1.dist }
    }
    
    /**
    * Makes a prediction based on a number of field values.
    *
    * The input fields must be keyed by Id.
    *
    */
    func predict(arguments : [String : AnyObject],
        path : [String] = [],
        strategy : MissingStrategy = MissingStrategy.Proportional)
        -> (prediction: TreePrediction, path: [String]) {
        
            var p = path
            var prediction : TreePrediction?
            switch strategy {
                
            case MissingStrategy.LastPrediction:
                
                for child in self.children {
                    if child.predicate.apply(arguments, fields: self.fields) {
                        p.append(child.predicate.rule(self.fields))
                        return child.predict(arguments, path: p, strategy: strategy)
                    }
                }
                prediction = TreePrediction(prediction: self.output,
                    confidence: self.confidence,
                    count: self.instanceCount(self.distribution),
                    median: self.regression ? self.median : Double.NaN,
                    min: self.regression ? self.minimum : Double.NaN,
                    max: self.regression ? self.maximum : Double.NaN,
                    path: path,
                    distribution: self.distribution,
                    distributionUnit: self.distributionUnit,
                    children: self.children)

            case MissingStrategy.Proportional:
                
                let (finalDistribution, mi, ma, ln) = self.predictProportional(arguments,
                    path:path,
                    missingFound: false,
                    median: false)
                
                if self.regression {
                    if finalDistribution.count == 1 {
                        if let (_, instances) = finalDistribution.first where instances == 1 {
                            prediction = TreePrediction(prediction: self.output,
                                confidence: self.confidence,
                                count: self.instanceCount(self.distribution),
                                median: self.regression ? self.median: Double.NaN,
                                min: self.regression ? self.minimum: Double.NaN,
                                max: self.regression ? self.maximum: Double.NaN,
                                path: path,
                                distribution: self.distribution,
                                distributionUnit: self.distributionUnit,
                                children: self.children)
                        }
                        assert(false, "Got more than one instance in single-node case")
                    }
                    //-- when there are more instances, sort elements by their mean
                    var distribution = finalDistribution.sort {
                        if let x = $0.0 as? Double, y = $1.0 as? Double {
                            return x > y
                        }
                        assert(false, "Found non-float value in distribution")
                        return false
                    }
                    let distributionUnit = distribution.count > BINS_LIMIT ? "bins" : "counts"
                    distribution = mergeBins(distribution, limit: BINS_LIMIT)
                    let totalInstances = self.instanceCount(distribution)
                    let m = meanOfDistribution(distribution)
                    let confidence = regressionError(
                        varianceOfDistribution(distribution, mean: m),
                        instances: totalInstances)
                    
                    prediction = TreePrediction(prediction: m,
                        confidence: confidence,
                        count: totalInstances,
                        median: medianOfDistribution(distribution, instances: totalInstances),
                        min: mi,
                        max: ma,
                        path: path,
                        distribution: distribution,
                        distributionUnit: distributionUnit,
                        children:ln.children)
                    
                } else {
                    
                    let distribution = finalDistribution.sort {
                        $0.1 < $1.1
                    }
                    prediction = TreePrediction(prediction: distribution.first!.1,
                        confidence: wsConfidence(distribution.first!.1,
                            distribution: finalDistribution),
                        count: self.instanceCount(distribution),
                        median: Double.NaN,
                        min: mi,
                        max: ma,
                        path: path,
                        distribution: distribution,
                        distributionUnit: "categorical",
                        children:ln.children)
                }
            }
            return (prediction: prediction!, path: path)
    }

}
