//
//  AssociationItem.swift
//  BigMLKitConnector
//
//  Created by sergio on 18/12/15.
//  Copyright © 2015 BigML Inc. All rights reserved.
//

import Foundation

/**
 * AssociationItem object for the Association resource.
 *
 * Object encapsulating an Association resource item as described in
 * https://bigml.com/developers/associations
 */

open class AssociationItem : CustomStringConvertible {
 
    let index : Int
    let fieldInfo : [String : AnyObject]
    let complementIndex : Int

    open let complement : Bool
    open let count : Int
    open let itemDescription : String
    open let fieldId : String
    open let name : String
    open let binEnd : Double
    open let binStart : Double
    
    open var description : String {
        
        get {
            return ["bin_end" : self.binEnd,
                "bin_start" : self.binStart,
                "complement" : self.complement,
                "count" : self.count,
                "description" : self.itemDescription,
                "field_id" : self.fieldId,
                "name" : self.name].description
        }
    }
    
    public required init(index : Int,
        itemInfo : [String : AnyObject],
        fields : [String : AnyObject]) {
        
            self.index = index
            self.complement = itemInfo["complement"] as? Bool ?? false
            self.complementIndex = itemInfo["complement_index"] as? Int ?? 0
            self.count = itemInfo["count"] as? Int ?? 0
            self.itemDescription =  itemInfo["description"] as? String ?? ""
            self.fieldId = itemInfo["field_id"] as? String ?? ""
            self.fieldInfo = fields[self.fieldId] as? [String : AnyObject] ?? [:]
            self.name = itemInfo["name"] as? String ?? ""
            self.binEnd = itemInfo["bin_end"] as? Double ?? Double.nan
            self.binStart = itemInfo["bin_start"] as? Double ?? Double.nan
    }
    
    /**
     * Checks whether the value is in a range for numeric fields or
     * matches a category for categorical fields
     */
    func doesMatch(_ value : AnyObject) -> Bool {

        var result = false
        if let fieldType = self.fieldInfo["optype"] as? String {
            switch fieldType {
            case "numeric":
                if let value = value as? Double {
                    if self.binEnd != -1 && self.binStart != -1 {
                        result = (self.binStart <= value) && value <= self.binEnd
                    } else if self.binEnd != -1 {
                        result = (value) <= self.binEnd
                    } else {
                        result = (self.binStart <= value)
                    }
                } else {
                    assert(false,
                        "AssociationItem.doesMatch: inconsistent fieldType and value (Int)")
                }
            case "text":
                //-- This block is equivalent to one in Predicate.apply() -- refactor?
                if let summary = self.fieldInfo["summary"] as? [String : AnyObject],
                    let allForms = summary["term_forms"] as? [String : [String]] {
                        if let value = value as? String {
                            let termForms = allForms[self.name] ?? []
                            let terms = [self.name] + termForms
                            let options = self.fieldInfo["term_analysis"]
                                as? [String : AnyObject] ?? [:]
                            result = Predicate.termCount(value, forms: terms, options: options) > 0
                        } else {
                            assert(false,
                                "AssociationItem.doesMatch: inconsistent fieldType and value (String)")
                        }
                }
            case "categorical":
                result = (self.name == value as! String)
            case "items":
                let options = self.fieldInfo["term_analysis"] as? [String : AnyObject] ?? [:]
                result = Predicate.itemCount(value as? String ?? "", item: self.name, options: options) > 0
            default:
                return false
            }
        }
        return result
    }
}
