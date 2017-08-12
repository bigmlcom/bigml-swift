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
    
    case development
    case production
}

@objc public enum BMLResourceType : Int, ExpressibleByStringLiteral {
    
    case file
    case source
    case dataset
    case model
    case cluster
    case anomaly
    case ensemble
    case logisticRegression
    case association
    case evaluation
    case prediction
    case project
    case configuration
    case whizzmlSource
    case whizzmlScript
    case whizzmlExecution
    case notAResource
    
    static let all = [file, source, dataset, model, cluster, anomaly, prediction, project]
    
    public init(stringLiteral value: String) {
        switch (value) {
        case "file":
            self = .file
        case "source":
            self = .source
        case "dataset":
            self = .dataset
        case "model":
            self = .model
        case "cluster":
            self = .cluster
        case "prediction":
            self = .prediction
        case "anomaly":
            self = .anomaly
        case "ensemble":
            self = .ensemble
        case "logisticregression":
            self = .logisticRegression
        case "association":
            self = .association
        case "evaluation":
            self = .evaluation
        case "configuration":
            self = .configuration
        case "sourcecode":
            self = .whizzmlSource
        case "script":
            self = .whizzmlScript
        case "execution":
            self = .whizzmlExecution
        case "project":
            self = .project
        default:
            self = .notAResource
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
        case .file:
            return "file"
        case .source:
            return "source"
        case .dataset:
            return "dataset"
        case .model:
            return "model"
        case .cluster:
            return "cluster"
        case .prediction:
            return "prediction"
        case .anomaly:
            return "anomaly"
        case .ensemble:
            return "ensemble"
        case .logisticRegression:
            return "logisticregression"
        case .association:
            return "association"
        case .configuration:
            return "configuration"
        case .evaluation:
            return "evaluation"
        case .whizzmlSource:
            return "sourcecode"
        case .whizzmlScript:
            return "script"
        case .whizzmlExecution:
            return "execution"
        case .project:
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

@objc open class BMLResourceTypeIdentifier : NSObject, ExpressibleByStringLiteral {
    
    open var type : BMLResourceType
    
    open override var description: String {
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
    
    open func stringValue() -> String {
        return self.type.stringValue()
    }
    
    open func copyWithZone(_ zone: NSZone?) -> AnyObject {
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

