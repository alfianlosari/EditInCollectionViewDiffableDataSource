//
//  Universe.swift
//  CharactersGrid
//
//  Created by Alfian Losari on 9/22/20.
//

import Foundation

typealias SectionCharactersTuple = (section: Section, characters: [Character])

enum Universe: CaseIterable {
    case ff7r
    case marvel
    case starwars
    
    var stubs: [Character] {
        switch self {
        case .ff7r:
            return Character.ff7Stubs
        case .marvel:
            return Character.marvelStubs
        case .starwars:
            return Character.starWarsStubs
        }
    }
    
    var sectionedStubs: [SectionCharactersTuple] {
        let stubs = self.stubs
        var categoryCharactersDict = [String: [Character]]()
        stubs.forEach { (character) in
            let category = character.category
            if let characters = categoryCharactersDict[category] {
                categoryCharactersDict[category] = characters + [character]
            } else {
                categoryCharactersDict[category] = [character]
            }
        }
        let sectionedStubs = categoryCharactersDict.map { (category, items) -> (Section, [Character]) in
            (Section(category: category), items)
        }.sorted { $0.0.category < $1.0.category }
        return sectionedStubs
    }
    
    var title: String {
        switch self {
        case .ff7r:
            return "FF7R"
        case .marvel:
            return "Marvel"
        case .starwars:
            return "Star Wars"
        }
    }
}
