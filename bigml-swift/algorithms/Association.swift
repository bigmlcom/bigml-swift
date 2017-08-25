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

/**
 * A local Association Rules object.

 * This module defines an Association Rule object as extracted from a given
 * dataset. It shows the items discovered in the dataset and the association
 * rules between these items.
 *
 * let association = Association('association/5026966515526876630001b2')
 * association.rules()
 *
 */

private let kRuleHeaders = [
    "Rule ID",
    "Antecedent",
    "Consequent",
    "Antecedent Coverage %",
    "Antecedent Coverage", "Support %",
    "Support", "Confidence",
    "Leverage",
    "Lift",
    "p-value",
    "Consequent Coverage %",
    "Consequent Coverage"]

private let kAssociationMetrics = [
    "lhs_cover",
    "support",
    "confidence",
    "leverage",
    "lift",
    "p_value"]

private let kMetricLiterals = [
    "confidence": "Confidence",
    "support": "Support",
    "leverage": "Leverage",
    "lhs_cover": "Coverage",
    "p_value": "p-value",
    "lift": "Lift"]

private let kDefaultK = 100
private let kDefaultSearchStrategy = "leverage"
private let kSearchStrategyCodes = [
    "leverage" : 0,
    "confidence" : 1,
    "support" : 2,
    "lhs_coverage" : 3,
    "lift" : 4
]

private let kSearchStrategyAttributes = [
    0: "leverage",
    1: "confidence",
    2: "support",
    3: "lhsCover",
    4: "lift"]

private let kNoItems = ["numeric", "categorical"]

/**
 * Returns the string that describes the values of metrics for a rule
 */
func metricString(_ rule : AssociationRule, reverse : Bool = false) -> String {
    
    return kAssociationMetrics.map {
        metric -> String in
        let metricKey = (reverse && metric == "lhs_cover") ? "rhs_cover" : metric
        let metricValue = rule.valueForMetric(metricKey)
        if let metricValue = metricValue as? [Any] {
            return "\(kMetricLiterals[metric])=\(((round(1000.0 * (metricValue[0] as! Double)) / 10))) \(metricValue[1])"
        } else if metric == "confidence" {
            return "\(kMetricLiterals[metric])=\(((round(1000.0 * (metricValue as! Double)) / 10)))"
        } else {
            return "\(kMetricLiterals[metric])=\(metricValue)"
        }
        }.joined(separator: ";")
}

/**
 * A lightweight wrapper around an Association rules object.
 *
 * Uses a BigML remote association resource to build a local version
 * that can be used to extract associations information.
 */
open class Association : FieldedResource {
    
    let resourceId : String
    let complement : Bool
    let discretization : [String : AnyObject]
    let fieldDiscretizations : [String : AnyObject]
    let items : [AssociationItem]
    let k : Int
    let maxLhs : Int
    let minCoverage : Int
    let minLeverage : Int
    let minStrength : Int
    let minSupport : Int
    let minLift : Int
    let prune : Bool
    let searchStrategy : Int
    let rules : [AssociationRule]
    let significanceLevel : Double
    
    required public init(jsonAssociation : [String : AnyObject]) {
        
        self.resourceId = jsonAssociation["id"] as? String ?? ""

        let associations = jsonAssociation["associations"] as? [String : AnyObject]
        let status = jsonAssociation["status"]?["code"] as? Int ?? -1
        assert(status == 5, "Association is not complete yet.")

        let fields = associations?["fields"] as? [String : AnyObject] ?? [:]
        self.complement = associations?["complement"] as? Bool ?? false
        self.discretization = associations?["complement"] as? [String : AnyObject] ?? [:]
        self.fieldDiscretizations = associations?["field_discretizations"]
            as? [String : AnyObject] ?? [:]
        var index = 0
        self.items = (associations?["items"] as? [[String : AnyObject]] ?? []).map {
            (item : [String : AnyObject]) -> AssociationItem in
            index += 1
            return AssociationItem(index: index,
                itemInfo: item,
                fields: fields)
        }
        
        self.k = associations?["k"] as? Int ?? kDefaultK
        self.maxLhs = associations?["max_lhs"] as? Int ?? 4
        self.minCoverage = associations?["minCoverage"] as? Int ?? 0
        self.minLeverage = associations?["minLeverage"] as? Int ?? -1
        self.minStrength = associations?["minStrength"] as? Int ?? 0
        self.minSupport = associations?["minSupport"] as? Int ?? 0
        self.minLift = associations?["minLift"] as? Int ?? 0
        self.prune = associations?["prune"] as? Bool ?? true
        self.searchStrategy = kSearchStrategyCodes[
            associations?["search_strategy"] as? String ?? kDefaultSearchStrategy]!
        self.rules = (associations?["rules"] as? [[String : AnyObject]] ?? []).map {
            AssociationRule(ruleInfo: $0)
        }

        self.significanceLevel = associations?["significance_level"] as? Double ?? 0.05
        super.init(fields: fields)
    }
    
    /**
     *
     */
    func getItems(_ field : String? = nil,
        names : [String]? = nil,
        inputMap : [String : AnyObject]? = nil,
        filterFunction : ((AssociationItem) -> Bool)? = nil) -> [AssociationItem] {
            
            let filterFunctionFilter = { (item : AssociationItem) -> Bool in
                if let filterFunction = filterFunction {
                    return filterFunction(item)
                }
                return true
            }
            let fieldFilter = { (item : AssociationItem) -> Bool in
                if field != nil {
                    var fieldId = field
                    if self.fields[field!] == nil {
                        fieldId = self.inverseFieldMap[field!]
                    }
                    assert(fieldId != nil, "Failed to find a field name or ID for '\(field)'")
                    return item.fieldId == fieldId ?? ""
                }
                return true
            }
            let namesFilter = { (item : AssociationItem) -> Bool in
                if let names = names {
                    return names.contains(item.name)
                }
                return true
            }
            let inputMapFilter =  { (item : AssociationItem) -> Bool in
                if let inputMap = inputMap {
                    if let value = inputMap[item.fieldId] {
                        return item.doesMatch(value)
                    }
                    return false
                }
                return true
            }

            return self.items.filter {
                (i : AssociationItem) -> Bool in
                fieldFilter(i) && namesFilter(i) && inputMapFilter(i) && filterFunctionFilter(i)
            }
    }
    
    func tagsFromRhs(_ rhs : [Int]) -> String {
        return rhs.map { String($0) }.joined(separator: "-")
    }
    
    func rhsFromTag(_ tag : String) -> [Int] {
        return tag.components(separatedBy: "-").map{ Int($0)! }
    }
    
    /**
     * Returns the Consequents for the rules whose LHS best match
     * the provided items. Cosine similarity is used to score the match.
     *
     * @param arguments dict map of input data: e.g.
     *   ["petal length": 4.4,
     *    "sepal length": 5.1,
     *    "petal width": 1.3,
     *    "sepal width": 2.1,
     *    "species": "Iris-versicolor"]
     *
     * @param k integer Maximum number of item predictions to return
     *    (Default 100)
     *
     * @param max_rules integer Maximum number of rules to return per item
     *
     * @param score_by [0-4] Code for the metric used in scoring
     *   (default search_strategy)
     *   0 - Leverage
     *   1 - Confidence
     *   2 - Support
     *   3 - Coverage
     *   4 - Lift
     *
     * @param byName boolean If true, arguments is keyed by field
     *   name, field id is used otherwise.
     */
    open func associationSet(_ arguments : [String : AnyObject],
        options : [String : Any])
        -> [[String : AnyObject]] {

            let scoreBy = options["scoreBy"] as? Int ?? self.searchStrategy
            let byName = options["byName"] as? Bool ?? false

            var predictions = [String : [String : AnyObject]]()
            let arguments = self.filteredInputData(arguments, byName: byName)
            let itemIndexes = self.getItems(inputMap: arguments).map { $0.index }
            for rule in self.rules {
                //-- checking that the field in the rhs is not in the input data
                let item = self.items[rule.rhs[0]]
                let fieldType = self.fields[item.fieldId]?["optype"] as? String ?? ""
                //-- if the rhs corresponds to a non-itemized field and this field
                //-- is already in input_data, don't add rhs
                if kNoItems.contains(fieldType) && arguments.keys.contains(item.fieldId) {
                    continue
                }
                //-- if an itemized content is in input_data, don't add it to the prediction
                if kNoItems.contains(fieldType) && itemIndexes.contains(rule.rhs[0]) {
                    continue
                }
                var cosine = itemIndexes.reduce(0.0) { rule.lhs.contains($1) ? $0 + 1.0 : $0 }
                if cosine > 0.0 {
                    cosine /= sqrt(Double(itemIndexes.count)) * sqrt(Double(rule.lhs.count))
                    let rhsTag = self.tagsFromRhs(rule.rhs)
                    if !predictions.keys.contains(rhsTag) {
                        predictions[rhsTag] = ["score" : 0.0 as AnyObject]
                    }
                    predictions[rhsTag]!["score"] = (predictions[rhsTag]!["score"] as? Double ?? Double.nan) + cosine *
                        (rule.valueForMetric(kSearchStrategyAttributes[scoreBy]!) as? Double ?? Double.nan) as AnyObject
                }
            }
            //-- choose the best k predictions
            let k = options["k"] as? Int ?? predictions.keys.count - 1
            let p = predictions.sorted {
                ($0.1["score"] as? Double ?? Double.nan) > ($1.1["score"] as? Double ?? Double.nan) }[0...k]
            
            var result = [[String : AnyObject]]()
            for (rhsTag, var prediction) in p {
                let rhs = self.rhsFromTag(rhsTag)
                prediction.updateValue(self.items[rhs[0]], forKey: "item")
                result.append(prediction)
            }
            return result
    }
}







