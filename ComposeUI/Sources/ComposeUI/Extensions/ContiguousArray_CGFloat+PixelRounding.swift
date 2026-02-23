//
//  ContiguousArray_CGFloat+PixelRounding.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/23/23.
//

import CoreGraphics

extension ContiguousArray where Element == CGFloat {

    /// Rounding an array of sizes to nearest pixel.
    ///
    /// This method is useful to round frames to the nearest displayable pixel value to avoid rendering artifacts.
    ///
    /// - Parameter scaleFactor: The screen scale factor.
    /// - Returns: A corrected sizes which match the pixel boundary.
    func rounded(scaleFactor: CGFloat) -> Self {
        guard !isEmpty else {
            return self
        }

        if count == 1 {
            return self
        }

        let pixelSize: CGFloat = 1 / scaleFactor
        var roundedSizes: ContiguousArray<CGFloat> = []
        roundedSizes.reserveCapacity(count)
        var totalError: CGFloat = 0.0

        for original in self {
            // if accumulative error exceeds pixel size, should apply a correction to the next item
            let correction: CGFloat
            if abs(totalError) >= pixelSize {
                correction = totalError > 0 ? -pixelSize : pixelSize
                totalError += correction
            } else {
                correction = 0
            }

            let rounded = original.round(nearest: pixelSize)
            totalError += (rounded - original)

            roundedSizes.append(rounded + correction)
        }

        if abs(totalError) > 0 {
            roundedSizes[roundedSizes.count - 1] -= totalError
            if roundedSizes[roundedSizes.count - 1] < 0 {
                // the last element can't hold the error correction
                // to avoid return negative sizes, return self
                return self
            }
        }

        return roundedSizes
    }
}
