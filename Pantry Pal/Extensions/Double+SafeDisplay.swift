//
//  Double+SafeDisplay.swift
//  Pantry Pal
//

import Foundation

extension Float {
    var safeForDisplay: Float {
        if isNaN || isInfinite || !isFinite {
            return 0.0
        }
        return self
    }
}

extension CGFloat {
    var safeForDisplay: CGFloat {
        if isNaN || isInfinite || !isFinite {
            return 0.0
        }
        return self
    }
}
