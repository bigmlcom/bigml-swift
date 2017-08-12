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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


let ML_DEFAULT_LOCALE = "en_US.UTF-8"

/**
  *  A local Predictive Model.
  *
  *  This class defines a Model to make predictions locally or
  *  embed them into your application without needing to send requests to
  *  BigML.io.
  *
  *  This class cannot only save you a few credits, but also enormously
  *  reduce the latency for each prediction and let you use your models
  *  offline.
  *
  *  Example usage (assuming that you have previously set up the BIGML_USERNAME
  *  and BIGML_API_KEY environment variables and that you own the model/id below):
  *
  *   let model = Model(jsonModel: modelJsonDefinition)
  *   let prediction = model.predict(
  *                         args:[
  *                             "sepal width": 3.15,
  *                             "petal length": 4.07,
  *                             "petal width": 1.51],
  *                         options:["byName": true])
  *   }
  *
  */
open class Model : FieldedResource {
    
    var fieldImportance : [(String, Double)]
    let description : String
    
    let tree : PredictionTree
    var idsMap : [Int : AnyObject]
    var treeInfo : [String : AnyObject]
    
    let model : [String : AnyObject]
    
    required public init(jsonModel : [String : AnyObject]) {
        
        let status = jsonModel["status"] as? [String : AnyObject] ?? [:]
        assert(status["code"] as? Int == 5, "Model is not ready")
        
        var fields : [String : AnyObject]
        let model = jsonModel["model"] as? [String : AnyObject] ?? [:]
        fields = model["model_fields"] as? [String : AnyObject] ?? [:]
        let modelFields = model["fields"] as? [String : AnyObject] ?? [:]
        
        for fieldName in fields.keys {
            assert(modelFields[fieldName] != nil,
                "Some fields are missing to generate a local model.")
            let modelField = modelFields[fieldName] as? [String : AnyObject] ?? [:]
            var field = fields[fieldName] as? [String : AnyObject] ?? [:]
            field.updateValue(modelField["summary"] ?? "" as AnyObject, forKey:"summary")
            field.updateValue(modelField["name"] ?? "" as AnyObject, forKey:"name")
        }
        
        let objectiveField = model["objective_field"] as? String ?? ""
        let locale = jsonModel["locale"] as? String ?? ML_DEFAULT_LOCALE
        
        self.treeInfo = ["maxBins" : 0 as AnyObject]
        self.model = jsonModel
        self.description = jsonModel["description"] as? String ?? ""
        
        if let modelFieldImportance = model["importance"] as? [[AnyObject]] {
            self.fieldImportance = modelFieldImportance.filter{
                if  let x = $0.first as? String {
                    return fields.keys.contains(x)
                }
                return false
                }.map {
                    if let f = $0.first as? String, let i = $0.last as? Double {
                        return (f, i)
                    }
                    return ("", Double.nan)
            }
        } else {
            self.fieldImportance = []
        }
        
        let distribution = model["distribution"] as? [String : AnyObject] ?? [:]
        self.idsMap = [:]
        self.tree = PredictionTree(tree: model["root"] as? [String : AnyObject] ?? [:],
            fields: fields,
            objectiveFields: [objectiveField],
            rootDistribution: distribution["training"] as? [String : AnyObject] ?? [:],
            parentId:-1,
            idsMap: &idsMap,
            isSubtree: true,
            treeInfo: &self.treeInfo)
        
        super.init(fields: fields, objectiveId: objectiveField, locale: locale, missingTokens: [])
    }
    
    func roundedConfidence(_ confidence : Double, precision : Double = 0.001) -> Double {
        return floor(confidence / precision) * precision
    }
    
/**
  * Makes a prediction based on a number of field values.
  *
  * By default the input fields must be keyed by field name but you can
  *  specify the "by_name" option to input them directly keyed by id.
  *
  * This method supports a set of options that will affect its behaviour:
  *
  *  - input_data: Input data to be predicted
  *  - by_name: Boolean, true if input_data is keyed by names
  *  - print_path: Boolean, if true the rules that lead to the prediction
  *                are printed
  *  - out: output handler
  *  - missing_strategy: MissingStrategy, the missing strategy for
  *                missing fields
  *  - add_confidence: Boolean, if true adds confidence to the dict output
  *  - add_path: Boolean, if true adds path to the dict output
  *  - add_distribution: Boolean, if true adds distribution info to the
  *                 dict output
  *  - add_count: Boolean, if true adds the number of instances in the
  *                 node to the dict output
  *  - add_median: Boolean, if true adds the median of the values in
  *                 the distribution
  *  - add_next: Boolean, if true adds the field that determines next
  *                 split in the tree
  *  - add_min: Boolean, if true adds the minimum value in the prediction's
  *                 distribution (for regressions only)
  *  - add_max: Boolean, if true adds the maximum value in the prediction's
  *                 distribution (for regressions only)
  *  - multiple: For categorical fields, it will return the categories
  *                 in the distribution of the predicted node as a
  *                 list of dicts:
  *                   [{'prediction': 'Iris-setosa',
  *                     'confidence': 0.9154
  *                     'probability': 0.97
  *                     'count': 97},
  *                   {'prediction': 'Iris-virginica',
  *                    'confidence': 0.0103
  *                    'probability': 0.03,
  *                    'count': 3}]
  *                 The value of this argument can either be an integer
  *                (maximum number of categories to be returned), or the
  *                 literal 'all', that will cause the entire distribution
  *                 in the node to be returned.
  */
    open func predict(_ arguments : [String : AnyObject],
        options : [String : Any])
        -> [String : Any] {
            
            assert(arguments.count > 0, "Prediction arguments missing")
            let byName = options["byName"] as? Bool ?? false
            let missingStrategy = options["strategy"] as? MissingStrategy ?? MissingStrategy.lastPrediction
            let multiple = options["multiple"] as? Int ?? 0
            
            let arguments = castArguments(self.filteredInputData(arguments, byName: byName),
                fields: self.fields)
            
            var prediction = self.tree.predict(arguments,
                path: [],
                strategy: missingStrategy).prediction
            
            var output : [String : Any] = [:]
            let distribution = prediction.distribution
            if multiple > 0 && !self.tree.isRegression() {
                for var i = 0; i < [multiple, distribution.count].min(); i += 1 {
                    let distributionElement = distribution[i]
                    let category = distributionElement.0
                    let confidence = wsConfidence(category, distribution: distribution)
                    let probability = ((Double(distributionElement.1) ) /
                        (Double(prediction.count) ))
                    output = [
                        "prediction" : category,
                        "confidence" : self.roundedConfidence(confidence),
                        "probability" : probability,
                        "distribution" : distribution,
                        "count" : distributionElement.value
                    ]
                }
            } else {
                
                output = ["prediction" : prediction.prediction]
                
                if let add_next = options["add_next"] as? Bool, add_next {
                    let children = prediction.children
                    if let firstChild = children.first {
                        let field = firstChild.predicate.field
                        if let _ = self.fields[field],
                            let field = self.fieldNameById[field] {
                                prediction.next = field
                        }
                    }
                    output["next"] = prediction.next
                }
                if options["add_confidence"] as? Bool ?? true {
                    output["confidence"] = prediction.confidence
                }
                if let add_path = options["add_path"] as? Bool, add_path {
                    output["path"] = prediction.path
                }
                if let add_dist = options["add_distribution"] as? Bool, add_dist {
                    output["distribution"] = prediction.distribution
                }
                if let add_count = options["add_count"] as? Bool, add_count {
                    output["count"] = prediction.count
                }
                if self.tree.isRegression() {
                    if let add_median = options["add_median"] as? Bool, add_median {
                        output["median"] = prediction.median
                    }
                    if let add_min = options["add_min"] as? Bool, add_min {
                        output["min"] = prediction.min
                    }
                    if let add_max = options["add_max"] as? Bool, add_max {
                        output["max"] = prediction.max
                    }
                }
            }
            return output
    }
}
