//
//  Character.swift
//  CharactersGrid
//
//  Created by Alfian Losari on 9/22/20.
//

import Foundation

struct Character: Codable, Hashable {
    
    let id: String
    let name: String
    let imageName: String
    let category: String
    let job: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageName
        case category
        case job
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.imageName == rhs.imageName &&
            lhs.category == rhs.category &&
            lhs.job == rhs.job
    }
    
}

