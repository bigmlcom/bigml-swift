//
//  ChiSquare.swift
//  BigMLKitConnector
//
//  Created by sergio on 25/12/15.
//  Copyright © 2015 BigML Inc. All rights reserved.
//

import Foundation

public func chi2ppf(_ p : Double, _ n : Int) -> Double {
    
    let p = 1 - p
    var v = 0.5
    var dv = 0.5
    var x = 0.0
    while (dv > 1e-15) {
        x = 1/v - 1
        dv /= 2
        if chi2(x, n) > p {
            v -= dv
        } else {
            v += dv
        }
    }
    return x
}

func chi2ppm(_ conf : Double, fails : Double, total : Double) -> Double {
    
    let e5 = conf / 100.0
    let f5 = fails
    let g5 = total
    let i5 = chi2ppf(1 - e5, Int(2.0 * (f5 + 1))) * 1000000.0 / (2 * g5)
    return round(i5)
}

public func norm(_ z : Double) -> Double {
    let q = z * z
    if (abs(z) > 7.0) {
        let c = (1.0 - 1.0/q + 3.0 / (q * q))
        return c * exp(-q/2.0) / (abs(z) * M_PI/2);
    }
    return chi2(q, 1)
}

public func chi2(_ x : Double, _ n : Int) -> Double {

    if (x > 1000.0 || n > 1000) {
        let n = Double(n)
        let c = (pow(x / n, 1.0/3.0) + 2.0 / (9*n) - 1)
        let q = norm(c / sqrt(2.0/(9.0 * n))) / 2.0
        if (x > n) {
            return q
        } else {
            return 1.0 - q
        }
    }

    var p = exp(-0.5 * x)
    if n % 2 == 1 {
        p *= sqrt(2.0 * x / M_PI)
    }
    var k = n
    while k >= 2 {
        p *= x / Double(k) 
        k -= 2
    }
    var t = p
    var a = n
    while t > 1e-15 * p {
        a += 2
        t *= x / Double(a) 
        p += t
    }
    return 1 - p
}
