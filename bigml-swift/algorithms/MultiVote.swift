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

private let kNullCategory = "kNullCategory"
private let kBinsLimit = 32

/**
* MultiVote: combiner class for ensembles voting predictions.
*
*/
class MultiVote {
    
    var predictions : [[String : Any]]
    
    static fileprivate let combinationWeightsForMethod = [
        PredictionMethod.plurality : kNullCategory,
        PredictionMethod.confidence : "confidence",
        PredictionMethod.probability : "probability",
        PredictionMethod.threshold : kNullCategory]
    
    static fileprivate let weightLabelForMethod = ["plurality", "confidence", "probability", "threshold"]
    static fileprivate let weightKeys = [[], ["confidence"], ["distribution", "count"], []]
    
    fileprivate static func weightLabel(_ method : PredictionMethod) -> String {
        assert(combinationWeightsForMethod[method] != nil)
        return combinationWeightsForMethod[method] ?? kNullCategory
    }
    
    /**
    * MultiVote: combiner class for ensembles voting predictions.
    *
    * @param predictions: Array of model's predictions
    */
    required init(predictions : [[String : Any]]) {
        
        self.predictions = predictions
        var ordered = true
        for p in self.predictions {
            if p["order"] == nil {
                ordered = false
            }
        }
        if !ordered {
            var count = 0
            for var p in self.predictions {
                count += 1;
                p.updateValue(count, forKey: "order")
            }
        }
    }
    
    
    /**
    * Return the next order to be assigned to a prediction
    *
    * Predictions in MultiVote are ordered in arrival sequence when
    * added using the constructor or the append and extend methods.
    * This order is used to break even cases in combination
    * methods for classifications.
    *
    * @return the next order to be assigned to a prediction
    */
    func nextOrder() -> Int {
        return (self.predictions.last?["order"] as? Int ?? 0) + 1
    }
    
    /**
    * Given a MultiVote instance, extends its prediction array
    * with another MultiVote's predictions and adds the order information.
    *
    * For instance, votes could be:
    *
    *  [{'prediction': 'Iris-virginica', 'confidence': 0.3},
    *      {'prediction': 'Iris-versicolor', 'confidence': 0.8}]
    *
    *  where the expected prediction keys are: prediction (compulsory),
    *  confidence, distribution and count.
    *
    * @param votes
    */
    func extend(_ votes : MultiVote) -> MultiVote {
        
        assert(votes.predictions.count > 0, "MultiVote extendWithMultiVote: contract unfulfilled")
        if (votes.predictions.count > 0) {
            var order = self.nextOrder()
            for var p in votes.predictions {
                order += 1
                p.updateValue(order, forKey: "order")
                self.predictions.append(p)
            }
        }
        return self
    }
    
    func areKeysValid(_ keys : [String]) -> Bool {
        
        for key in keys {
            for p in self.predictions {
                if p[key] == nil {
                    return false;
                }
            }
        }
        return true;
    }
    
    /**
    * Checks the presence of each of the keys in each of the predictions
    *
    * @param keys {array} keys Array of key strings
    */
    func weightKeys(_ method : PredictionMethod) -> [String] {
        
        let keys = MultiVote.weightKeys[method.rawValue]
        return self.areKeysValid(keys) ? keys : []
    }
    
    /**
    * Check if this is a regression model
    *
    * @return {boolean} True if all the predictions are numbers.
    */
    func isRegression() -> Bool {
        for p in self.predictions {
            if p["prediction"] is String {
                return false
            }
        }
        return true
    }
    
    /**
    * Returns a distribution formed by grouping the distributions of each predicted node.
    */
    func groupedDistributionPrediction(_ prediction : [String : Any])
        -> [String : Any] {
            
            var distributionUnit = "counts"
            var groupedDistribution :[(value : Any, dist : Int)] = []
            for p in self.predictions {
                groupedDistribution = mergeDistributions(groupedDistribution,
                    distribution: p["distribution"] as? [(value : Any, dist : Int)] ?? [])
                if distributionUnit == "counts" && groupedDistribution.count > kBinsLimit {
                    distributionUnit = "bins"
                }
                groupedDistribution = mergeBins(groupedDistribution, limit: kBinsLimit)
            }
            var prediction = prediction
            prediction.updateValue(groupedDistribution, forKey: "distribution")
            prediction.updateValue(distributionUnit, forKey: "distributionUnit")
            
            return prediction
    }
    
    /*
    * Shifts and scales predictions errors to [0, top_range]. Then
    * builds e^-[scaled error] and returns the normalization factor to
    * fit them between [0, 1]
    */
    func normalizedError(_ range : Double, topRange : Double, rangeMin : Double) -> Double {
        
        var normalizedError = 0.0
        if range > 0.0 {
            for i in 0...self.predictions.count-1 {
                let delta = rangeMin - (self.predictions[i]["confidence"] as? Double ?? Double.nan)
                self.predictions[i].updateValue(exp(delta / range * topRange), forKey: "errorWeight")
                normalizedError += (self.predictions[i]["errorWeight"] as? Double ?? Double.nan)
            }
        } else {
            for i in 0...self.predictions.count-1 {
                self.predictions[i].updateValue(1.0, forKey: "errorWeight")
            }
            normalizedError = Double(self.predictions.count) 
        }
        return normalizedError
    }
    
    /**
    * Normalizes error to a [0, top_range] range and builds probabilities
    *
    * @param topRange {number} The top range of error to which the original error is
    *        normalized.
    * @return {number} The normalization factor as the sum of the normalized
    *         error weights.
    */
    func normalizedError(_ topRange : Double) -> Double {
        
        var error = 0.0
        var errorRange = 0.0
        var maxError = 0.0
        var minError = Double.infinity
        
        for p in self.predictions {
            assert(p["confidence"] != nil)
            error = p["confidence"] as? Double ?? Double.nan
            maxError = max(error, maxError)
            minError = min(error, minError)
        }
        errorRange = maxError - minError
        return self.normalizedError(errorRange, topRange: topRange, rangeMin: minError)
    }
    
    /**
    * Returns the prediction combining votes using error to compute weight
    *
    * @return [['prediction': String|Double|Int, 'confidence': Double]] The
    *         combined error is an average of the errors in the MultiVote
    *         predictions.
    */
    func weightedError(_ confidence : Bool,
        distribution : Bool,
        count : Bool,
        median : Bool,
        addMin : Bool,
        addMax : Bool) -> [String : Any] {
            
            assert(self.areKeysValid(["confidence"]))
            
            var instances = 0
            var combinedError = 0.0
            var result = 0.0
            var medianResult = 0.0
            var min = Double.infinity
            var max = -Double.infinity
            
            let topRange = 10.0
            let normalizationFactor = self.normalizedError(topRange)
            
            var newPrediction : [String : Any] = [:]
            if (normalizationFactor == 0.0) {
                newPrediction.updateValue(Double.nan, forKey: "prediction")
                newPrediction.updateValue(0.0, forKey: "confidence")
            }
            
            for p in self.predictions {
                
                result += (p["prediction"] as? Double ?? Double.nan) *
                    (p["errorWeight"] as? Double ?? Double.nan)
                if median {
                    medianResult += (p["median"] as? Double ?? Double.nan) *
                        (p["errorWeight"] as? Double ?? Double.nan)
                }
                if count {
                    instances += p["count"] as? Int ?? 0
                }
                if addMin && min > (p["min"] as? Double ?? Double.nan) {
                    min = (p["min"] as? Double ?? Double.nan)
                }
                if addMax && max < (p["max"] as? Double ?? Double.nan) {
                    max = (p["max"] as? Double ?? Double.nan)
                }
                if (confidence) {
                    combinedError += (p["confidence"] as? Double ?? Double.nan) *
                        (p["errorWeight"] as? Double ?? Double.nan)
                }
            }
            newPrediction.updateValue(result/normalizationFactor, forKey: "prediction")
            if confidence {
                newPrediction.updateValue(combinedError/normalizationFactor, forKey: "confidence")
            }
            if count {
                newPrediction.updateValue(instances, forKey: "count")
            }
            if median {
                newPrediction.updateValue(medianResult/normalizationFactor, forKey:"median")
            }
            if addMin {
                newPrediction.updateValue(min, forKey: "min")
            }
            if addMax {
                newPrediction.updateValue(max, forKey: "max")
            }
            return self.groupedDistributionPrediction(newPrediction)
    }
    
    /**
    * Returns the average of a list of numeric values.
    
    * If with_confidence is True, the combined confidence (as the
    * average of confidences of the multivote predictions) is also
    * returned
    *
    */
    func average(_ confidence : Bool,
        distribution : Bool,
        count : Bool,
        median : Bool,
        addMin : Bool,
        addMax : Bool) -> [String : Any] {
            
            let total = self.predictions.count
            var result = 0.0
            var confidenceValue = 0.0
            var medianResult = 0.0
            var min = Double.infinity
            var max = -Double.infinity
            var instances = 0
            
            for p in self.predictions {
                result += (p["prediction"] as? Double ?? Double.nan)
                if median {
                    medianResult += (p["median"] as? Double ?? Double.nan)
                }
                if confidence {
                    confidenceValue += (p["confidence"] as? Double ?? Double.nan)
                }
                if count {
                    instances += (p["count"] as? Int ?? 0)
                }
                if addMin {
                    min += (p["min"] as? Double ?? Double.nan)
                }
                if addMax {
                    max += (p["max"] as? Double ?? Double.nan)
                }
            }
            if total > 0 {
                result /= Double(total) 
                confidenceValue /= Double(total) 
                medianResult /= Double(total) 
            } else {
                result = Double.nan
                confidenceValue = 0.0
                medianResult = Double.nan
            }
            
            var output : [String : Any] = ["prediction" : result]
            if confidence {
                output.updateValue(confidenceValue, forKey: "confidence")
            }
            if distribution {
                output = self.groupedDistributionPrediction(output)
            }
            if count {
                output.updateValue(instances, forKey: "count")
            }
            if median {
                output.updateValue(medianResult, forKey: "median")
            }
            if addMin {
                output.updateValue(min, forKey: "min")
            }
            if addMax {
                output.updateValue(max, forKey: "max")
            }
            return output
    }
    
    /**
    * Singles out the votes for a chosen category and returns a prediction
    *  for this category if the number of votes reaches at least the given
    *  threshold.
    *
    * @param threshold the number of the minimum positive predictions needed for
    *                    a final positive prediction.
    * @param category the positive category
    * @return MultiVote instance
    */
    func singleOutCategory(_ category : String, threshold : Int) -> MultiVote {
        
        assert(threshold > 0 && category != "",
            "MultiVote singleOutCategory contract unfulfilled")
        assert(threshold <= self.predictions.count,
            "MultiVote singleOutCategory: threshold higher than prediction count")
        var categoryPredictions : [[String : Any]] = []
        var restOfPredictions : [[String : Any]] = []
        for p in self.predictions {
            if let prediction = p["prediction"] as? String, category == prediction {
                categoryPredictions.append(p)
            } else {
                restOfPredictions.append(p)
            }
        }
        if categoryPredictions.count >= threshold {
            return MultiVote(predictions: categoryPredictions)
        }
        return MultiVote(predictions: restOfPredictions)
    }
    
    /**
    * Compute the combined weighted confidence from a list of predictions
    *
    * @param combinedPrediction {object} combinedPrediction Prediction object
    * @param weightLabel {string} weightLabel Label of the value in the prediction object
    *        that will be used to weight confidence
    */
    func weightedConfidence(_ combinedPrediction : Any,
        weightLabel : String) -> [String : Any] {
            
            var finalConfidence = 0.0
            var weight = 1.0
            var totalWeight = 0.0
            
            let predictions = self.predictions.filter{
                if let prediction = $0["prediction"] as? String {
                    return prediction == combinedPrediction as? String ?? ""
                } else if let prediction = $0["prediction"] as? Double {
                    return prediction == (combinedPrediction as? Double ?? Double.nan)
                } else if let prediction = $0["prediction"] as? Int {
                    return prediction == combinedPrediction as? Int ?? Int.max
                }
                return false
            }
            if weightLabel != kNullCategory {
                for p in predictions {
                    assert(p["confidence"] != nil && p[weightLabel] != nil,
                        "MultiVote weightedConfidence: not enough data to use selected method (missing \(weightLabel)")
                }
            }
            for p in predictions {
                if (weightLabel != kNullCategory) {
                    weight = p[weightLabel] as? Double ?? Double.nan
                }
                finalConfidence += weight * (p["confidence"] as? Double ?? Double.nan)
                totalWeight += weight
            }
            if totalWeight > 0 {
                finalConfidence = finalConfidence / totalWeight
            } else {
                finalConfidence = 0.0
            }
            
            return ["prediction" : combinedPrediction, "confidence" : finalConfidence]
    }
    
    /**
    * Builds a distribution based on the predictions of the MultiVote
    *
    * @param weightLabel {string} weightLabel Label of the value in the prediction object
    *        whose sum will be used as count in the distribution
    */
    func combinedDistribution(_ weightLabel : String = "probability") -> (Any, Any) {
        
        var total = 0
        var distribution : [String : Any] = [:]
        let weightedValue : (String) -> Double =  { predictionName in
            return (distribution[predictionName] as? Double ?? Double.nan *
                (distribution[weightLabel] as? Double ?? Double.nan))
        }
        for p in self.predictions {
            assert(p[weightLabel] != nil, "MultiVote combinedDistribution contract unfulfilled")
            if let predictionName = p["prediction"] as? String {
                if distribution[predictionName] == nil {
                    distribution.updateValue(0.0 as Any, forKey: predictionName)
                }
                distribution.updateValue(weightedValue(predictionName) as Any,
                    forKey: predictionName)
                total += p["count"] as? Int ?? 0
            }
        }
        return (distribution as Any, total as Any)
    }
    
    /**
    *  Returns the prediction combining votes by using the given weight:
    *
    * weight_label can be set as:
    * None:          plurality (1 vote per prediction)
    * 'confidence':  confidence weighted (confidence as a vote value)
    * 'probability': probability weighted (probability as a vote value)
    *
    * If with_confidence is true, the combined confidence (as a weighted
    * average of the confidences of the votes for the combined
    * prediction) will also be given.
    */
    func combineCategorical(_ weightLabel : String, confidence : Bool) -> [String : Any] {
        
        var weight = 1.0
        var mode : [String : (count : Double, order : Int)] = [:]
        var category : String
        
        for p in self.predictions {
            
            if (weightLabel != kNullCategory) {
                assert(MultiVote.weightLabelForMethod.contains(weightLabel),
                    "MultiVote combineCategorical: wrong weightLabel")
                assert(p[weightLabel] != nil,
                    "MultiVote combineCategorical: Not enough data to use the selected method.")
                
                if (p[weightLabel] != nil) {
                    weight = p[weightLabel] as? Double ?? Double.nan
                }
            }
            category = p["prediction"] as? String ?? kNullCategory
            
            let categoryHash : (count : Double, order : Int)
            if let m = mode[category] {
                categoryHash = (count: weight + m.count, order: m.order)
            } else {
                categoryHash = (count: weight, order: p["order"] as? Int ?? -1)
            }
            mode.updateValue(categoryHash, forKey: category)
        }
        
        let predictionName = mode.sorted{
            
            let w0 = $0.1.count
            let w1 = $1.1.count
            let order0 = $0.1.order
            let order1 = $1.1.order
            return w0 > w1 ? false : (w0 < w1 ? true : order0 < order1 ? false : true)
            }.last?.0 ?? ""
        
        var result : [String : Any] = [:]
        result.updateValue(predictionName, forKey: "prediction")
        
        if (confidence) {
            if (self.predictions.first?["confidence"] != nil) {
                return self.weightedConfidence(predictionName as Any, weightLabel:weightLabel)
            }
            let distributionInfo = self.combinedDistribution(weightLabel)
            let count = distributionInfo.1 as? Int ?? -1
            let distribution = distributionInfo.0 as? [(value : Any, dist : Int)] ?? []
            let combinedConfidence = wsConfidence(predictionName as Any,
                distribution: distribution,
                n: count)
            result.updateValue(combinedConfidence, forKey: "confidence")
        }
        return result
    }
    
    func probabilityWeight() -> [[String : Any]] {
        
        var predictions : [[String : Any]] = []
        
        for p in self.predictions {
            assert(p["distribution"] != nil && p["count"] != nil,
                "Wrong prediction found: no distribution/count info")
            let total = p["count"] as? Int ?? 0
            assert(total > 0, "Wrong total in probabilityWeight")
            
            let distribution = p["distribution"] as? [String : Any] ?? [:]
            for (k, v) in distribution {
                let instances = v as? Int ?? 0
                predictions.append([
                    "prediction" : k,
                    "probability" : (Double(instances) ) /
                        (Double(total) ),
                    "count" : instances,
                    "order" : p["order"] ?? 0])
            }
        }
        return predictions
    }
    
    /**
    * Reduces a number of predictions voting for classification and averaging
    * predictions for regression.
    *
    * @param method {0|1|2|3} method Code associated to the voting method (plurality,
    *        confidence weighted or probability weighted or threshold).
    * @param withConfidence if withConfidence is true, the combined confidence
    *                       (as a weighted of the prediction average of the confidences
    *                       of votes for the combined prediction) will also be given.
    * @return {{"prediction": prediction, "confidence": combinedConfidence}}
    */
    func combine(_ method : PredictionMethod,
        confidence : Bool,
        distribution : Bool,
        count : Bool,
        median : Bool,
        addMin : Bool,
        addMax : Bool,
        options : [String : Any]) -> [String : Any] {
            
            if self.isRegression() {
                for var p in self.predictions {
                    if (p["confidence"] == nil) {
                        p["confidence"] = 0
                    }
                }
                if (method == PredictionMethod.confidence) {
                    return self.weightedError(confidence,
                        distribution: distribution,
                        count: count,
                        median: median,
                        addMin: addMin,
                        addMax: addMax)
                }
                return self.average(confidence,
                    distribution: distribution,
                    count: count,
                    median: median,
                    addMin: addMin,
                    addMax: addMax)
            }
            
            var votes : MultiVote = self
            if method == PredictionMethod.threshold {
                let threshold = options["threshold-k"] as? Int ?? 0
                let category = options["threshold-category"] as? String ?? ""
                votes = self.singleOutCategory(category, threshold: threshold)
            } else if method == PredictionMethod.probability {
                votes = MultiVote(predictions: self.probabilityWeight())
            }
            return votes.combineCategorical(MultiVote.weightLabel(method),
                confidence: confidence)
    }
    
    /**
    * Adds a new prediction into a list of predictions
    *
    * prediction_info should contain at least:
    *      - prediction: whose value is the predicted category or value
    *
    * for instance:
    *      {'prediction': 'Iris-virginica'}
    *
    * it may also contain the keys:
    *      - confidence: whose value is the confidence/error of the prediction
    *      - distribution: a list of [category/value, instances] pairs
    *                      describing the distribution at the prediction node
    *      - count: the total number of instances of the training set in the
    *                  node
    *
    * @param predictionInfo the prediction to be appended
    * @return the this instance
    */
    func append(_ predictionInfo : [String : Any]) {
        
        assert(predictionInfo.count > 0 && predictionInfo["prediction"] != nil,
            "Failed to append prediction")
        
        var dict = predictionInfo
        let order = self.nextOrder()
        dict.updateValue(order as Any, forKey: "order")
        self.predictions.append(dict)
    }
    
    func addMedian() {
        for var p in self.predictions {
            p.updateValue(p["median"] ?? Double.nan, forKey: "prediction")
        }
    }
}

