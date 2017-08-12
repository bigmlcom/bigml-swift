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

class MultiModel {
    
    let models : [[String : AnyObject]]
    
    required init(models : [[String : AnyObject]]) {
        
        self.models = models
    }
    
    func generateVotes(_ arguments : [String : AnyObject],
        byName : Bool,
        missingStrategy : MissingStrategy,
        median : Bool) -> MultiVote {
            
            return MultiVote(predictions: self.models.map{
                Model(jsonModel: $0).predict(arguments,
                    options: [
                        "byName" : byName,
                        "strategy" : missingStrategy,
                        "median" : median,
                        "confidence" : true,
                        "count" : true,
                        "distribution" : true,
                        "multiple" : Int.max])
            })
    }
}
