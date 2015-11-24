//
//  MTLParser.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 12/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import GLKit

enum MTLPattern : String {
    case AmbientColour = "Ka"
    case DiffuseColour = "Kd"
    case SpecularColour = "Ks"
    case Specularity = "Ns"
    case Transparency = "d"
    case Transparency2 = "Tr"
    case IlluminationMode = "illum"
    case NewMaterial = "newmtl"
    case AmbientMap = "map_Ka"
    case DiffuseMap = "map_Kd"
    case SpecularColourMap = "map_Ks"
    case SpecularityMap = "map_Ns"
    case BumpMap = "map_bump"
    case BumpMap2 = "bump"
    case NormalMap = "map_normal"
    case NormalMap2 = "normal"
}

enum MTLParserError : ErrorType {
    case FileNotFound
    case InvalidFormat(String)
}

private func parseVector3(scanner : NSScanner) throws -> Vector3 {

    let possibleError = MTLParserError.InvalidFormat("A Vector3 requires three float components")
    var value : Float = 0.0
    
    var vector = [Float]()
    for _ in 0..<3 {
        guard scanner.scanFloat(&value) else { throw possibleError }
        vector.append(value)
    }
    return Vector3(vector)
}

private func parseTexture(scanner: NSScanner, directory: String?, useSRGB : Bool, unit: TextureUnit, isHeightMap : Bool = false) throws -> TextureSampler {
    
    var restOfLine : NSString?
    
    guard scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet(), intoString: &restOfLine) else { throw MTLParserError.InvalidFormat("A texture definition must be followed by a name.") }
    let args = restOfLine!.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    
    guard let name = args.last else {
        throw MTLParserError.InvalidFormat("A texture definition must be followed by a name.")
    }
    guard let path = NSBundle.mainBundle().pathForResource(name, ofType: nil, inDirectory: directory) else { throw MTLParserError.FileNotFound }
    
    let texture = try TextureLoader.loadTexture(atPath: path, useSRGB: useSRGB, isHeightMap: isHeightMap)
    let filter = MDLTextureFilter()
    filter.sWrapMode = .Repeat
    filter.tWrapMode = .Repeat
    
    let textureSampler = TextureSampler(texture: texture, textureUnit: unit, filter: filter)
    
    return textureSampler
}

class MTLParser {
    
    /**
    * Parses a material file and returns a map from strings to materials.
    * @param file The file to read.
    * @param directory The directory from which all referenced resources will be loaded relative to.
    * @return A map from strings to materials.
    * @throws FileNotFoundException if the file can't be found.
    */
    static func parseMaterialFile(inDirectory directory: String? = nil, withName fileName: String) throws -> [String : Material] {
        guard let path = NSBundle.mainBundle().pathForResource(fileName, ofType: nil, inDirectory: directory) else {
            throw MTLParserError.FileNotFound
        }
        let mtlFile = try String(contentsOfFile: path)
        
        return try MTLParser.parseMaterialFile(mtlFile, fromDirectory: directory);
    }
    
    private static func parseMaterialFile(string: String, fromDirectory directory: String?) throws -> [String : Material] {
        let lines = string.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        var materialMap = [String : Material]()
    
        var material : Material! = nil;
        var currentName : String?
        
        for line in lines {
            let scanner = NSScanner(string: line)
            var command : NSString?
            if scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceCharacterSet(), intoString: &command) {
                let command = command! as String
                if let pattern = MTLPattern(rawValue: command) {
                    if material == nil && pattern != .NewMaterial {
                        continue
                    }
                    
                    switch pattern {
                    case .NewMaterial:
                        
                        var materialName : NSString?
                        if scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceCharacterSet(), intoString: &materialName) {
                            if let currentName = currentName {
                                materialMap[currentName] = material
                            }
                            currentName = materialName as String?
                            
                            material = Material.defaultMaterial
                        }
                        
                    case .AmbientColour:
                        material.ambientColour = try parseVector3(scanner)
                        
                    case .DiffuseColour:
                        material.diffuseColour = try parseVector3(scanner)
                        
                    case .SpecularColour:
                        material.specularColour = try parseVector3(scanner)
                        
                    case .Specularity:
                        var specularity : Float = 0.0
                        guard scanner.scanFloat(&specularity) else { throw MTLParserError.InvalidFormat("Specularity requires a float value") }
                        material.specularity = Material.phongSpecularToGaussian(specularity)
                        
                    case .IlluminationMode:
                        var illuminationMode = 0
                        guard scanner.scanInteger(&illuminationMode) else { throw MTLParserError.InvalidFormat("Illumination mode requires an integer value") }
                        material.useAmbient = illuminationMode > 0
                        
                    case .Transparency: fallthrough
                    case .Transparency2:
                        var transparency : Float = 0.0
                        guard scanner.scanFloat(&transparency) else { throw MTLParserError.InvalidFormat("Transparency requires a float value") }
                        material.opacity = transparency
                        
                    case .AmbientMap:
                        material.ambientMap = try parseTexture(scanner, directory: directory, useSRGB: true, unit: .AmbientColourUnit)

                    case .DiffuseMap:
                        material.diffuseMap = try parseTexture(scanner, directory: directory, useSRGB: true, unit: .DiffuseColourUnit)
                        
                    case .SpecularColourMap: fallthrough
                    case .SpecularityMap:
                        material.specularityMap = try parseTexture(scanner, directory: directory, useSRGB: false, unit: .SpecularityUnit)
                        
                    case .BumpMap: fallthrough
                    case .BumpMap2:
                     //   material.normalMap = try parseTexture(scanner, directory: directory, useSRGB: false, isHeightMap: true)
                        print("Warning: bump maps are unsupported")
                        break
                        
                    case .NormalMap: fallthrough
                    case .NormalMap2:
                        material.normalMap = try parseTexture(scanner, directory: directory, useSRGB: false, unit: .NormalMapUnit)
                    }
                }
            }
        }

        if let currentName = currentName {
            materialMap[currentName] = material
        }
    
        return materialMap;
    }
}
