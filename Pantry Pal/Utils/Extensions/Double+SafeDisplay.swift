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
    
    var safeForCoreGraphics: Float {
        return safeForDisplay
    }
}

extension CGFloat {
    var safeForDisplay: CGFloat {
        if isNaN || isInfinite || !isFinite {
            return 0.0
        }
        return self
    }
    
    var safeForCoreGraphics: CGFloat {
        return safeForDisplay
    }
}

extension Double {
    var safeForCoreGraphics: Double {
        if isNaN || isInfinite || !isFinite {
            return 0.0
        }
        return self
    }
}
