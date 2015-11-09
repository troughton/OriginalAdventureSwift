//
//  GLMesh.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL.GL3
import GLKit

typealias AttributeType = GLenum

extension AttributeType {
    var isNormalised : Bool { return true }
    var sizeInBytes : Int { return 0 }
    
    func writeToBuffer<T>(buffer : UnsafePointer<Void>, dataArray : [T], componentsPerStride : Int, offset : GLsizei, stride : GLsizei) {
        
    }
}

/**
* An attribute is an abstraction around an array of primitives, providing extra information that is required for OpenGL.
*/
struct Attribute<T> {
    let attributeIndex : GLuint
    let attributeType : AttributeType;
    let numberOfComponents : Int;
    let isIntegral : Bool;
    let data : [T];
    
    init(attributeIndex : GLuint, numberOfComponents : Int, attributeType : AttributeType, isIntegral : Bool, data : [T]) {
        self.attributeIndex = attributeIndex;
        
        assert(0 < numberOfComponents && numberOfComponents < 5, "Attribute size must be between 1 and 4.");
        
        self.numberOfComponents = numberOfComponents;
        self.attributeType = attributeType;
        
        self.isIntegral = isIntegral;
        
        self.data = data;
        
        assert(!(isIntegral && self.attributeType.isNormalised), "Attribute cannot be both 'integral' and a normalized 'type'.")
        
        assert(!data.isEmpty, "The attribute must have an array of values.")
        
        assert(data.count % self.numberOfComponents == 0, "The attribute's data must be a multiple of its size in elements.")
    }
    
    var sizeInBytes : Int {
        return self.data.count * self.attributeType.sizeInBytes
    }
    
    var sizePerElement : Int {
        return self.numberOfComponents * self.attributeType.sizeInBytes
    }
    
    func fillBoundBufferObject(buffer: UnsafePointer<Void>, offset: GLsizei, stride: GLsizei) {
        self.attributeType.writeToBuffer(buffer, dataArray: self.data, componentsPerStride: self.numberOfComponents, offset: offset, stride: stride);
    }
    
    
    func setupAttributeArray(var offset offset : GLsizei, stride: GLsizei) {
        glEnableVertexAttribArray(self.attributeIndex);
        withUnsafePointer(&offset, { (offset) -> Void in
            if (self.isIntegral) {
                glVertexAttribIPointer(self.attributeIndex, GLint(self.numberOfComponents), self.attributeType,
                    stride, offset);
            } else {
                glVertexAttribPointer(self.attributeIndex, GLint(self.numberOfComponents),
                    self.attributeType, self.attributeType.isNormalised ? 1 : 0,
                    stride, offset);
            }
        })
    }
}

/**
* IndexData defines a list of indices.
* @param <U> The type of data that the indices are.
*/
struct IndexData<U> {
    let attributeType : AttributeType;
    let data : [U];
    
    var sizeInBytes : Int {
        return data.count * attributeType.sizeInBytes;
    }
    
    func fillBoundBufferObject(offset : Int) {
        let buffer = malloc(self.sizeInBytes)
        self.attributeType.writeToBuffer(buffer, dataArray: self.data, componentsPerStride: self.data.count, offset: 0, stride: 0);
        glBufferSubData(GLenum(GL_ELEMENT_ARRAY_BUFFER), offset, self.sizeInBytes, buffer);
        free(buffer)
    }
}

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
enum RenderCommand {
    
    case NonIndexed(GLenum, GLint, GLsizei, Material)
    case IndexedUninitialised(GLenum, Material)
    case Indexed(GLuint, GLenum, GLsizei, GLenum, GLint, Material)
    
    var material : Material {
        switch self {
        case .NonIndexed(_, _, _, let material):
            return material
        case .IndexedUninitialised(_, let material):
            return material
        case .Indexed(_, _, _, _, _, let material):
            return material
        }
    }
    
    /**
    * Constructs a new non-indexed command.
    * @param primitiveType GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT, or GL_UNSIGNED_INT
    * @param startIndex The start index for drawing the array.
    * @param material The material to use when performing self render command.
    */
    init(nonIndexedCommandWithPrimitiveType primitiveType: GLenum, startIndex : GLint, elementCount : GLsizei, material : Material) {
        assert(startIndex >= 0, "The array start index must be 0 or greater")
        assert(elementCount > 0, "The array count must be 1 or greater")
        self = .NonIndexed(primitiveType, startIndex, elementCount, material)
    }
    
    /**
    * Constructs a new indexed command. The _startIndex, _elementCount, _indexDataType, and _primitiveRestart fields need to be filled in before use.
    * @param primitiveType GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT, or GL_UNSIGNED_INT
    * @param material The material to use when performing self render command.
    */
    init(indexedCommandWithPrimitiveType primitiveType : GLenum, material : Material) {
        self = .IndexedUninitialised(primitiveType, material)
    }
    
    mutating func initialise(indexBuffer indexBuffer: GLuint, startIndex : GLint, elementCount: GLsizei, indexDataType: GLenum) {
        switch self {
        case let .IndexedUninitialised(primitiveType, material):
            self = RenderCommand.Indexed(indexBuffer, primitiveType, elementCount, indexDataType, startIndex, material)
        default:
            assert(true, "Cannot initialise anything except for an uninitialised indexed RenderCommand")
        }
    }
    
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
        
        var error = glGetError()
        if error != 0 {
            assertionFailure("OpenGL error \(error)")
        }
        switch self {
        case .Indexed(let indexBuffer, let primitiveType, let elementCount, let indexDataType, var startIndex, _):
            
            error = glGetError()
            if error != 0 {
                assertionFailure("OpenGL error \(error) for index buffer \(indexBuffer)")
            }
            
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
            
            error = glGetError()
            if error != 0 {
                assertionFailure("OpenGL error \(error) for index buffer \(indexBuffer)")
            }
            
            withUnsafePointer(&startIndex, { (startIndex) -> Void in
                glDrawElements(primitiveType, elementCount, indexDataType, startIndex)
            })
            
            error = glGetError()
            if error != 0 {
                assertionFailure("OpenGL error \(error)")
            }
            
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        case let .NonIndexed(primitiveType, startIndex, elementCount, _):
            glDrawArrays(primitiveType, startIndex, elementCount)
        default:
            break;
        }
    }
}


class GLMesh<A, I> : Mesh {
    var isEnabled = true
    
    private lazy var _vertexArrayObjectRef : GLuint = {
        //Create the "Everything" VAO.
        var vao : GLuint = 0
        withUnsafeMutablePointer(&vao) { (vao) -> Void in
            glGenVertexArrays(1, vao);
        }
        return vao
    }()
    
    private var primitives : [RenderCommand]; //The primitives that make up self mesh.
    private var namedVAOs = [VertexArrays : GLuint]()
    
    init(mesh: GLKMesh, asset: MDLMesh) {
        
        self.primitives = mesh.submeshes.map({ (submesh) -> RenderCommand in
            let material = asset.submeshes
                .filter({ (mdlSubmesh) -> Bool in
                    mdlSubmesh.name == submesh.name
                })
                .flatMap({ (submesh) -> MDLMaterial? in
                    submesh.material
                })
                .map({ (mdlMaterial) -> Material in
                    Material(fromModelIO: mdlMaterial)
                })
                .first ?? Material.defaultMaterial
            
            var primitive = RenderCommand(indexedCommandWithPrimitiveType: submesh.mode, material: material)
            primitive.initialise(indexBuffer: submesh.elementBuffer.glBufferName, startIndex: GLint(submesh.elementBuffer.offset), elementCount: submesh.elementCount, indexDataType: submesh.type)
            return primitive
        })
        
        glBindVertexArray(_vertexArrayObjectRef)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), mesh.vertexBuffers[0].glBufferName)
        
        let stride = mesh.vertexDescriptor.layouts[0].stride
        
        var attributeIndex : GLuint = 0;
        for attribute in mesh.vertexDescriptor.attributes {
            guard let attribute = attribute as? MDLVertexAttribute else { continue }
            guard attribute.format != MDLVertexFormat.Invalid else { continue }
            
            glEnableVertexAttribArray(attributeIndex)
            
            if (attribute.format.isNormalised) {
                glVertexAttribIPointer(attributeIndex, attribute.format.numberOfComponents, attribute.format.glType,
                    GLsizei(stride), &attribute.offset);
            } else {
                glVertexAttribPointer(attributeIndex, attribute.format.numberOfComponents,
                    attribute.format.glType, attribute.format.isNormalised ? 1 : 0,
                    GLsizei(stride), &attribute.offset);
            }
            
            let error3 = glGetError()
            if error3 != 0 {
                assertionFailure("OpenGL error \(error3)")
            }
            
            attributeIndex++;
        }
        
    }
    
    init(attributes : [Attribute<A>], indexData : [IndexData<I>], namedVAOList : [VertexArrayObject], primitives : [RenderCommand]) {
        
        self.primitives = primitives;
        
        //Figure out how big of a buffer object for the attribute data we need.
        var attribStartLocs = [GLsizei]()
        var attributeStartLocation : GLsizei = 0
        
        var numVertices : GLsizei = 0
        for i in 0..<attributes.count {
            //Make sure that the buffer is a workable number of bytes (multiple of size of Vector4).
            attributeStartLocation = attributeStartLocation % 16 != 0 ?
                (attributeStartLocation + (16 - attributeStartLocation % 16)) : attributeStartLocation;
            
            attribStartLocs[i] = attributeStartLocation;
            
            let attribute = attributes[i];
            attributeStartLocation += attribute.sizePerElement;
            
            let vertices = GLsizei(attribute.data.count/attribute.numberOfComponents)
            assert(numVertices == 0 || numVertices == vertices, "Some of the attribute arrays have different numbers of vertices.")
            numVertices = vertices
        }
        
        attributeStartLocation = attributeStartLocation % 16 != 0 ?
            (attributeStartLocation + (16 - attributeStartLocation % 16)) : attributeStartLocation;
        let attributeBufferSize = GLsizeiptr(attributeStartLocation) * GLsizeiptr(numVertices);
        let stride = attributeStartLocation;
    
        
        glBindVertexArray(_vertexArrayObjectRef);
        
        //Create the buffer object.
        var attributeArraysBufferRef : GLuint = 0
        withUnsafeMutablePointer(&attributeArraysBufferRef, { (attributeArraysBufferRef) -> Void in
            glGenBuffers(1, attributeArraysBufferRef)
        })
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), attributeArraysBufferRef);
        glBufferData(GLenum(GL_ARRAY_BUFFER), attributeBufferSize, nil, GLenum(GL_STATIC_DRAW));
        
        let attributesBuffer = malloc(attributeBufferSize)
        
        //Fill in our data
        for (attribute, startLocation) in zip(attributes, attribStartLocs) {
            attribute.fillBoundBufferObject(attributesBuffer, offset: startLocation, stride: stride);
        }
        
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, attributeBufferSize, attributesBuffer);
        
        free(attributesBuffer)
        
        //Set up the attribute arrays.
        for (attribute, startLocation) in zip(attributes, attribStartLocs) {
            attribute.setupAttributeArray(offset: startLocation, stride: stride)
        }
        
        var extraVAOs = [GLuint]()
        extraVAOs.reserveCapacity(namedVAOList.count)
        extraVAOs.withUnsafeMutableBufferPointer { (inout vaosBuffer : UnsafeMutableBufferPointer<GLuint>) -> Void in
            glGenVertexArrays(GLsizei(namedVAOList.count), vaosBuffer.baseAddress)
        }
        
        //Fill the named VAOs.
        for (namedVAO, glArray) in zip(namedVAOList, extraVAOs) {
            glBindVertexArray(glArray);
            
            for attributeIndex in namedVAO.attributeIndices {
                var attributeOffset = -1
                for count in 0..<attributes.count {
                    if attributes[count].attributeIndex == attributeIndex {
                        attributeOffset = count;
                        break;
                    }
                }
                let attribute = attributes[attributeOffset]
                attribute.setupAttributeArray(offset: attribStartLocs[attributeOffset], stride: stride)
            }
            namedVAOs[namedVAO.name] = glArray
        }
        
        glBindVertexArray(0);
        
        //Get the size of our index buffer data.
        var indexBufferSize : GLsizeiptr = 0;
        var indexStartLocs = [GLsizeiptr]()
        
        for i in 0..<indexData.count {
            indexBufferSize = indexBufferSize % 16 != 0 ?
                (indexBufferSize + (16 - indexBufferSize % 16)) : indexBufferSize; //Again, make sure we're aligned to boundaries.
            
            indexStartLocs[i] = indexBufferSize;
            let data = indexData[i];
            
            indexBufferSize += data.sizeInBytes;
        }
        
        //Create the index buffer object.
        if (indexBufferSize > 0) {
            glBindVertexArray(_vertexArrayObjectRef);
            
            var indexBufferRef : GLuint = 0
            withUnsafeMutablePointer(&indexBufferRef, { (indexBufferRef) -> Void in
                glGenBuffers(1, indexBufferRef);
            })
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBufferRef);
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBufferSize, nil, GLenum(GL_STATIC_DRAW))
            
            for (data, startLocation) in zip(indexData, indexStartLocs) {
                data.fillBoundBufferObject(startLocation)
            }
            
            //Fill in indexed rendering commands.
            var currentIndex = 0;
            for (index, _) in self.primitives.enumerate() {
                var primitive = self.primitives[index]
                switch primitive {
                case .IndexedUninitialised(_, _):
                    let indexDatum = indexData[currentIndex]
                    primitive.initialise(indexBuffer: indexBufferRef, startIndex: GLint(indexStartLocs[currentIndex]), elementCount: GLsizei(indexDatum.data.count), indexDataType: indexDatum.attributeType)
                default:
                    break
                }
                
                self.primitives[index] = primitive
                
                currentIndex++;
            }
            
            for vao in namedVAOs.values {
                glBindVertexArray(vao)
                glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBufferRef)
            }
            
            glBindVertexArray(0);
        }
    }
    
    /**
    * Renders using the currently bound material.
    */
    func render() {
        
        assert(_vertexArrayObjectRef != 0, "The vertex array should not be 0")
        
        glBindVertexArray(_vertexArrayObjectRef);
        
        for primitive in self.primitives {
            primitive.render()
        }
        glBindVertexArray(0)
    }
    
    /**
    * Renders using each primitive's own material.
    * @param shader The shader on which to set the materials.
    * @param hdrMaxIntensity The maximum light intensity in the scene, beyond which values will be clipped.
    */
    func renderWithShader(shader: Shader, hdrMaxIntensity: Float) {
        assert(_vertexArrayObjectRef != 0, "The vertex array should not be 0")
        
        glBindVertexArray(_vertexArrayObjectRef);
    
        for primitive in self.primitives {
            primitive.renderWithShader(shader, hdrMaxIntensity: hdrMaxIntensity)
        }
        
        glBindVertexArray(0);
    }
    
    /**
    * Renders using only the named vertex array objects.
    * @param vertexArrayObject An enum value specifying which vertex arrays should be passed to the vertex shader for rendering.
    */
    func renderWithVertexArrays(vertexArray : VertexArrays) {
        guard let vao = self.namedVAOs[vertexArray] else {
            assertionFailure("There is no named vertex array object for the vertex array \(vertexArray)")
            return
        }
        
        glBindVertexArray(vao);
    
        for primitive in self.primitives {
            primitive.render()
        }
        
        glBindVertexArray(0);
    }
    
    var boundingBox : BoundingBox? {
        return nil
    }
}