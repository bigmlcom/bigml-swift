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

open class Ensemble {
    
    open var isReadyToPredict : Bool
    
    fileprivate var distributions : [[String : AnyObject]]
    fileprivate var fields : [String : AnyObject]
    fileprivate var multiModels : [MultiModel]
    
    static fileprivate func multiModels(_ models : [[String : AnyObject]], maxModels : Int)
        -> [MultiModel] {
            
            return stride(from: 0, to: models.count - maxModels, by: maxModels).map { s in
                MultiModel(models:Array(models[s..<s+models.count]))
            }
    }
    
    public required init(models : [[String : AnyObject]],
        maxModels : Int = Int.max,
        distributions : [[String : AnyObject]] = []) {
        
            assert(models.count > 0)
            assert(maxModels >= 0)
        
            self.multiModels = Ensemble.multiModels(models, maxModels: maxModels)
            self.fields = Ensemble.fieldsFromModels(models)
            self.isReadyToPredict = true
            self.distributions = distributions
    }
    
    static func fieldsFromModels(_ models : [[String : AnyObject]]) -> [String : AnyObject] {
        
        var fields : [String : AnyObject] = [:]
        for model in models {
            for (fieldId, field) in model {
                fields.updateValue(field, forKey: fieldId)
            }
        }
        return fields
    }
    
    /**
    * Makes a prediction based on the prediction made by every model.
    *
    * @param arguments: input data for the prediction
    * @param options: a map specifying which options to use, i.e.
    *        byName: Boolean that is set to true if field names (as
    *        alternative to field ids) are used;
    *        method: a value from the PredictionMethod enumeration
    *        confidence: if true, add the confidence, distribution, counts
    *        distribution: if true, add the predicted node's distribution to the
    *        prediction
    *        count: if true, add the predicted nodes' instances to the
    *        prediction
    *        median: if true, add the median of the predicted nodes' distribution
    *        to the prediction
    *        min: if true, add the minimum value in the
    *        prediction's distribution (for regressions only)
    *        max: if true, add the maximum value in the
    *        prediction's distribution (for regressions only)
    *        threshold-k: the threshold to be used when method is PredictionMethod.Threshold.
    *        threshold-category: the category used with PredictionMethod.Threshold.
    *        missing_strategy: a value from the MissingStrategy enumeration
    *        median: if true, then use the median of each individual model's predicted
    *        node as individual prediction for the specified
    *        combination method.
    */
    open func predict(_ arguments : [String : AnyObject],
        options : [String : Any])
        -> [String : Any] {
        
        assert(self.isReadyToPredict)
        
        let method = options["method"] as? PredictionMethod ?? PredictionMethod.plurality
        let missingStrategy = options["strategy"] as? MissingStrategy ??
            MissingStrategy.lastPrediction
        let byName = options["byName"] as? Bool ?? true
        let confidence = options["confidence"] as? Bool ?? true
        let distribution = options["distribution"] as? Bool ?? false
        let count = options["count"] as? Bool ?? false
        let median = options["median"] as? Bool ?? false
        let min = options["min"] as? Bool ?? false
        let max = options["max"] as? Bool ?? false
        
        let votes = self.multiModels.map{ (multiModel : MultiModel) in
            multiModel.generateVotes(arguments,
                byName: byName,
                missingStrategy: missingStrategy,
                median: median)
        }
        let multiVote = MultiVote(predictions: [])
        for v in votes {
            if (median) {
                v.addMedian()
            }
            multiVote.extend(v)
        }
        return multiVote.combine(method,
            confidence: confidence,
            distribution: distribution,
            count: count,
            median: median,
            addMin: min,
            addMax: max,
            options: options)
    }
    
    open func fieldImportance() -> [String : Double] {
        
        var fieldImportance : [String : Double] = [:]
        var fieldNames : [String : String] = [:]
        let importances = self.distributions.map {
            $0["importance"] as? [[AnyObject]] ?? []
        }
        for modelInfo in importances {
            for info in modelInfo {
                let fieldId = info[0] as? String ?? ""
                if !fieldImportance.keys.contains(fieldId) {
                    fieldImportance.updateValue(0.0, forKey: fieldId)
                    fieldNames.updateValue(self.fields[fieldId]?["name"] as? String ?? "",
                        forKey: fieldId)
                }
                let imp = info[1] as? Double ?? Double.nan
                fieldImportance.updateValue(fieldImportance[fieldId]! + imp, forKey: fieldId)
            }
        }
        return fieldImportance
    }
}
