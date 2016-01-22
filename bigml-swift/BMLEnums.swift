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
* Combination methods used in ensemble classifications/regressions:
*
* Plurality: majority vote (plurality)/ average
* Confidence: confidence weighted majority vote / weighted error
* Probability: probability weighted majority vote / average
* Threshold: threshold filtered vote
*/
public enum PredictionMethod : Int {
    
    case Plurality
    case Confidence
    case Probability
    case Threshold
}

/**
* There are two possible strategies to predict when the value for the
* splitting field is missing:
*
*      0 - LastPrediction: the last issued prediction is returned.
*      1 - Proportional: as we cannot choose between the two branches
*          in the tree that stem from this split, we consider both.
*          The  algorithm goes on until the final leaves are reached
*          and all their predictions are used to decide the final
*          prediction.
*/
public enum MissingStrategy : Int {
    
    case LastPrediction
    case Proportional
}