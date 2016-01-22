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

public typealias CentroidInfo = (centroidId : Int, centroidName : String, centroidDistance : Double)

/** A local predictive Cluster.

This module defines a Cluster to make predictions (centroids) locally or
embedded into your application without needing to send requests to
BigML.io.

This module cannot only save you a few credits, but also enormously
reduce the latency for each prediction and let you use your models
offline.

**/

private let kOptionalFields = ["categorical", "text", "items"]

public class Cluster : FieldedResource {
    
    var tagCloud : [String : AnyObject] = [:]
    var termForms : [String : [String : [String]]] = [:]
    var termAnalysis : [String : [String : AnyObject]] = [:]
    var items : [String : AnyObject] = [:]
    var itemAnalysis : [String : [String : AnyObject]] = [:]
    
    var centroids : [Centroid]
    let scales : [String : Double]

    var clusterDescription : String
    var ready : Bool
    
    static func predict(jsonCluster : [String : AnyObject],
        arguments : [String : AnyObject],
        options : [String : Any]) -> CentroidInfo {
        
            let fields = (jsonCluster["clusters"]?["fields"] as? [String : AnyObject] ?? [:])
            let inputData : [String : AnyObject] = fields.filter{ (key, _) in
                if let name = fields[key]?["name"] as? String {
                    return (arguments[name] != nil)
                }
                return false
            }.map{ (key : String, _ : AnyObject) -> (String, AnyObject) in
                if let name = fields[key]?["name"] as? String {
                    return (key, arguments[name]!)
                }
                assert(false, "Cluster.predict(...), map got corrupted?")
                return (key, "")
            }
            
            return Cluster(jsonCluster: jsonCluster).centroid(inputData,
                byName: options["byName"] as? Bool ?? false)
    }
    
    required public init(jsonCluster : [String : AnyObject]) {
        
        if let clusters = jsonCluster["clusters"]?["clusters"] as? [[String : AnyObject]],
            status = jsonCluster["status"] as? [String : AnyObject],
            code = status["code"] as? Int where code == 5 {
                self.centroids = clusters.map{
                    Centroid(cluster: $0)
                }
        } else {
            self.centroids = []
        }
        self.scales = jsonCluster["scales"] as? [String : Double] ?? [:]
        let summaryFields = jsonCluster["summary_fields"] as? [String] ?? []
        let fields = (jsonCluster["clusters"]?["fields"] as? [String : AnyObject] ?? [:]).filter{
            (key : String, value : AnyObject) in
            !summaryFields.contains(key)
        }
        for fieldId in self.scales.keys {
            assert(fields.keys.contains(fieldId), "Some fields are missing")
        }
        for (fieldId, field) in fields {
            if let field = field as? [String : AnyObject],
                optype = field["optype"] as? String {
            
                    if optype == "text" {
                        if let termForms = field["summary"]?["term_forms"] as?
                            [String : [String]] {
                            self.termForms[fieldId] = termForms
                        }
                        if let tagCloud = field["summary"]?["tag_cloud"] {
                            self.tagCloud[fieldId] = tagCloud
                        }
                        if let termAnalysis = field["term_analysis"] as?
                            [String : [String : AnyObject]] {
                            self.termAnalysis[fieldId] = termAnalysis
                        }
                    } else if optype == "items" {
                        self.items[fieldId] = field["summary"]?["items"] ?? [:]
                        self.itemAnalysis = field["item_analysis"] as?
                            [String : [String : AnyObject]] ?? [:]
                    }
            }
        }
        self.clusterDescription =  jsonCluster["description"] as? String ?? ""
        self.ready = true
        super.init(fields: fields)
    }
    
    /**
      * Returns the id of the nearest centroid
      */
    public func centroid(arguments : [String : AnyObject], byName : Bool) -> CentroidInfo {
        
        var filteredArguments = self.filteredInputData(arguments, byName: byName)
        for (fieldId, field) in self.fields {
            if let optype = field["optype"] as? String
                where !kOptionalFields.contains(optype) && !arguments.keys.contains(fieldId) {
                    assert(filteredArguments.keys.contains(fieldId),
                        "Failed to predict a centroid. Arguments must contain values for all numeric fields.")
            }
        }
        filteredArguments = castArguments(filteredArguments, fields: self.fields)
        let uTerms = uniqueTerms(filteredArguments,
            termForms: self.termForms,
            termAnalysis: self.termAnalysis,
            tagCloud: self.tagCloud,
            items: self.items,
            itemAnalysis: self.itemAnalysis)
        
        return nearest(filteredArguments, uniqueTerms: uTerms)
    }
    
    func nearest(arguments : [String : AnyObject], uniqueTerms : [String : [(AnyObject, Int)]])
        -> CentroidInfo {

            var uTerms = [String : [String]]()
            for (term, occurrences) in uniqueTerms {
                uTerms[term] = occurrences.map{ $0.0 as? String ?? ""}
            }
            var nearestCentroid = (centroidId: -1,
                centroidName: "",
                centroidDistance: Double.infinity);
            for centroid in self.centroids {
                let squareDistance = centroid.squareDistance(arguments,
                    uniqueTerms: uTerms,
                    scales: self.scales,
                    nearestDistance: nearestCentroid.centroidDistance)
                if !squareDistance.isNaN {
                    nearestCentroid = (centroidId: centroid.centroidId,
                        centroidName: centroid.name,
                        centroidDistance: squareDistance);
                }
            }
            return (centroidId: nearestCentroid.centroidId,
                centroidName: nearestCentroid.centroidName,
                centroidDistance: sqrt(nearestCentroid.centroidDistance))
    }
}