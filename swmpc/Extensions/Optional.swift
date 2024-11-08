//
//  Optional.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

extension Optional where Wrapped: Equatable {
    mutating func update(to value: Wrapped?) -> Bool {
        guard self != value else {
            return false
        }

        self = value
        return true
    }
}
