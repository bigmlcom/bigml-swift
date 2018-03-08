//
//  BigMLKitConnectorChiSquaredTests.swift
//  BigMLKitConnector
//
//  Created by sergio on 25/12/15.
//  Copyright © 2015 BigML Inc. All rights reserved.
//

import XCTest
import bigmlSwift_macOS

class BigMLKitConnectorChiSquareTests: XCTestCase {

    func testChi2Ppf() {
        
        var x = chi2ppf(0.01, 55)
        XCTAssert(compareDoubles(x, d2: 33.5704))

        x = chi2ppf(0.99, 55)
        XCTAssert(compareDoubles(x, d2: 82.2921))
        
        x = chi2ppf(0.01, 555)
        XCTAssert(compareDoubles(x, d2: 480.4464))

        x = chi2ppf(0.99, 555)
        XCTAssert(compareDoubles(x, d2: 635.4341))
        
        x = chi2ppf(0.01, 5555)
        XCTAssert(compareDoubles(x, d2: 5312.7387))
        
        x = chi2ppf(0.99, 5555)
        XCTAssert(compareDoubles(x, d2: 5803.14360))
    }
}
