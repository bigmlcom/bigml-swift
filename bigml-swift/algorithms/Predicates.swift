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

func plural(_ string : String, multiplicity : Int) -> String {
    
    if (multiplicity == 1) {
        return string
    }
    return "\(string)s"
}

class Predicate {
    
    static let TM_TOKENS = "tokens_only"
    static let TM_FULL_TERMS = "full_terms_only"
    static let TM_ALL = "all"
    static let FULL_TERM_PATTERN = "^.+\\b.+$"
    
    var op : String
    var field : String
    var value : Any
    var term : String?
    var missing : Bool
    
    init (op : String, field : String, value : Any, term : String? = .none) {
        
        self.op = op
        self.field = field
        self.value = value
        self.term = term
        self.missing = false
        if self.op =~? "\\*$" {
            self.missing = true
            self.op = self.op.substring(to: self.op.characters.index(self.op.startIndex, offsetBy: self.op.characters.count-1))
        }
    }
    
    /**
     * Returns a boolean showing if a term is considered as a full_term
     */
    func isFullTerm(_ fields : [String : Any]) -> Bool {
        
        if let term = self.term,
            let fieldDict = fields[self.field] as? [String : Any],
            let optype = fieldDict["optype"] as? String, optype != "items" {
                
                if let options = fieldDict["term_analysis"] as? [String : Any] {

                    let tokenMode = options["token_mode"] as? String ?? Predicate.TM_TOKENS
                    if tokenMode == Predicate.TM_FULL_TERMS {
                        return true
                    }
                    if tokenMode == Predicate.TM_ALL {
                        return term =~? Predicate.FULL_TERM_PATTERN
                    }
                }
        }
        return false
    }
    
    /**
     * Builds rule string from a predicate
    */
    func rule(_ fields : [String : Any], label : String = "name") -> String {
        
        if let fieldDict = fields[self.field] as? [String : Any] {
            
            let name = fieldDict[label] as? String ?? ""
            let fullTerm = self.isFullTerm(fields)
            let relationMissing = self.missing ? " or missing " : ""
            if let term = self.term, let value = self.value as? Int {
                var relationSuffix = ""
                let relationLiteral : String
                if ((self.op == "<" && value <= 1) || (self.op == "<=" && value == 0)) {
                    relationLiteral = fullTerm ? " is not equal to " : " does not contain "
                } else {
                    relationLiteral = fullTerm ? " is equal to " : " contains "
                    if !fullTerm {
                        if self.op != ">" || value != 0 {
                            let times = plural("time", multiplicity: value)
                            if self.op == ">=" {
                                relationSuffix = "\(value) \(times) at most"
                            } else if self.op == "<=" {
                                relationSuffix = "no more than \(value) \(times)"
                            } else if self.op == ">" {
                                relationSuffix = "more than \(value) \(times)"
                            } else if self.op == "<" {
                                relationSuffix = "less than \(value) \(times)"
                            }
                        }
                    }
                }
                return "\(name) \(relationLiteral) \(term) \(relationSuffix)\(relationMissing)"
            }
            if let value = self.value as? NSNull {
                let _ = (self.op == "=") ? " is None " : " is not None "
                return "\(name) \(self.op) \(value) \(relationMissing)"
            } else {
                return "\(name) \(self.op) \(value) \(relationMissing)"
            }
        } else {
            return self.op
        }
    }

    /**
      * Counts the number of occurences of the words in forms_list in the text
      *
      * The terms in forms_list can either be tokens or full terms. The
      * matching for tokens is contains and for full terms is equals.
      */
    static func termCount(_ text : String,
        forms : [String],
        options : [String : Any] = [:])
        -> Int {

        let tokenMode = options["token_mode"] as? String ?? Predicate.TM_TOKENS
        let caseSensitive = options["case_sensitive"] as? Bool ?? false
        let firstTerm = forms[0]
        if (tokenMode == Predicate.TM_FULL_TERMS) {
            return self.fullTermCount(text, fullTerm: firstTerm, caseSensitive: caseSensitive)
        }
        if (tokenMode == Predicate.TM_ALL && forms.count == 1) {
            if (firstTerm =~? Predicate.FULL_TERM_PATTERN) {
                return self.fullTermCount(text, fullTerm: firstTerm, caseSensitive: caseSensitive)
            }
        }
        
        return self.tokenTermCount(text, forms: forms, caseSensitive: caseSensitive)
    }
    
    static func fullTermCount(_ text : String, fullTerm : String, caseSensitive : Bool) -> Int {
        return (caseSensitive ?
            ((text == fullTerm) ? 1 : 0) :
            ((text.caseInsensitiveCompare(fullTerm) == ComparisonResult.orderedSame) ? 1 : 0));
    }

    static func tokenTermCount(_ text : String, forms : [String], caseSensitive : Bool) -> Int {

        let fre = forms.joined(separator: "(\\b|_)")
        let re = "(\\b|_)\(fre)(\\b|_)"
        return text =~~ re
    }
    
    /**
     *  Counts the number of occurences of the item in the text
     *
     * The matching considers the separator or the separating regular expression.
     */
    static func itemMatchCount(_ text : String, item : String, options : [String : Any]) -> Int {
        
        let separator = options["separator"] as? String ?? ""
        let regexp = options["separator_regexp"] as? String ?? separator
        return text =~~ "(^|\(regexp))\(item)($|\(regexp))"
    }
    
    /**
     * Counts the number of occurences of the item in the text
     *
     * The matching considers the separator or the separating regular expression
     */
    static func itemCount(_ text : String,
        item : String,
        options : [String : Any] = [:])
        -> Int {
        
        let sep = options["separator_regexp"] as? String ??
            (options["separator"] as? String ?? " ")
        return (text =~~ "(^|\(sep))\(item)(\(sep)|$))")
    }
    
    func eval(_ predicate : String, args : [String : Any]) -> Bool {
        let p = NSPredicate(format:predicate)
        return p.evaluate(with: args)
    }
    
    /**
     * Applies the operators defined in the predicate as strings to
     * the provided input data.
     */
    func apply(_ input : [String : Any], fields : [String : Any]) -> Bool {
        
        if (self.op == "TRUE") {
            return true
        }

        if self.field != "" && !fields.keys.contains(self.field) {
            return false
        }
        
        if input[self.field] == nil {
            return self.missing || (self.op == "=" && self.value as! NSObject == NSNull())
        } else if self.op == "!=" && self.value as! NSObject == NSNull() {
            return true
        }
        
        if self.op == "in" {
            return self.eval("ls \(self.op) rs",
                args: [ "ls" : input[self.field]!, "rs" : self.value])
        }
        if let term = self.term,
            let text = input[self.field] as? String,
            let field = fields[self.field] as? [String : Any],
            let optype = field["optype"] as? String {
                
                if optype == "text" {
                    
                    var termForms : [String] = []
                    if let summary = fields["summary"] as? [String : Any],
                        let allForms = summary["term_forms"] as? [String : Any],
                        let letTermForms = allForms[term] as? [String] {
                     
                            termForms = letTermForms
                    }
                    let terms = [term] + termForms
                    let options = field["term_analysis"] as? [String : Any] ?? [:]
                    
                    return self.eval("ls \(self.op) rs",
                        args: ["ls" : Predicate.termCount(text, forms: terms, options: options) as Any,
                               "rs" : self.value])
                    
                } else if optype == "items" {
                    
                    let options = field["items_analysis"] as? [String : Any] ?? [:]
                    return self.eval("ls \(self.op) rs",
                        args: ["ls" : Predicate.itemCount(text, item: term, options: options) as Any,
                            "rs" : self.value])
                } else {
                    assert(false, "Should not be here: Predicate.apply()")
                }
        }
        if let inputValue = input[self.field] {
            return self.eval("ls \(self.op) rs",
                args: ["ls" : inputValue, "rs" : self.value])
        }
        assert(false, "Should not be here: no input value provided!")
        return false
    }
}

class Predicates {
    
    let predicates : [Predicate]
    
    init(predicates : [Any]) {
        self.predicates = predicates.map() {
            
            if let _ = $0 as? String {
                return Predicate(op: "TRUE", field: "", value: 1 as Any, term: "")
            }
            if let p = $0 as? [String : Any] {
                if let op = p["op"] as? String, let field = p["field"] as? String, let value : Any = p["value"] {
                    if let term = p["term"] as? String {
                        return Predicate(op: op, field: field, value: value, term: term)
                    } else {
                        return Predicate(op: op, field: field, value: value)
                    }
                }
            }
            assert(false, "Could not create predicate")
            return Predicate(op: "", field: "", value: "" as Any)
        }
    }
    
    func rule(_ fields : [String : Any], label : String = "name") -> String {
        
        let strings = self.predicates.filter({ $0.op != "TRUE" }).map() {
            return $0.rule(fields, label: label)
        }
        return strings.joined(separator: " and ")
    }
    
    func apply(_ input : [String : Any], fields : [String : Any]) -> Bool {
        
        return predicates.reduce(true) {
            let result = $1.apply(input, fields: fields)
            return $0 && result
        }
    }
}
