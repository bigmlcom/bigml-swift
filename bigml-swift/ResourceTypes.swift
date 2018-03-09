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

public enum BMLResourceType : String {
    
    case File = "file"
    case Source = "source"
    case Dataset = "dataset"
    case Model = "model"
    case Cluster = "cluster"
    case Anomaly = "anomaly"
    case AnomalyScore = "anomalyscore"
    case Ensemble = "ensemble"
    case LogisticRegression = "logisticregression"
    case TopicModel = "topicmodel"
    case TopicDistribution = "topicdistribution"
    case Association = "association"
    case AssociationSet = "associationset"
    case TimeSeries = "timeseries"
    case Forecasts = "forecasts"
    case Deepnets = "deepnets"
    case Prediction = "prediction"
    case BatchPrediction = "batchprediction"
    case BatchCentroid = "batchcentroid"
    case BatchScore = "batchscore"
    case Evaluation = "evaluation"
    case Project = "project"
    case Configuration = "configuration"
    case WhizzmlSource = "sourcecode"
    case WhizzmlScript = "script"
    case WhizzmlExecution = "execution"
    case NotAResource = "invalid"
    
    public init(stringLiteral value: String) {
        if let r = BMLResourceType(rawValue: value) {
            self = r
        } else {
            self = .NotAResource
        }
    }
    
    public init(_ value: String) {
        self.init(stringLiteral: value)
    }

    @available(*, deprecated)
    public init(extendedGraphemeClusterLiteral value: String) {
        self = BMLResourceType(value)
    }

    @available(*, deprecated)
    public init(unicodeScalarLiteral value: String) {
        self = BMLResourceType(value)
    }

    @available(*, deprecated)
    public func stringValue() -> String {
        return self.rawValue
    }
}

/*
 * This class works as a high-level bridge to BMLResourceType to overcome C-enum limitations.
 * Indeed, BMLResourceType is bridged to Objective-C through a C-enum, which is a very poor
 * abstraction and makes it trivial.
 * You should always use BMLResourceType in Swift code and only resort to BMLResourceTypeIdentifier
 * in Objective-C.
 */

@available(*, deprecated)
@objc public class BMLResourceTypeIdentifier : NSObject, ExpressibleByStringLiteral {
    
    public var type : BMLResourceType
    
    public override var description: String {
        return self.stringValue()
    }
    
    public required init(rawType value: BMLResourceType) {
        self.type = value
        super.init()
    }
    
    public required init(stringLiteral value: String) {
        self.type = BMLResourceType(stringLiteral: value)
        super.init()
    }
    
    public convenience init(_ value: String) {
        self.init(stringLiteral: value)
    }
    
    public required init(extendedGraphemeClusterLiteral value: String) {
        self.type = BMLResourceType(value)
        super.init()
    }
    
    public required init(unicodeScalarLiteral value: String) {
        self.type = BMLResourceType(value)
        super.init()
    }
    
    public func stringValue() -> String {
        return self.type.stringValue()
    }
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return BMLResourceTypeIdentifier(rawType: self.type)
    }
}

@available(*, deprecated)
public func == (left : BMLResourceTypeIdentifier, right : BMLResourceType) -> Bool {
    return left.type == right
}

@available(*, deprecated)
public func != (left : BMLResourceTypeIdentifier, right : BMLResourceType) -> Bool {
    return left.type != right
}

public typealias BMLResourceUuid = String
public typealias BMLResourceFullUuid = String

