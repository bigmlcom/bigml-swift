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

let DEFAULT_RZ = 1.96

func delay(_ delay : Double, closure : @escaping ()->()) {
    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

func bridgedDictRep(_ dict : [String : Any]) -> [String : Any] {
    
    var result = [String: Any]()
    for (key, value) in dict {
        result[key] = value as Any
    }
    return result
}

func doubleFromNum(_ num : Any?) -> Double {
    
    if let d = num as? Double {
        return d
    } else if let i = num as? Int {
        return Double(i)
    }
    return Double.nan
}

struct AnyKey : Hashable, Comparable {
    
    let underlying: Any
    fileprivate let hashValueFunc: () -> Int
    fileprivate let equalityFunc: (Any) -> Bool
    fileprivate let compareFunc: (Any) -> Bool
    
    init<T>(_ key: T) where T:Hashable, T:Comparable {
        underlying = key
        //-- Capture the key's hashability and equatability using closures.
        //-- The Key shares the hash of the underlying value.
        hashValueFunc = { key.hashValue }
        
        //-- The Key is equal to a Key of the same underlying type,
        //-- whose underlying value is "==" to ours.
        equalityFunc = {
            if let other = $0 as? T {
                return key == other
            }
            return false
        }
        
        compareFunc = {
            if let other = $0 as? T {
                return key < other
            }
            return false
        }
    }
    
    var hashValue: Int { return hashValueFunc() }
}

func ==(lhs: AnyKey, rhs: AnyKey) -> Bool {
    return lhs.equalityFunc(rhs.underlying)
}

func < (lhs: AnyKey, rhs: AnyKey) -> Bool {
    return lhs.compareFunc(rhs.underlying)
}

/**
* Adds up a new distribution structure to a map formatted distribution
*
* @param dist1
* @param dist2
* @return
*/
func mergeDoubleDistributions(_ distribution1 : [(value : Any, dist : Int)],
    distribution : [(value : Double, dist : Int)])
    -> [(value : Any, dist : Int)] {
        
        var d1 = distribution1.sorted(){
            let a0 = $0.0 as? Double ?? Double.nan
            let a1 = $1.0 as? Double ?? Double.nan
            return a0 < a1
        }
        let d2 = distribution.sorted(){ $0.0 < $1.0 }
        
        var i = 0, j = 0
        while i < d1.count {
            while (j < d2.count && (d1[i].0 as? Double ?? Double.nan) > d2[j].0) {
                j += 1
            }
            if (j < d2.count && (d1[i].0 as? Double ?? Double.nan) == d2[j].0) {
                d1[i].1 += d2[j].1
            }
            i += 1
        }
        return d1
}

func mergeDistributions(_ distribution1 : [(value : Any, dist : Int)],
    distribution : [(value : Any, dist : Int)])
    -> [(value : Any, dist : Int)] {
        
        if distribution.count == 0 {
            return distribution1
        }
        if distribution1.count == 0 {
            return distribution
        }
        
        if let _ = distribution1.first?.0 as? Double,
            let _ = distribution.first?.0 as? Double {
                
                return mergeDoubleDistributions(distribution1,
                    distribution: distribution.map { ($0.0 as? Double ?? Double.nan, $0.1) })
        }
        assert(false, "Should not be here")
        return distribution1
}

/**
* Merges the bins of a regression distribution to the given limit number.
* Two methods are provided: a generic one which is only required for compilation,
* and a Double-tailored version. The generic version simply asserts.
*/
func mergeBins(_ distribution : [(value : Any, dist : Int)], limit : Int)
    -> [(value : Any, dist : Int)] {
    
    let length = distribution.count
    if (limit < 1 || length <= limit || length < 2) {
        return distribution
    }
    var indexToMerge = 2
    var shortest = DBL_MAX
    for i in 1 ..< (length + 1) {
        let distance = (distribution[i].0 as? Double ?? Double.nan) -
            (distribution[i-1].0 as? Double ?? Double.nan)
        if distance < shortest {
            shortest = distance
            indexToMerge = i
        }
    }
    var newDistribution = Array<(value : Any, dist : Int)>(distribution[0...indexToMerge-1])
    let left = distribution[indexToMerge - 1]
    let right = distribution[indexToMerge]
    let f1 = (left.0 as? Double ?? Double.nan) * Double(left.1) +
        (right.0 as? Double ?? Double.nan) * Double(right.1)
    let f2 = left.1 * right.1
    newDistribution.append(((f1 / Double(f2)) as Any, f2))
    if (indexToMerge < length - 1) {
        newDistribution += distribution[indexToMerge + 1 ... distribution.count - 1]
    }
    return mergeBins(newDistribution, limit: limit)
}

/**
* Computes the mean of a distribution
*
* @param distribution
* @return
*/
func meanOfDistributionD(_ distribution : [(value: Double, dist: Int)]) -> Double {
    
    let (acc, count) = distribution.reduce((0.0, 0)) {
        ($1.0 * Double($1.1), $0.1 + $1.1)
    }
    return acc / Double(count)
}

func meanOfDistribution(_ distribution : [(value: Any, dist: Int)]) -> Double {
    
    return meanOfDistributionD(
        distribution.map { ($0.0 as? Double ?? Double.nan, $0.1) })
}

/**
 * Error Function
 *
 * Returns the real error function of a number.
 * An approximation from Abramowitz and Stegun is used.
 * Maximum error is 1.5e-7. More information can be found at
 * http://en.wikipedia.org/wiki/Error_function#Approximation_with_elementary_functions
 *
 * @param float $x Argument to the real error function
 * @return float A value between -1 and 1
 * @static
 */
func erf(_ x : Double) -> Double {
    
    if (x < 0) {
        return -erf(-x)
    }
    let t = 1 / (1 + 0.3275911 * x)
    let c = (0.254829592 * t - 0.284496736 * pow(t, 2) + 1.421413741 * pow(t, 3) - 1.453152027 * pow(t, 4) + 1.061405429 * pow(t, 5))
    return 1 - c * exp(-pow(x, 2));
}

/**
 * Computes the variance error
 */
func regressionError(_ variance : Double, instances : Int, rz : Double = DEFAULT_RZ) -> Double {

    if instances > 0 {
        let ppf = chi2ppf(erf(rz), instances)
        if ppf != 0 {
            let instances = Double(instances)
            let error = variance * (instances - 1) / ppf * pow(sqrt(instances) + rz, 2);
            return sqrt(error / instances);
        }
    }
    return Double.nan
}

func varianceOfDistributionD(_ distribution : [(value: Double, dist: Int)], mean : Double)
    -> Double {
    
    let (acc, count) = distribution.reduce((0.0, 0)) {
        (($1.0 - mean) * ($1.0 - mean) * Double($1.1), $0.1 + $1.1)
    }
    return acc / Double(count)
}

func varianceOfDistribution(_ distribution : [(value: Any, dist: Int)], mean : Double)
    -> Double {
    
        return varianceOfDistributionD(
            distribution.map { ($0.0 as? Double ?? Double.nan, $0.1) },
            mean: mean)
}

func medianOfDistributionD(_ distribution : [(value: Double, dist: Int)], instances : Int) -> Double {
 
    var count = 0
    var previousPoint = Double.nan
    for bin in distribution {
        let point = bin.0
        count += bin.1
        if count > instances / 2 {
            if (instances % 2 != 0) && (count-1 == instances/2) && previousPoint != Double.nan {
                return (point + previousPoint) / 2
            }
            return point
        }
        previousPoint = point
    }
    return Double.nan
}

func medianOfDistribution(_ distribution : [(value: Any, dist: Int)], instances : Int) -> Double {

    return medianOfDistributionD(
        distribution.map { ($0.0 as? Double ?? Double.nan, $0.1) },
        instances: instances)
}

func strippedValue(_ value : String, field : [String : Any]) -> String {
    
    var newValue = value
    if let prefix = field["prefix"] as? String {
        if (newValue.hasPrefix(prefix)) {
            newValue.removeSubrange(newValue.startIndex ..<
                newValue.characters.index(newValue.startIndex, offsetBy: prefix.characters.count))
        }
    }
    if let suffix = field["suffix"] as? String {
        if (newValue.hasSuffix(suffix)) {
            newValue.removeSubrange(newValue.characters.index(newValue.endIndex, offsetBy: -suffix.characters.count) ..<
                newValue.endIndex)
        }
    }
    return newValue
}

func castArguments(_ arguments : [String : Any], fields : [String : Any])
    -> [String : Any] {

        return arguments.map { (key, value) in
            let field = fields[key] as? [String : Any] ?? [:]
            if let opType = field["optype"] as? String {
                if opType == "numeric" && value is String {
                    return (key, strippedValue(value as! String, field: field) as Any)
                }
            }
            return (key, value)
        }
}

func findInDistribution(_ distribution : [(value : Any, dist : Int)],
    element : Any) -> (value : Any, dist : Int)? {
        
        for distElement in distribution {
            if distElement.0 as? String == element as? String {
                return distElement
            }
        }
        return nil
}

func wsConfidence(_ prediction : Any,
    distribution : [(value : Any, dist : Int)],
    n : Int,
    z : Double = 1.96) -> Double {
        
        var p = Double.nan
        if let v = findInDistribution(distribution, element: prediction) {
            p = Double(v.dist)
        }
        assert (!p.isNaN && p > 0)
        
        let norm = Double(distribution.reduce(0) { $0 + $1.dist })
        if norm != 1.0 {
            p /= norm
        }
        let n = Double(n)
        let z2 = z * z
        let wsFactor = z2 / n
        let wsSqrt = sqrt((p * (1 - p) + wsFactor / 4) / n)
        return (p + wsFactor / 2 - z * wsSqrt) / (1 + wsFactor)
}

func wsConfidence(_ prediction : Any,
    distribution : [(value : Any, dist : Int)]) -> Double {
        
        return wsConfidence(prediction, distribution: distribution,
            n: distribution.reduce(0) { $0 + $1.dist })
}

public func compareDoubles(_ d1 : Double, d2 : Double, eps : Double = 0.01) -> Bool {
    return ((d1 - eps) < d2) && ((d1 + eps) > d2)
}
/*
extension String {
    
    func rangeFromNSRange(_ nsRange : NSRange) -> Range<String.Index>? {
        let from16 = utf16.index(nsRange.location, offsetBy: utf16.endIndex)
        let to16 = utf16.index(nsRange.length, offsetBy: utf16.endIndex)
        if let from = String.Index(nsRange.location, within: self),
            let to = String.Index(nsRange.location, within: self) {
                return from ..< to
        }
        return nil
    }

    func NSRangeFromRange(_ range : Range<String.Index>) -> NSRange {
        let utf16view = self.utf16
        let from = String.UTF16View.Index(range.lowerBound, within: utf16view)
        let to = String.UTF16View.Index(range.upperBound, within: utf16view)
        return NSMakeRange(distance(from: from, to: utf16view.startIndex), from.distanceTo(to))
    }
}
*/
extension NSError {
    
    struct BMLExtendedError {
        static let DescriptionKey = "BMLExtendedErrorDescriptionKey"
    }
    
    convenience init(status : Any?, code : Int) {
        
        var info = "Could not complete operation"
        var extraInfo : [String : Any] = [:]
        if let statusDict = status as? [String : Any] {
            if let message = statusDict["message"] as? String {
                info = message
            }
            if let extra = statusDict["extra"] as? [String : Any] {
                extraInfo = extra
            }
        } else {
            info = "Bad response format"
        }
        self.init(info: info, code: code, message: extraInfo)
    }
    
    convenience init(info : String, code : Int, message : [String : Any] = [:]) {
        let userInfo = [
            NSLocalizedDescriptionKey : info,
            NSError.BMLExtendedError.DescriptionKey : message
            ] as [AnyHashable: Any]
        self.init(domain: "com.bigml.bigmlkitconnector", code: code, userInfo: userInfo)
    }
    
}

extension NSMutableData {
    
    func appendString(_ string: String) {
        if let data = string.data(using: String.Encoding.utf8) {
            self.append(data)
        }
    }
}

extension Dictionary {
    init(_ elements: [Element]){
        self.init()
        for (k, v) in elements {
            self[k] = v
        }
    }
    
    func map<U>(_ transform: (Value) -> U) -> [Key : U] {
        return Dictionary<Key, U>(self.map({ (key, value) in (key, transform(value)) }))
    }
    
    func map<T : Hashable, U>(_ transform: (Key, Value) -> (T, U)) -> [T : U] {
        return Dictionary<T, U>(self.map(transform))
    }
    
    func filter(_ includeElement: (Element) -> Bool) -> [Key : Value] {
        return Dictionary(self.filter(includeElement))
    }
    
    func reduce<U>(_ initial: U, combine: (U, Element) -> U) -> U {
        return self.reduce(initial, combine: combine)
    }
}

class BMLRegex {
    
    let internalExpression : NSRegularExpression
    let pattern : String
    
    init(_ pattern : String) {
        self.pattern = pattern
        do {
            self.internalExpression = try NSRegularExpression(pattern: pattern,
                options: .caseInsensitive)
        } catch {
            self.internalExpression = try! NSRegularExpression(pattern: "^$",
                options: .caseInsensitive)
        }
    }
    
    func matches(_ input : String) -> [NSTextCheckingResult] {
        return self.internalExpression.matches(in: input,
            options: [],
            range:NSMakeRange(0, input.characters.count))
    }

    func test(_ input : String) -> Bool {
        return self.matches(input).count > 0
    }

    func matchCount(_ input : String) -> Int {
        return self.matches(input).count
    }
    
    func split(_ input : String) -> [String] {
        
        var separator = "-+"
        while (input.contains(separator)) {
            separator += "-+"
        }
        return self.internalExpression.stringByReplacingMatches(in: input,
            options: NSRegularExpression.MatchingOptions(),
            range: NSMakeRange(0, (input as NSString).length),
            withTemplate:separator).components(separatedBy: separator)
    }
}

infix operator =~ : MultiplicationPrecedence
func =~ (input: String, pattern: String) -> [NSTextCheckingResult] {
    return BMLRegex(pattern).matches(input)
}

infix operator =~% : MultiplicationPrecedence
func =~% (input: String, pattern: String) -> [String] {
    return BMLRegex(pattern).split(input)
}

infix operator =~? : MultiplicationPrecedence
func =~? (input: String, pattern: String) -> Bool {
    return BMLRegex(pattern).test(input)
}

infix operator =~~ : MultiplicationPrecedence
func =~~ (input: String, pattern: String) -> Int {
    return BMLRegex(pattern).matchCount(input)
}

infix operator %% : MultiplicationPrecedence
func %%<T: Equatable> (input: Array<T>, exp: (T) -> Bool) -> Bool {
    for t in input {
        if exp(t) {
            return true
        }
    }
    return false
}

// MARK: used by logistic and cluster
/**
* Returns the list of parsed terms.
*/
func parseTerms(_ text : String, caseSensitive : Bool) -> [String] {
    
    let expression = "(\\b|_)([^\\b_\\s]+?)(\\b|_)"
    var terms = [String]()
    for result in text =~ expression {
        let term = (text as NSString).substring(with: result.range)
        terms.append(caseSensitive ? term : term.lowercased())
    }
    return terms
}

/**
 * Returns the list of parsed items.
 */
func parseItems(_ text : String, regexp : String) -> [String] {
    return text =~% regexp
}

/**
* Extracts the unique terms that occur in one of the alternative forms in
* termForms or in the tagCloud
*/
func uniqueTerms(_ terms : [String],
    forms : [String : [String]],
    tagCloud : [String])
    -> [(Any, Int)] {
        
        var extendForms : [String : String] = [:]
        for (term, formList) in forms {
            for form in formList {
                extendForms[form] = term
            }
            extendForms[term] = term
        }
        var termSet : [String : Int] = [:]
        for term in terms {
            if tagCloud.contains(term) {
                if !termSet.keys.contains(term) {
                    termSet[term] = 0
                }
                termSet.updateValue(termSet[term]! + 1, forKey: term)
            } else if let term = extendForms[term] {
                if !termSet.keys.contains(term) {
                    termSet[term] = 0
                }
                termSet.updateValue(termSet[term]! + 1, forKey: term)
            }
        }
        return termSet.map{ ($0.0 as Any, $0.1) }
}

/**
* Parses the input data to find the list of unique terms in the
* tag cloud
*/
func uniqueTerms(_ arguments : [String : Any],
    termForms : [String : [String : [String]]],
    termAnalysis : [String : [String : Any]],
    tagCloud : [String : Any],
    items : [String : Any],
    itemAnalysis : [String : [String : Any]])
    -> [String : [(Any, Int)]] {
    
        var uTerms = [String : [(Any, Int)]]()
        for fieldId in termForms.keys {
            if let inputDataField = arguments[fieldId] as? String {
                let caseSensitive : Bool = termAnalysis[fieldId]?["case_sensitive"] as? Bool ?? true
                let tokenMode : String = termAnalysis[fieldId]?["token_mode"] as? String ?? Predicate.TM_ALL
                var terms : [String] = []
                if tokenMode != Predicate.TM_FULL_TERMS {
                    terms = parseTerms(inputDataField, caseSensitive: caseSensitive)
                }
                if tokenMode != Predicate.TM_TOKENS {
                    terms.append(caseSensitive ? inputDataField : inputDataField.lowercased())
                }
                uTerms.updateValue(uniqueTerms(terms,
                    forms: termForms[fieldId] ?? [:],
                    tagCloud: tagCloud[fieldId] as? [String] ?? []),
                    forKey: fieldId)
            } else if let inputDataField = arguments[fieldId] {
                uTerms.updateValue([(inputDataField, 1)], forKey:fieldId)
            }
        }
        for (fieldId, analysis) in itemAnalysis {
            if let inputDataField = arguments[fieldId] as? String {
                let separator = analysis["separator"] as? String ?? " "
                let regexp = analysis["separator_regexp"] as? String ?? separator
                let terms : [String] = parseItems(inputDataField, regexp: regexp)
                uTerms[fieldId] = uniqueTerms(terms,
                    forms: [:],
                    tagCloud: (items[fieldId] as? [String] ?? []))
            } else if let inputDataField = arguments[fieldId] {
                uTerms[fieldId] = [(inputDataField, 1)]
            }
        }
        return uTerms
}

