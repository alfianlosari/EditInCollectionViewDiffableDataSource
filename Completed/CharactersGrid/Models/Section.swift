//
//  Section.swift
//  CharactersGrid
//
//  Created by Alfian Losari on 9/22/20.
//

import Foundation

struct Section: Hashable {
    let category: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(category)
    }
    
    func headerTitleText(count: Int = 0) -> String {
        guard count > 0 else {
            return category.uppercased()
        }
        return "\(category) (\(count))".uppercased()
    }
    
}
