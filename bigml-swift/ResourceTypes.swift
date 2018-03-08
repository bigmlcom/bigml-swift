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

@objc public enum BMLMode : Int {
    
    case Development
    case Production
}

@objc public enum BMLResourceType : Int, ExpressibleByStringLiteral {
    
    case File
    case Source
    case Dataset
    case Model
    case Cluster
    case Anomaly
    case Ensemble
    case LogisticRegression
    case TopicModel
    case TopicDistribution
    case Association
    case Evaluation
    case Prediction
    case Project
    case Configuration
    case WhizzmlSource
    case WhizzmlScript
    case WhizzmlExecution
    case NotAResource
    
    static let all = [File, Source, Dataset, Model, Cluster, Anomaly, Prediction, Project]
    
    public init(stringLiteral value: String) {
        switch (value) {
        case "file":
            self = .File
        case "source":
            self = .Source
        case "dataset":
            self = .Dataset
        case "model":
            self = .Model
        case "cluster":
            self = .Cluster
        case "prediction":
            self = .Prediction
        case "anomaly":
            self = .Anomaly
        case "ensemble":
            self = .Ensemble
        case "logisticregression":
            self = .LogisticRegression
        case "topicmodel":
            self = .TopicModel
        case "topicdistribution":
            self = .TopicDistribution
        case "association":
            self = .Association
        case "evaluation":
            self = .Evaluation
        case "configuration":
            self = .Configuration
        case "sourcecode":
            self = .WhizzmlSource
        case "script":
            self = .WhizzmlScript
        case "execution":
            self = .WhizzmlExecution
        case "project":
            self = .Project
        default:
            self = .NotAResource
        }
    }
    
    public init(_ value: String) {
        self.init(stringLiteral: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self = BMLResourceType(value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self = BMLResourceType(value)
    }
    
    public func stringValue() -> String {
        switch (self) {
        case .File:
            return "file"
        case .Source:
            return "source"
        case .Dataset:
            return "dataset"
        case .Model:
            return "model"
        case .Cluster:
            return "cluster"
        case .Prediction:
            return "prediction"
        case .Anomaly:
            return "anomaly"
        case .Ensemble:
            return "ensemble"
        case .LogisticRegression:
            return "logisticregression"
        case .TopicModel:
            return "topicmodel"
        case .TopicDistribution:
            return "topicdistribution"
        case .Association:
            return "association"
        case .Configuration:
            return "configuration"
        case .Evaluation:
            return "evaluation"
        case .WhizzmlSource:
            return "sourcecode"
        case .WhizzmlScript:
            return "script"
        case .WhizzmlExecution:
            return "execution"
        case .Project:
            return "project"
        default:
            return "invalid"
        }
    }
}

/*
 * This class works as a high-level bridge to BMLResourceType to overcome C-enum limitations.
 * Indeed, BMLResourceType is bridged to Objective-C through a C-enum, which is a very poor
 * abstraction and makes it trivial.
 * You should always use BMLResourceType in Swift code and only resort to BMLResourceTypeIdentifier
 * in Objective-C.
 */

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

public func == (left : BMLResourceTypeIdentifier, right : BMLResourceType) -> Bool {
    return left.type == right
}

public func != (left : BMLResourceTypeIdentifier, right : BMLResourceType) -> Bool {
    return left.type != right
}

public typealias BMLResourceUuid = String
public typealias BMLResourceFullUuid = String

