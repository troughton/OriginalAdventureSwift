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
    func renderWithShader(shader : Shader, hdrMaxIntensity : Float) {
        let material = self.material
        shader.applyMaterial(material);
        material.bindTextures();
        material.bindSamplers();
        
        self.render();
        
        material.unbindSamplers();
        material.unbindTextures();
    }
    
    /**
    * Renders these primitives using the currently bound material.
    */
    func render() {
        
        glBindVertexArray(self.vertexArrayObject)
        defer {
            glBindVertexArray(0)
        }
        
        var vertexBufferRef : GLint = 0
        glGetVertexAttribiv(0, GLenum(GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING), &vertexBufferRef)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), GLuint(vertexBufferRef))
        
        let vertexBufferBaseAddress = malloc(192)
        glGetBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, 192, vertexBufferBaseAddress)
        let vertexBuffer = UnsafeBufferPointer<Float>(start: UnsafePointer<Float>(vertexBufferBaseAddress), count: 192/4)
        var vertexBufferArray = [Float]()
        vertexBufferArray.appendContentsOf(vertexBuffer)
        print(vertexBufferArray)
        
        
        let indexBufferBaseAddress = malloc(4 * Int(elementCount))
        glGetBufferSubData(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0, 4 * Int(elementCount), indexBufferBaseAddress)
        let indexBuffer = UnsafeBufferPointer<UInt32>(start: UnsafePointer<UInt32>(indexBufferBaseAddress), count: Int(self.elementCount))
        var indexBufferArray = [UInt32]()
        indexBufferArray.appendContentsOf(indexBuffer)
        print(indexBufferArray)
        
        glDrawElements(primitiveType, elementCount, indexDataType, UnsafePointer<Void>().advancedBy(self.startIndex))
    }
}


class GLMesh: Mesh {
    var isEnabled = true
    
    private let primitives : [RenderCommand]; //The primitives that make up self mesh.
    
    let boundingBox : BoundingBox

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
    
    init(mdlMesh: MDLMesh) {
        
        self.boundingBox = BoundingBox(minPoint: mdlMesh.boundingBox.minBounds, maxPoint: mdlMesh.boundingBox.maxBounds)
        
        let mdlVertexBuffer = mdlMesh.vertexBuffers[0] as! MDLMeshBufferData
        let stride = mdlMesh.vertexDescriptor.layouts[0].stride
        
        var vertexBufferRef : GLuint = 0;
        glGenBuffers(1, &vertexBufferRef)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBufferRef)
        glBufferData(GLenum(GL_ARRAY_BUFFER), mdlVertexBuffer.length, mdlVertexBuffer.data.bytes, GLenum(GL_STATIC_DRAW))
        
        self.primitives = mdlMesh.submeshes.flatMap({ (mdlSubmesh) -> RenderCommand? in
            guard let mdlSubmesh = mdlSubmesh as? MDLSubmesh else { return nil }
            let material = (mdlSubmesh.material != nil) ? Material(fromModelIO: mdlSubmesh.material!) : Material.defaultMaterial

            var vao : GLuint = 0
            glGenVertexArrays(1, &vao)
            glBindVertexArray(vao)
            
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBufferRef)
            
            let indexBufferData = (mdlSubmesh.indexBuffer as! MDLMeshBufferData).data
            
            var indexBufferRef : GLuint = 0
            glGenBuffers(1, &indexBufferRef)
        
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBufferRef)
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBufferData.length, indexBufferData.bytes, GLenum(GL_STATIC_DRAW))
         
            var attributeIndex : GLuint = 0;
            for attribute in mdlMesh.vertexDescriptor.attributes {
                guard let attribute = attribute as? MDLVertexAttribute else { continue }
                guard attribute.format != MDLVertexFormat.Invalid else { continue }
                
                GLMesh.enableAttribute(attribute, atIndex: attributeIndex, withStride: stride)
                
                attributeIndex++;
            }
            
            let primitive = RenderCommand(vertexArrayObject: vao, primitiveType: mdlSubmesh.geometryType.glType, startIndex: 0, elementCount: GLsizei(mdlSubmesh.indexCount), indexDataType: mdlSubmesh.indexType.glType, material: material)
           
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
    
        for primitive in self.primitives {
            primitive.renderWithShader(shader, hdrMaxIntensity: hdrMaxIntensity)
        }
    }
}