//
//  Texture.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 12/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import GLKit

class TextureLoader {
    
    enum TextureLoaderError : ErrorType {
        case UnableToLoadImage
        case UnableToConvertToBitmap
    }
    
    private class func grayscaleAtLocation(pixelBuffer pixelBuffer: UnsafeMutableBufferPointer<UInt8>, wrap: Bool, var x: Int, var y: Int, width: Int, height: Int, componentsPerPixel: Int) -> Double {
    
        if (x < 0) { x = wrap ? (x + width) : 0; }
        if (y < 0) { y = wrap ? (y + height) : 0; }
        if (x >= width) { x = wrap ? (x - width) : (width - 1); }
        if (y >= height) { y = wrap ? (y - height) : (height - 1); }
        let idx = x + y * width;
        return (Double(pixelBuffer[idx * componentsPerPixel + 0]) + Double(pixelBuffer[idx * componentsPerPixel + 1]) + Double(pixelBuffer[idx * componentsPerPixel + 2])) / (256.0 * 3.0);
    }
    
    /**
    * Generates a normal map from a height map.
    * Adapted from http://gamedev.stackexchange.com/questions/80940/how-to-create-normal-map-from-bump-map-in-runtime#81934
    * @param heightMap The height-map image.
    * @param width The width of the image.
    * @param height The height of the image.
    * @return A RGB(A) format image containing the new normal map.
    */
    class func generateNormalMap(heightMap: UnsafeMutableBufferPointer<UInt8>, width: Int, height: Int, componentsPerPixel: Int, extrusion : Double, wrap: Bool) -> UnsafeMutableBufferPointer<UInt8> {
    
        let outputImageBaseAddress = malloc(heightMap.count)
        let outputImage = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(outputImageBaseAddress), count: heightMap.count)
        
    
        for y in 0..<height {
            for x in 0..<width {
                let up = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x, y: y - 1, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let down = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x, y: y + 1, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let left = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x - 1, y: y, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let right = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x + 1, y: y, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let upleft = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x - 1, y: y - 1, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let upright = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x + 1, y: y - 1, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let downleft = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x - 1, y: y + 1, width: width, height: height, componentsPerPixel: componentsPerPixel);
                let downright = grayscaleAtLocation(pixelBuffer: heightMap, wrap: wrap, x: x + 1, y: y + 1, width: width, height: height, componentsPerPixel: componentsPerPixel);
    
                let vert = (down - up) * 2.0 + downright + downleft - upright - upleft;
                let horiz = (right - left) * 2.0 + upright + downright - upleft - downleft;
                let depth = 1.0 / extrusion;
                let scale = 127.0 / sqrt(vert * vert + horiz * horiz + depth*depth);
    
                let r = UInt8(128 - horiz * scale);
                let g = UInt8(128 + vert * scale);
                let b = UInt8(128 + depth * scale);
    
                let idx = x + y * width;
                outputImage[idx * componentsPerPixel + 0] = r;
                outputImage[idx * componentsPerPixel + 1] = g;
                outputImage[idx * componentsPerPixel + 2] = b;
    
                if (componentsPerPixel == 4) { outputImage[idx * 4 + 3] = 255; };
            }
        }
    
        return outputImage;
    }
    
    private class func loadHeightMap(atPath path: String, useSRGB: Bool) throws -> GLKTextureInfo {
        var width : Int32 = 0
        var height : Int32 = 0
        var numComponents : Int32 = 0

        let image = path.withCString { (path) -> UnsafeMutablePointer<UInt8> in
            return UnsafeMutablePointer<UInt8>() //stbi_load(path, &width, &height, &numComponents, 0)
        }
        let imageBuffer = UnsafeMutableBufferPointer<UInt8>(start: image, count: Int(width * height * numComponents));
        let normalMap = generateNormalMap(imageBuffer, width: Int(width), height: Int(height), componentsPerPixel: Int(numComponents), extrusion: 2.0, wrap: true)
        free(imageBuffer.baseAddress)
        
        var planes = [normalMap.baseAddress]
        var bitmapNormal : NSBitmapImageRep?
        
        planes.withUnsafeMutableBufferPointer { (planes) -> Void in
            bitmapNormal = NSBitmapImageRep(bitmapDataPlanes: planes.baseAddress, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8, samplesPerPixel: Int(numComponents), hasAlpha: numComponents == 4, isPlanar: false, colorSpaceName: NSDeviceRGBColorSpace, bytesPerRow: 0, bitsPerPixel: 0)
            return
        }
        
        return try GLKTextureLoader.textureWithCGImage(bitmapNormal!.CGImage!, options: [GLKTextureLoaderGenerateMipmaps : true, GLKTextureLoaderSRGB: useSRGB, GLKTextureLoaderOriginBottomLeft: true])
    }
    
    
    class func loadTexture(atPath path: String, useSRGB : Bool, isHeightMap : Bool = false) throws -> GLKTextureInfo {
        if isHeightMap {
            return try loadHeightMap(atPath: path, useSRGB: useSRGB)
        }
    
        return try GLKTextureLoader.textureWithContentsOfFile(path, options: [GLKTextureLoaderGenerateMipmaps : true, GLKTextureLoaderSRGB: useSRGB, GLKTextureLoaderOriginBottomLeft: true])
    }
}
