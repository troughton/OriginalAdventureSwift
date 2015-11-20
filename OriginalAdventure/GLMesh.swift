//
//  GLMesh.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import GLKit

typealias AttributeType = GLenum

/**
* A vertex array object that allows you to pass only certain attributes to the shader (i.e. just vertex positions).
*/
struct VertexArrayObject {
    let name : VertexArrays
    let attributeIndices : [GLuint]
}

/**
* A render command is a command that can be used to draw elements in OpenGL.
* It stores a material, along with the information required to draw the elements.
*/
struct RenderCommand {
    
    let vertexArrayObject : GLuint
    let primitiveType : GLenum
    let startIndex : Int
    let elementCount : GLsizei
    let indexDataType : GLenum
    let material : Material
    
    /**
    * Binds self command's material to the shader, and then renders the primitive.
    * @param shader The MaterialShader to set the material on.
    * @param hdrMaxIntensity The maximum light intensity in the scene, beyond which values will be clipped.
    */
    func renderWithShader(shader : Shader, materialOverride: Material?, hdrMaxIntensity : Float) {
        
        let material = materialOverride ?? self.material
        shader.setBuffer(material.toStruct(hdrMaxIntensity: hdrMaxIntensity), forProperty: .Material);
        
        material.bindSamplers();
        
        self.render();
        
        
        material.unbindSamplers();
        
    }
    
    /**
    * Renders these primitives using the currently bound material.
    */
    func render() {
        
        glBindVertexArray(self.vertexArrayObject)
        defer {
            glBindVertexArray(0)
        }
        glDrawElements(primitiveType, elementCount, indexDataType, UnsafePointer<Void>().advancedBy(self.startIndex))
    }
}


struct GLMesh: Mesh {
    var isEnabled = true
    var materialOverride : Material? = nil
    var textureRepeat = Vector3.One
    var parent : GameObject! = nil
    
    private let primitives : [RenderCommand]; //The primitives that make up self mesh.
    
    let boundingBox : BoundingBox
    let glkMesh : GLKMesh

    static func enableAttribute(attribute: MDLVertexAttribute, atIndex index: GLuint, withStride stride: Int) {
        glEnableVertexAttribArray(index)
        
        if (attribute.format.isNormalised) {
            glVertexAttribIPointer(index, attribute.format.numberOfComponents, attribute.format.glType,
                GLsizei(stride), UnsafePointer<Void>().advancedBy(attribute.offset));
        } else {
            glVertexAttribPointer(index, attribute.format.numberOfComponents,
                attribute.format.glType, attribute.format.isNormalised ? 1 : 0,
                GLsizei(stride), UnsafePointer<Void>().advancedBy(attribute.offset));
        }

    }
    
    init(glkMesh: GLKMesh, mdlMesh: MDLMesh, materialLibraries: [MaterialLibrary]) {
        
        self.boundingBox = BoundingBox(minPoint: mdlMesh.boundingBox.minBounds, maxPoint: mdlMesh.boundingBox.maxBounds)
        
        let vertexBuffer = glkMesh.vertexBuffers[0]
        let stride = mdlMesh.vertexDescriptor.layouts[0].stride
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer.glBufferName)
        
        self.glkMesh = glkMesh
        self.primitives = zip(glkMesh.submeshes, mdlMesh.submeshes).flatMap({ (glkSubmesh, mdlSubmesh) -> RenderCommand? in
            guard let mdlSubmesh = mdlSubmesh as? MDLSubmesh else { return nil }
            
            let material = (mdlSubmesh.material?.name).flatMap({ (materialName) -> Material? in
                for materialLibrary in materialLibraries {
                    if let material = materialLibrary.materials[materialName] {
                        return material
                    }
                }
                return nil
            }) ?? Material.defaultMaterial

            var vao : GLuint = 0
            glGenVertexArrays(1, &vao)
            glBindVertexArray(vao)
        
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), glkSubmesh.elementBuffer.glBufferName)
         
            var attributeIndex : GLuint = 0;
            for attribute in mdlMesh.vertexDescriptor.attributes {
                guard let attribute = attribute as? MDLVertexAttribute else { continue }
                guard attribute.format != MDLVertexFormat.Invalid else { continue }
                
                GLMesh.enableAttribute(attribute, atIndex: attributeIndex, withStride: stride)
                
                attributeIndex++;
            }
            
            let primitive = RenderCommand(vertexArrayObject: vao, primitiveType: glkSubmesh.mode, startIndex: glkSubmesh.elementBuffer.offset, elementCount: glkSubmesh.elementCount, indexDataType: glkSubmesh.type, material: material)
           
            glBindVertexArray(0)
            return primitive
        })
        
    }
    
    /**
    * Renders using the currently bound material.
    */
    func render() {
        
        for primitive in self.primitives {
            primitive.render()
        }
    }
    
    /**
    * Renders using each primitive's own material.
    * @param shader The shader on which to set the materials.
    * @param hdrMaxIntensity The maximum light intensity in the scene, beyond which values will be clipped.
    */
    func renderWithShader(shader: Shader, hdrMaxIntensity: Float) {
        shader.setUniform(self.textureRepeat.x, self.textureRepeat.y, forProperty: .TextureRepeat)

        for primitive in self.primitives {
            primitive.renderWithShader(shader, materialOverride: self.materialOverride, hdrMaxIntensity: hdrMaxIntensity)
        }
    }
}