//
//  Shaders.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 5/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL.GL3

enum ShaderProperty : String {
    case Matrix4CameraToClip = "cameraToClipMatrix"
    case Matrix4ModelToCamera = "modelToCameraMatrix"
    case Matrix4NormalModelToCamera = "normalModelToCameraMatrix"
    case Matrix4ModelToClip = "modelToClipMatrix"
    case Matrix3ModelToCamera = "nodeToCamera3x3Matrix"
    case ScreenSize = "screenSize"
    case DepthRange = "depthRange"
    case HalfSizeNearPlane = "halfSizeNearPlane"
    
    case TextureRepeat = "textureRepeat"
    
    case LightBlock = "LightBlock"
    case Material = "Material"
    
    case Light = "Light"
    
    case AmbientColourMap = "ambientColourSampler"
    case DiffuseColourMap = "diffuseColourSampler"
    case SpecularColourMap = "specularColourSampler"
    case SpecularityMap = "specularitySampler"
    case NormalMap = "normalMapSampler"
    
    case DepthMap = "depthSampler"
}

class Shader {
    
    private static var _nextUniformBlockBinding : GLuint = 0;
    
    private let _glProgramRef : GLuint
    
    init(withVertexShader vertexShader: String, fragmentShader: String) {
        let shaders = [Shader.createShader(GLenum(GL_VERTEX_SHADER), shaderText: vertexShader), Shader.createShader(GLenum(GL_FRAGMENT_SHADER), shaderText: fragmentShader)]
        _glProgramRef = Shader.createProgram(shaders)
    }
    
    func useProgram() {

        glUseProgram(_glProgramRef)
    }
    
    func endUseProgram() {
        glUseProgram(0)
    }
    
    private lazy var uniformMappings : [String : GLint] = {
        var mappings = [String : GLint]()
        
        var numActiveUniforms : GLint = 0;
        glGetProgramiv(self._glProgramRef, GLenum(GL_ACTIVE_UNIFORMS), &numActiveUniforms);
        
        var maxUniformNameLength : GLint = 0;
        glGetProgramiv(self._glProgramRef, GLenum(GL_ACTIVE_UNIFORM_MAX_LENGTH), &maxUniformNameLength);
       
        var nameData = [GLchar]()
        nameData.reserveCapacity(Int(maxUniformNameLength))
        
        for uniform : GLuint in 0..<GLuint(numActiveUniforms) {
            var arraySize : GLint = 0
            var type : GLenum = 0
            var actualLength : GLsizei = 0
            glGetActiveUniform(self._glProgramRef, uniform, GLsizei(nameData.capacity), &actualLength, &arraySize, &type, &nameData)
            
            let name = String(CString: nameData, encoding: NSUTF8StringEncoding)
            mappings[name!] = glGetUniformLocation(self._glProgramRef, nameData)
        }
        
        var numBlocks : GLint = 0;
        glGetProgramiv(self._glProgramRef, GLenum(GL_ACTIVE_UNIFORM_BLOCKS), &numBlocks);
    
        for blockIndex : GLuint in 0..<GLuint(numBlocks) {
            var nameLength : GLint = 0;
            glGetActiveUniformBlockiv(self._glProgramRef, blockIndex, GLenum(GL_UNIFORM_BLOCK_NAME_LENGTH), &nameLength);
            
            var name = [GLchar]()
            name.reserveCapacity(Int(nameLength))
            glGetActiveUniformBlockName(self._glProgramRef, blockIndex, nameLength, nil, &name);
            
            let nameString = String(CString: name, encoding: NSUTF8StringEncoding)!
            
            var blockSize : GLint = 0
            glGetActiveUniformBlockiv(self._glProgramRef, blockIndex,  GLenum(GL_UNIFORM_BLOCK_DATA_SIZE), &blockSize);
            
            
            var bindingPoint = Shader._nextUniformBlockBinding++
            glUniformBlockBinding(self._glProgramRef, blockIndex, bindingPoint);

            var uniformBlockRef : GLuint = 0
            glGenBuffers(1, &uniformBlockRef);
            glBindBuffer(GLenum(GL_UNIFORM_BUFFER), uniformBlockRef);
            glBufferData(GLenum(GL_UNIFORM_BUFFER), GLsizeiptr(blockSize), nil, GLenum(GL_DYNAMIC_DRAW));
            
            //Bind the static buffer
            glBindBufferRange(GLenum(GL_UNIFORM_BUFFER), bindingPoint, uniformBlockRef, 0, GLsizeiptr(blockSize));
            
            mappings[nameString] = GLint(uniformBlockRef)
        }
        
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), 0);
        
        return mappings
    }()
    
    func addTextureMappings(textureMappings : [ShaderProperty : TextureUnit]) {
        self.useProgram()
        for (property, textureUnit) in textureMappings {
            self.setUniform(GLint(textureUnit.rawValue), forProperty: property)
        }
        self.endUseProgram()
    }
}

extension Shader {
    
    /**
    * Creates and links a shader program using the specified OpenGL shader objects.
    * @param shaderList A list of references to OpenGL shader objects.
    * @return A reference to the OpenGL program.
    */
    private static func createProgram(shaderList: [GLuint]) -> GLuint {
    
        let program = glCreateProgram();
    
        for shader in shaderList {
            glAttachShader(program, shader);
        }
    
        glLinkProgram(program);
        
        var status : GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        
        if (status == GL_FALSE) {
            var infoLogLength : GLint = 0
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &infoLogLength);
    
            let error = UnsafeMutablePointer<GLchar>(calloc(sizeof(GLchar), Int(infoLogLength)))
            
            glGetProgramInfoLog(program, infoLogLength, nil, error);
            
            let errorString = String(CString: error, encoding: NSUTF8StringEncoding)
            
            free(error)
            
            print("Linker failure: \(errorString!)");
        }
    
        for shader in shaderList {
            glDetachShader(program, shader);
        }
    
        return program;
    }
    
    /**
    * Creates and compiles a shader from the given text.
    * @param shaderType The type of the shader. Any of GL_VERTEX_SHADER, GL_GEOMETRY_SHADER, or GL_FRAGMENT_SHADER.
    * @param shaderText The text of the shader program.
    * @return A reference to the OpenGL shader object.
    */
    private static func createShader(shaderType : GLenum, shaderText : String) -> GLuint {
        let shader = glCreateShader(shaderType);
        let cString = shaderText.cStringUsingEncoding(NSUTF8StringEncoding)!
        let baseAddress = cString.withUnsafeBufferPointer { (shaderText) -> UnsafePointer<CChar> in
            return shaderText.baseAddress
        }
        let lengths = [GLint(cString.count)]
        let shaderTexts = [baseAddress]
        
        glShaderSource(shader, 1, shaderTexts, lengths);
        
        glCompileShader(shader);
    
        var status : GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status);
        if (status == GL_FALSE) {
            var infoLogLength : GLint = 0
            glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &infoLogLength);
    
            let error = UnsafeMutablePointer<GLchar>(calloc(sizeof(GLchar), Int(infoLogLength)))
            
            glGetShaderInfoLog(shader, infoLogLength, nil, error);
            
            let errorString = String(CString: error, encoding: NSUTF8StringEncoding)
            
            free(error)
    
            let strShaderType : String;
            switch (shaderType) {
                case GLenum(GL_VERTEX_SHADER): strShaderType = "vertex";
                case GLenum(GL_GEOMETRY_SHADER): strShaderType = "geometry";
                case GLenum(GL_FRAGMENT_SHADER): strShaderType = "fragment";
                default: strShaderType = "";
            }
            print("Compile failure in \(strShaderType) shader:\n\(errorString!)")
        }
        return shader;
    }
}

/** Matrix setting. */
extension Shader {
    
    func setMatrix(matrix : Matrix4, forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformMappings[property.rawValue] else {
            print("Warning: No uniform exists for the name \(property.rawValue)")
            return
        }
        
        var cmatrix = matrix.cmatrix
        let matrixPtr = withUnsafePointer(&cmatrix) { (cmatrix) -> UnsafePointer<Float> in
            return UnsafePointer<Float>(cmatrix)
        }
        
        glUniformMatrix4fv(uniformRef, 1, 0, matrixPtr)
    }
    
    func setMatrix(matrix : Matrix3, forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformMappings[property.rawValue] else {
            print("Warning: No uniform exists for the name \(property.rawValue)")
            return
        }
        
        let matrixArray = [matrix[0][0], matrix[0][1], matrix[0][2], matrix[1][0], matrix[1][1], matrix[1][2], matrix[2][0], matrix[2][1], matrix[2][2]]

        glUniformMatrix3fv(uniformRef, 1, 0, matrixArray)
    }
}

/** Uniform setting. */
extension Shader {
    
    func setUniform(values : Float..., forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformMappings[property.rawValue] else {
            assertionFailure("No uniform exists for the name \(property.rawValue)")
            return
        }
        
        switch values.count {
        case 1:
            glUniform1f(uniformRef, values[0])
        case 2:
            glUniform2f(uniformRef, values[0], values[1])
        case 3:
            glUniform3f(uniformRef, values[0], values[1], values[2])
        case 4:
            glUniform4f(uniformRef, values[0], values[1], values[2], values[3])
        default:
            assertionFailure("There is no uniform mapping for the values \(values) of length \(values.count)")
            break;
        }
    }
    
    func setUniform(values : GLint..., forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformMappings[property.rawValue] else {
            print("Warning: No uniform exists for the name \(property.rawValue)")
            return
        }
        
        switch values.count {
        case 1:
            glUniform1i(uniformRef, values[0])
        case 2:
            glUniform2i(uniformRef, values[0], values[1])
        case 3:
            glUniform3i(uniformRef, values[0], values[1], values[2])
        case 4:
            glUniform4i(uniformRef, values[0], values[1], values[2], values[3])
        default:
            assertionFailure("There is no uniform mapping for the values \(values) of length \(values.count)")
            break;
        }
    }
}

/** Materials. */
extension Shader {
    func setBuffer<T>(var buffer : T, forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformMappings[property.rawValue] else {
            print("Warning: No uniform exists for the name \(property.rawValue)")
            return
        }
        
        
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), GLuint(uniformRef));
        
        withUnsafePointer(&buffer) { (bufferPtr) -> Void in
            glBufferSubData(GLenum(GL_UNIFORM_BUFFER), 0, sizeof(T), bufferPtr);
        }
       
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), 0);
    }
}