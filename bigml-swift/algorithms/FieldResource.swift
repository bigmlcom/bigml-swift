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

let DEFAULT_MISSING_TOKENS = [
"", "N/A", "n/a", "NULL", "null", "-", "#DIV/0",
"#REF!", "#NAME?", "NIL", "nil", "NA", "na",
"#VALUE!", "#NULL!", "NaN", "#N/A", "#NUM!", "?"
]

private func makeFieldNamesUnique(_ fields : [String : AnyObject], objectiveFieldId : String?)
    -> ([String : AnyObject], [String], [String], [String : String], [String : String]) {
        
        var fieldNames : [String] = []
        var fieldIds : [String] = []
        var fieldNameById : [String : String] = [:]
        var fieldIdByName : [String : String] = [:]
        
        let addFieldId = { (fieldId : String, name : String) in
            fieldNames.append(name)
            fieldIdByName.updateValue(fieldId, forKey: name)
            fieldNameById.updateValue(name, forKey: fieldId)
        }
        
        if let objectiveFieldId = objectiveFieldId,
            let field = fields[objectiveFieldId] as? [String : Any],
            let fieldName = field["name"] as? String {
                addFieldId(objectiveFieldId, fieldName)
        }
        
        var fields2 = fields
        for fieldId in fields.keys {
            if fieldIds.index(of: fieldId) == nil {
                fieldIds.append(fieldId)
                if let field = fields[fieldId] as? [String : Any],
                    let fieldName = field["name"] as? String {
                        
                        var uniqueName = fieldName
                        if fieldNames.index(of: fieldName) != nil {
                            if let col_number = field["column_number"] {
                                uniqueName = "\(uniqueName)\(col_number)"
                                if fieldNames.index(of: fieldName) != nil {
                                    uniqueName = "\(uniqueName)\(fieldId)"
                                }
                            }
                        }
                        addFieldId(fieldId, uniqueName)
                        var field = fields2[fieldId] as! [String : Any]
                        field.updateValue(fieldName as Any, forKey: "name")
                }
            }
        }
        return (fields2, fieldNames, fieldIds, fieldNameById, fieldIdByName)
}

private func invertedFieldMap(_ fields : [String : Any]) -> [String : String] {
    
    var fieldMap : [String : String] = [:]
    for (key, value) in fields {
        if let value = value as? [String : Any],
            let name = value["name"] as? String {
            fieldMap[name] = key
        }
    }
    return fieldMap
}

open class FieldedResource {
    
    internal let fields : [String : AnyObject]
    internal let objectiveId : String?
    internal let locale : String?
    internal let missingTokens : [String]?
    internal var inverseFieldMap : [String : String]
    
    internal let fieldNames : [String]
    internal let fieldIds : [String]
    internal let fieldIdByName : [String : String]
    internal let fieldNameById : [String : String]
    
    init(fields : [String : AnyObject],
        objectiveId : String? = .none,
        locale : String? = .none,
        missingTokens : [String]? = DEFAULT_MISSING_TOKENS) {
            
            self.objectiveId = objectiveId
            self.locale = locale
            self.missingTokens = missingTokens
            self.inverseFieldMap = invertedFieldMap(fields)
            (self.fields,
                self.fieldNames,
                self.fieldIds,
                self.fieldNameById,
                self.fieldIdByName) = makeFieldNamesUnique(fields, objectiveFieldId: objectiveId)
    }
    
    func normalizedValue(_ value : Any) -> Any? {
        
        if let value = value as? String, let missingTokens = missingTokens {
            if missingTokens.contains(value) {
                return .none
            }
        }
        return value
    }
    
    func filteredInputData(_ input : [String : Any],
        byName : Bool = true) -> [String : Any] {
        
        var output : [String : Any] = [:]
        for (key, value) in input {
            if let value : Any = self.normalizedValue(value) {
                if self.objectiveId == .none || key != self.objectiveId {
                    if let key = byName ? self.inverseFieldMap[key] : key {
                        output[key] = value
                    }
                }
            }
        }
        return output
    }
}
