//
//  Optional+Update.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

extension Optional where Wrapped: Equatable {
    /// Updates the value of the optional if it is different from the new value.
    ///
    /// - Parameter value: The new value to compare with the current value.
    /// - Returns: A boolean indicating whether the value was updated.
    mutating func update(to value: Wrapped?) -> Bool {
        guard self != value else {
            return false
        }

        self = value
        return true
    }
}
