//
//  AssociationRule.swift
//  BigMLKitConnector
//
//  Created by sergio on 17/12/15.
//  Copyright © 2015 BigML Inc. All rights reserved.
//

import Foundation

/**
 * Object encapsulating an association rules as described in
 * https://bigml.com/developers/associations
 */

open class AssociationRule {
    
    let ruleId : String
    let confidence : Double
    let leverage : Double
    let lhs : [Int]
    let lhsCover : [Int]
    let rhs : [Int]
    let rhsCover : [Int]
    let pValue : Double
    let lift : Double
    let support : [Double]
    
    public required init(ruleInfo : [String : Any]) {
        
        self.ruleId = ruleInfo["id"] as? String ?? ""
        self.confidence = ruleInfo["confidence"] as? Double ?? Double.nan
        self.leverage = ruleInfo["leverage"] as? Double ?? Double.nan
        self.lhs = ruleInfo["lhs"] as? [Int] ?? []
        self.lhsCover = ruleInfo["lhs_cover"] as? [Int] ?? []
        self.pValue = ruleInfo["p_value"] as? Double ?? Double.nan
        self.rhs = ruleInfo["rhs"] as? [Int] ?? []
        self.rhsCover = ruleInfo["rhs_cover"] as? [Int] ?? []
        self.lift = ruleInfo["lift"] as? Double ?? Double.nan
        self.support = ruleInfo["support"] as? [Double] ?? []
    }
    
    open func valueForMetric(_ metric : String) -> Any {
        
        switch metric {
        case "id":
            return self.ruleId
        case "confidence":
            return self.confidence
        case "leverage":
            return self.leverage
        case "lhs":
            return self.lhs
        case "lhsCover":
            return self.lhsCover
        case "rhs":
            return self.rhs
        case "rhsCover":
            return self.rhsCover
        case "pValue":
            return self.pValue
        case "lift":
            return self.lift
        case "support":
            return self.support
        default:
            return ""
        }
    }
    
    /**
     * Transforming the rule into a JSON object
     */
    func asJson() -> [String : Any] {
       
        return [
            "ruleId" : self.ruleId,
            "confidence" : self.confidence,
            "leverage" : self.leverage,
            "lhs" : self.lhs,
            "lhsCover" : self.lhsCover,
            "pValue" : self.pValue,
            "rhs" : self.rhs,
            "rhsCover" : self.rhsCover,
            "lift" : self.lift,
            "support" : self.support
        ]
    }
    
    /**
    * Transforming the rule into a JSON object
    */
    func asCsv() -> [Any] {
        
        return [
            self.ruleId,
            self.lhs,
            self.rhs,
            (self.lhsCover.count > 0) ? self.lhsCover[0] : Double.nan,
            (self.lhsCover.count > 1) ? self.lhsCover[1] : Double.nan,
            (self.support.count > 0) ? self.support[0] : Double.nan,
            (self.support.count > 1) ? self.support[1] : Double.nan,
            self.confidence,
            self.leverage,
            self.lift,
            self.pValue,
            (self.rhsCover.count > 0) ? self.rhsCover[0] : Double.nan,
            (self.rhsCover.count > 1) ? self.rhsCover[1] : Double.nan
        ]
    }

}
