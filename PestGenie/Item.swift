//
//  Item.swift
//  PestGenie
//
//  Created by John Briggs on 8/5/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
