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

class Centroid {
    
    let center : [String : Any]
    let count : Int
    let centroidId : Int
    let name : String
    
    required init(cluster : [String : Any]) {
        
        self.center = cluster["center"] as? [String : Any] ?? [:]
        self.count = cluster["count"] as? Int ?? 0
        self.centroidId = cluster["id"] as? Int ?? 0
        self.name = cluster["name"] as? String ?? ""
    }
    
    /**
    * Squared distance from the given input data to the centroid
    *
    * @param {object} inputData Object describing the numerical or categorical
    *                           input data per field
    * @param {object} termSets Object containing the array of unique terms per
    *                          field
    * @param {object} scales Object containing the scaling factor per field
    * @param {number} stopDistance2 Maximum allowed distance. If reached,
    *                               the algorithm stops computing the actual
    *                               squared distance
    */
    func squareDistance(_ inputData : [String : Any],
        uniqueTerms : [String : Any],
        scales : [String : Double],
        nearestDistance : Double) -> Double {
        
            var terms : [String] = []
            var d2 = 0.0
            for (key, value) in self.center {
                guard let scale = scales[key] else {
                    break
                }
                if let value = value as? [String] {
                    terms = uniqueTerms[key] as? [String] ?? []
                    d2 += self.cosineDistance(terms,
                        centroidTerms: value,
                        scale: scale)
                } else if let value = value as? String {
                    if !inputData.keys.contains(key) || (inputData[key] as? String) != value {
                        d2 += 1.0 * scale * scale
                    }
                } else if let value = value as? Double {
                    d2 += pow(scale * (doubleFromNum(inputData[key]) - value), 2)
                }
                if nearestDistance <= d2 {
                    return Double.nan
                }
            }
            return d2
    }
    
    /**
    * Returns the square of the distance defined by cosine similarity
    *
    * @param {array} terms Array of input terms
    * @param {array} centroidTerms Array of terms used in the centroid field
    * @param {number} scale Scaling factor for the field
    */
    func cosineDistance(_ terms : [String], centroidTerms : [String], scale : Double) -> Double {
        
        if terms.count == 0 && centroidTerms.count == 0 {
            return 0.0
        }
        if terms.count == 0 || centroidTerms.count == 0 {
            return pow(scale, 2)
        }
        let inputCount = terms.filter{
            terms.contains($0)
        }.count
        
        let cosineSimilarity = Double(inputCount) /
            sqrt(Double(terms.count * centroidTerms.count))
        let similarityDistance = scale * (1 - cosineSimilarity)
        return pow(similarityDistance, 2)
    }
}
