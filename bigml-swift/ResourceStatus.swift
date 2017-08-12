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

/**
The following values must match those at https://bigml.com/developers/status_codes
Not all values are necessarily to be represented.
**/
@objc public enum BMLResourceStatus : Int, ExpressibleByIntegerLiteral {
    
    case undefined = 1000
    case waiting = 0
    case queued = 1
    case started = 2
    case inProgress = 3
    case summarized = 4
    case ended = 5
    case failed = -1
    case unknown = -2
    case runnable = -3
    
    public init(integerLiteral value: IntegerLiteralType) {
        switch(value) {
        case 1000:
            self = .undefined
        case 0:
            self = .waiting
        case 1:
            self = .queued
        case 2:
            self = .started
        case 3:
            self = .inProgress
        case 4:
            self = .summarized
        case 5:
            self = .ended
        case -1:
            self = .failed
        case -2:
            self = .unknown
        case -3:
            self = .runnable
        default:
            self = .undefined
        }
    }
}

func < (left : BMLResourceStatus, right : BMLResourceStatus) -> Bool {
    return left.rawValue < right.rawValue
}
func != (left : BMLResourceStatus, right : BMLResourceStatus) -> Bool {
    return left.rawValue != right.rawValue
}
