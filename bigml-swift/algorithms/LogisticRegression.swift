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
 * A local Predictive Logistic Regression.

 * This module defines a Logistic Regression to make predictions locally or
 * embedded into your application without needing to send requests to
 * BigML.io.

 * This module cannot only save you a few credits, but also enormously
 * reduce the latency for each prediction and let you use your logistic
 * regressions offline.
 *
 * let resource = bigMlConnector.get(...)
 * let pModel = LogisticRegression(jsonLogReg: resource.jsonDefinition)
 * let prediction1 = pModel.predict(
 *      argsByName,
 *      options: ["byName" : true])
 *
 */

private let kExpansionAttributes = [
    "categorical": "categories",
    "text": "tag_cloud",
    "items" : "items"]
//-- this is common to cluster: refactor some day?
private let kOptionalFields = ["categorical", "text", "items"]

open class LogisticRegression : FieldedResource {

    //-- this is common to cluster: refactor some day?
    var tagCloud : [String : Any] = [:]
    var termForms : [String : [String : [String]]] = [:]
    var termAnalysis : [String : [String : Any]] = [:]
    var items : [String : Any] = [:]
    var itemAnalysis : [String : [String : Any]] = [:]

    var inputFields : [String] = []
    var categories : [String : [String]] = [:]
    var fieldCodings : [String : [String : Any]] = [:]
    var fieldCodingList : [[String : Any]] = []

    var coefficients : [String : [[Double]]] = [:]
    var coefficient_shifts : [String : Int] = [:]
    let dataFieldTypes : [String : Int]
    let bias : Double
    var numericFieldIds : [String] = []
    var missingNumerics : Bool = false
    var lrNormalize : Bool = false
    
    let c : Double
    let eps : Double
    let normalize : Bool
    let regularization : String

    required public init(jsonLogReg : [String : Any]) {
        
        self.dataFieldTypes = jsonLogReg["dataset_field_types"] as?
            [String : Int] ?? [:]
        guard let status = jsonLogReg["status"] as? [String : Any],
            let code = status["code"] as? Int, code == 5 else {
                assert(false, "LogisticRegression not ready yet")
        }
        let logRegInfo = jsonLogReg["logistic_regression"] as? [String : Any] ?? [:]
        let fields = logRegInfo["fields"] as? [String : AnyObject] ?? [:]
        for tuple in (logRegInfo["coefficients"] as? [[Any]] ?? []) {
            self.coefficients.updateValue(tuple.last as? [[Double]] ?? [], forKey:tuple.first as? String ?? "")
        }
        self.inputFields = logRegInfo["input_fields"] as? [String] ?? []
        if self.inputFields.count == 0 {
            var inputFieldsMap : [String : String] = [:]
            for (fieldId, field) in fields {
                inputFieldsMap[String(field["column_number"] as! Int)] = fieldId
            }
            self.inputFields = Array(inputFieldsMap.keys).sorted().map { inputFieldsMap[$0]! }
        }
        
        self.lrNormalize = logRegInfo["lr_normalize"] as? Bool ?? false
        self.fieldCodingList = logRegInfo["field_codings"] as? [[String : Any]] ?? []
        
        self.bias = logRegInfo["bias"] as? Double ?? Double.nan
        self.c = logRegInfo["c"] as? Double ?? Double.nan
        self.eps = logRegInfo["eps"] as? Double ?? Double.nan
        self.normalize =  logRegInfo["normalize"] as? Bool ?? false
        self.regularization =  logRegInfo["regularization"] as? String ?? "l1"
        self.missingNumerics = logRegInfo["missing_numerics"] as? Bool ?? false
        
        let objectiveField = jsonLogReg["objective_field"] as? String ?? ""
        
        //-- this is the same as in cluster... refactor someday?
        for (fieldId, field) in fields {
            if let field = field as? [String : AnyObject],
                let optype = field["optype"] as? String {
                    
                    if optype == "text" {
                        
                        if let termForms = field["summary"]?["term_forms"] as?
                            [String : [String]] {
                                self.termForms[fieldId] = termForms
                        }
                        if let tagCloud = field["summary"]?["tag_cloud"] {
                            self.tagCloud[fieldId] = tagCloud as Any?
                        }
                        if let termAnalysis = field["term_analysis"] as?
                            [String : [String : [String : Any]]] {
                            self.termAnalysis[fieldId] = termAnalysis as [String : Any]?
                        }
                        
                    } else if optype == "items" {
                        
                        self.items[fieldId] = field["summary"]?["items"] as Any?? ?? [:] as Any
                        self.itemAnalysis = field["item_analysis"] as?
                            [String : [String : Any]] ?? [:]
                        
                    } else if optype == "categorical" {
                        
                        if let categories = field["summary"]?["categories"] as? [[Any]] {
                            self.categories.updateValue(categories.map{
                                $0.first as? String ?? ""
                                },
                                forKey: fieldId)
                        }
                    }
                    //-- this is not common with cluster:
                    if self.missingNumerics && optype == "numeric" {
                        self.numericFieldIds.append(fieldId)
                    }
            }
        }
        super.init(fields: fields, objectiveId: objectiveField)

        self.fieldCodings = self.fieldCodingsMap(fieldCodings: self.fieldCodingList)
        var newFieldCodings : [String : [String : Any]] = [:]
        for (fieldId, _) in self.fieldCodings {
            if !fields.keys.contains(fieldId) && self.inverseFieldMap.keys.contains(fieldId) {
                newFieldCodings[self.inverseFieldMap[fieldId]!] = self.fieldCodings[fieldId]
            } else {
                newFieldCodings[fieldId] = self.fieldCodings[fieldId]
            }
        }
        self.fieldCodings = newFieldCodings

        self.mapCoefficients()
    }
    
    /**
      * This wraps Utils.uniqueTerms(...) so that proper handling of the categories optype
      * can be done locally.
      * This should also be included in the refactoring of cluster/logistic common parts
      */
    func getUniqueTerms(_ arguments : [String : Any]) -> [String : [(Any, Int)]] {
     
        var uTerms = uniqueTerms(arguments,
            termForms: self.termForms,
            termAnalysis: self.termAnalysis,
            tagCloud: self.tagCloud,
            items: self.items,
            itemAnalysis: self.itemAnalysis)
        
        for fieldId in self.categories.keys {
            if !uTerms.keys.contains(fieldId) {
                if let argument = arguments[fieldId] {
                    uTerms.updateValue([(argument, 1)], forKey: fieldId)
                }
            }
        }
        return uTerms
    }
    
    /**
     * In case that missingNumerics is false, checks that all numeric
     * fields are present in input data.
     */
    func areAllNumericFieldsThere(_ arguments : [String : Any]) -> (Bool, String) {
     
        if !self.missingNumerics {
            for (fieldId, field) in self.fields {
                if let optype = field["optype"] as? String, (!kOptionalFields.contains(optype)
                        && !arguments.keys.contains(fieldId)) {
                            return (false, fieldId)
                }
            }
        }
        return (true, "")
    }
    /**
    * Returns the class prediction and the probability distribution
    */
    open func predict(_ arguments : [String : Any], options : [String : Any])
        -> [String : Any] {

            let byName = options["byName"] as? Bool ?? true

            let filteredArguments = castArguments(self.filteredInputData(
                arguments,
                byName: byName),
                fields: self.fields).map{ ($0.0, $0.1 as? Double ?? Double.nan) }
            
            let check = self.areAllNumericFieldsThere(filteredArguments as [String : Any])
            assert(check.0,
                "Failed to predict. " +
                    "Arguments must contain values for all numeric fields. " +
                "Missing field: \(check.1)")
            
            let uniqueTerms = self.getUniqueTerms(filteredArguments as [String : Any])
            var probabilities = [String : Double]()
            var total = 0.0
            for category in (self.categories[self.objectiveId!] ?? []) {
                if let coefficients = self.coefficients[category] {
                    probabilities[category] = self.categoryProbability(filteredArguments,
                                                                       uniqueTerms: uniqueTerms,
                                                                       coefficients: coefficients,
                                                                       category: category)
                    total += probabilities[category]!
                }
            }
            for category in probabilities.keys {
                probabilities.updateValue(probabilities[category]! / total, forKey: category)
            }
            let predictions = probabilities.sorted{ $0.1 < $1.1 }
            return [
                "prediction" : predictions.last?.0 ?? "",
                "probability" : predictions.last?.1 ?? Double.nan,
                "distribution" : predictions.map{ (category : $0.0, probability : $0.1) }
            ]
    }
    
    /**
     * Computes the probability for a concrete category
     */
    func categoryProbability(_ arguments : [String : Double],
        uniqueTerms : [String : [(Any, Int)]],
        coefficients : [[Double]],
        category : String)
        -> Double {
        
            let bias : Double = (self.coefficients[category]!.last?.first)!
            var probability = 0.0
            var norm2 = 0.0
            for (fieldId, argument) in arguments {
                let coefficients = self.coefficients(category: category, fieldId: fieldId)
                probability += coefficients[0] * argument
                norm2 += arguments[fieldId]! * arguments[fieldId]!
            }
            
 //-- text, items and categories
            for (fieldId, _) in uniqueTerms {
                if self.inputFields.contains(fieldId) {
                    let coefficients = self.coefficients(category: category, fieldId: fieldId)
                    for (term, occurrences) in uniqueTerms[fieldId]! {
                        var oneHot = true
                        var index = -1
                        if let tCloud = self.tagCloud[fieldId] as? [String] {
                            index = tCloud.index(of: term as! String) ?? -1
                        } else if let items = self.items[fieldId] as? [String] {
                            index = items.index(of: term as! String) ?? -1
                        } else if let cat = self.categories[fieldId] {
                            if let coding = self.fieldCodings[fieldId] {
                                if (coding["coding"] as? String) == "dummy" {
                                    index = cat.index(of: term as! String) ?? -1
                                } else {
                                    oneHot = false
                                    index = cat.index(of: term as! String) ?? -1
                                    var coeffIndex = 0
                                    if let coeffs = self.fieldCodings[fieldId]?.values.first as? [[Double]] {
                                        for contribution in coeffs {
                                            probability += coefficients[coeffIndex] * contribution[index] * Double(occurrences)
                                            coeffIndex += 1
                                        }
                                    }
                                }
                                if oneHot {
                                    probability += coefficients[index] * Double(occurrences)
                                    norm2 += Double(occurrences * occurrences)
                                }
                            }
                        }
                    }
                }
            }
            
            //-- missings
            for fieldId in self.numericFieldIds {
                if self.inputFields.contains(fieldId) {
                    let coefficients = self.coefficients(category: category, fieldId: fieldId)
                    if !arguments.keys.contains(fieldId) {
                        probability += coefficients[1]
                        norm2 += 1
                    }
                }
            }
            for (fieldId, tCloud) in self.tagCloud {
                if self.inputFields.contains(fieldId) {
                    let coefficients = self.coefficients(category: category, fieldId: fieldId)
                    if !uniqueTerms.keys.contains(fieldId) {
                        probability += coefficients[(tCloud as AnyObject).count]
                        norm2 += 1
                    }
                }
            }
            for (fieldId, items) in self.items {
                if self.inputFields.contains(fieldId) {
                    let coefficients = self.coefficients(category: category, fieldId: fieldId)
                    if !uniqueTerms.keys.contains(fieldId) {
                        probability += coefficients[(items as AnyObject).count]
                        norm2 += 1
                    }
                }
            }
            
            for (fieldId, _) in self.categories {
                if self.inputFields.contains(fieldId) {
                    let coefficients = self.coefficients(category: category, fieldId: fieldId)
                    if fieldId != self.objectiveId! && !uniqueTerms.keys.contains(fieldId) {
                        norm2 += 1
                        if !self.fieldCodings.keys.contains(fieldId) ||
                            (self.fieldCodings[fieldId]?["coding"] as? String) == "dummy" {
                            probability += coefficients[(self.categories as AnyObject).count]
                        } else {
                            var coeffIndex = 0
                            if let coeffs = self.fieldCodings[fieldId]?.values.first as? [[Double]] {
                                for contribution in coeffs {
                                    probability += coefficients[coeffIndex] * contribution.last!
                                    coeffIndex += 1
                                }
                            }
                        }
                    }
                }
            }
            probability += bias
            if self.bias != Double.nan {
                norm2 += 1
            }
            if self.lrNormalize {
                probability /= sqrt(norm2)
            }
            probability = 1 / (1 + exp(-probability))
            return probability
    }
    
    /**
     * Returns the set of coefficients for the given category and fieldIds
     */
    func coefficients(category : String, fieldId : String) -> [Double] {
        let index = self.inputFields.index(of: fieldId)
        return self.coefficients[category]![index!]
    }

    /**
     * Changes the field codings format to the dict notation
     */
    func fieldCodingsMap(fieldCodings : [Any]) -> [String : [String : Any]] {
        
        var result : [String : [String : Any]] = [:]
        for element in fieldCodings {
            if let e = element as? [String : Any] {
                if let c = e["coding"] as? String, let fieldId = e["fieldId"] as? String {
                    if c == "dummy" {
                        result[fieldId] = [c : e["dummy_class"] ?? ""]
                    } else {
                        result[fieldId] = [c : e["coefficients"] ?? ""]
                    }
                }
            }
        }
        return result
    }
    
    /**
     * Maps each field to the corresponding coefficients subarray
     */
    func mapCoefficients() {
        
        let fieldIds = self.fields.sorted{
            (($0.1 as? [String : Any] ?? [:])["column_number"] as? Int ?? 0) <
            (($1.1 as? [String : Any] ?? [:])["column_number"] as? Int ?? 0)}
        
        var shift = 0
        for (fieldId, field) in fieldIds.filter({ $0.0 != self.objectiveId }) {
            var length = 0
            if let optype = field["optype"] as? String {
                //-- text, items and categorical fields have one coefficient per
                //-- text/class plus a missing terms coefficient plus a bias
                //-- coefficient
                if let expandedOptype = kExpansionAttributes[optype],
                    let summary = field["summary"] as? [String : Any] {
                        length = (summary[expandedOptype] as? Int ?? 0) + 1
                } else {
                    length = self.missingNumerics ? 2 : 1
                }
                coefficient_shifts[fieldId] = shift
                shift += length
            }
        }
    }
}
