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

internal struct TreePrediction {
    
    let prediction : AnyObject
    let confidence : Double
    let count : Int
    let median : Double
    let min : Double
    let max : Double
    let path : [String]
    let distribution : [(value : AnyObject, dist : Int)]
    let distributionUnit : String
    let children : [PredictionTree]
    var probability : Double = Double.NaN
    var next : String = ""
    
    init(prediction : AnyObject,
        confidence : Double,
        count : Int,
        median : Double,
        min : Double,
        max : Double,
        path : [String],
        distribution : [(value : AnyObject, dist : Int)],
        distributionUnit : String,
        children : [PredictionTree]) {
            
            self.prediction = prediction
            self.confidence = confidence
            self.count = count
            self.median = median
            self.min = min
            self.max = max
            self.path = path
            self.distribution = distribution
            self.distributionUnit = distributionUnit
            self.children = children
    }
}