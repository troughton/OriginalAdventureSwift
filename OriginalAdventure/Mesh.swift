//
//  Mesh.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 12/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import GLKit

protocol Mesh : Enableable {
    
    var worldSpaceTransform : Matrix4 { get set }
    var boundingBox : BoundingBox { get }
    var materialOverride : Material? { get set }
    var textureRepeat : Vector3 { get set }
}

var _loadedMeshes = [String : [Mesh]]()

extension Mesh {
    
    static func loadMaterialsFromOBJAtPath(objPath: String, containingDirectory directory: String?) throws -> [MaterialLibrary] {
        
        var libraries = [MaterialLibrary]()
        
        let objFile = try String(contentsOfFile: objPath)
        
        let scanner = NSScanner(string: objFile)
        
        while scanner.scanUpToString("mtllib", intoString: nil) {
            scanner.scanString("mtllib", intoString: nil)
        
            var fileName : NSString? = nil
            if scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &fileName) {
                libraries.append(MaterialLibrary.library(inDirectory: directory, withName: fileName as! String))
            }
        }
        return libraries
    }
}