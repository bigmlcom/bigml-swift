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

@objc public protocol BMLResource {
    
    var name : String  { get }
    var type : BMLResourceType  { get }
    var uuid : BMLResourceUuid { get }
    var fullUuid : BMLResourceFullUuid { get }
    
    var jsonDefinition : [String : AnyObject] { get set }
    
    var status : BMLResourceStatus { get set }
    var progress : Float { get set }
    
    init(name: String,
        type: BMLResourceType,
        uuid: BMLResourceUuid,
        definition : [String : AnyObject])
    
    init(name: String,
        fullUuid: BMLResourceFullUuid,
        definition : [String : AnyObject])
}

public class BMLMinimalResource : NSObject, BMLResource {
    
    public var name : String
    public var type : BMLResourceType
    
    public var jsonDefinition : [String : AnyObject]
    
    public dynamic var status : BMLResourceStatus
    public dynamic var progress : Float
    
    public var uuid : BMLResourceUuid
    public var fullUuid : BMLResourceFullUuid {
        get {
            return "\(type.stringValue())/\(uuid)"
        }
    }
    
    public required init(name: String, type: BMLResourceType, uuid: String, definition : [String : AnyObject] = [:]) {
        
        self.name = name
        self.type = type
        self.uuid = uuid
        self.status = BMLResourceStatus.Undefined
        self.progress = 0.0
        self.jsonDefinition = definition;
    }

    public required init(name : String, fullUuid : String, definition : [String : AnyObject]) {
        
        let components = fullUuid.characters.split {$0 == "/"}.map { String($0) }
        self.name = name
        self.type = BMLResourceType(stringLiteral: components[0])
        if components.count > 1 {
            self.uuid = components[1]
        } else {
            self.uuid = ""
        }
        self.status = BMLResourceStatus.Undefined
        self.progress = 0.0
        self.jsonDefinition = definition;
    }
}
