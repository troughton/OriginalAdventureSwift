//
//  MaterialParser.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 12/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

/**
 * MaterialLibrary is an abstraction around a material library (.mtllib) file, and provides easy ways to access the materials in those files.
 */
struct MaterialLibrary {
    
    private static var _materialLibraries = [String : MaterialLibrary]();
    
    let materials : [String : Material]
    
    
    /**
    * Returns the material library with a particular name.
    * @param fileName The name of the mttlib file, including its extension
    * @return The material library, or null if it can't be found.
    */
    static func library(inDirectory directory: String? = nil, withName fileName: String) -> MaterialLibrary {
        let libraryName = (directory ?? "") + fileName;
        var library = _materialLibraries[libraryName];
        
        if library == nil {
            do {
                let libraryMap = try MTLParser.parseMaterialFile(inDirectory: directory, withName: fileName);
                library = MaterialLibrary(materials: libraryMap);
                _materialLibraries[libraryName] = library;
            } catch let error {
                assertionFailure("Error loading material library: \(error)");
            }
        }
        return library!;
    }
}