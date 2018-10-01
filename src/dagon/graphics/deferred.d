/*
Copyright (c) 2018 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.graphics.deferred;

import std.stdio;
import std.conv;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.image.color;

import derelict.opengl;

import dagon.core.ownership;
import dagon.core.interfaces;
import dagon.graphics.rc;
import dagon.graphics.gbuffer;
import dagon.graphics.shadow;
import dagon.graphics.light;
import dagon.graphics.screensurface;
import dagon.graphics.shapes;
import dagon.graphics.shaders.environmentpass;

class DeferredEnvironmentPass: Owner
{
	ScreenSurface surface;
    EnvironmentPassShader shader;
    GBuffer gbuffer;
    CascadedShadowMap shadowMap;

    this(GBuffer gbuffer, CascadedShadowMap shadowMap, Owner o)
    {
        super(o);
        
        this.gbuffer = gbuffer;
        this.shadowMap = shadowMap;
		this.surface = New!ScreenSurface(this);
        this.shader = New!EnvironmentPassShader(gbuffer, shadowMap, this);
    }
    
    void render(RenderingContext* rc2d, RenderingContext* rc3d)
    {
        shader.bind(rc2d, rc3d);
		surface.render(rc2d);
        shader.unbind(rc2d, rc3d);
    }
}

class DeferredLightPass: Owner
{
    Vector2f[4] vertices;
    Vector2f[4] texcoords;
    uint[3][2] indices;
    
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint tbo = 0;
    GLuint eao = 0;
    
    GLenum lightPassShaderVert;
    GLenum lightPassShaderFrag;
    GLenum lightPassShaderProgram;
    
    private string lightPassVsText = import("LightPass.vs");    
    private string lightPassFsText = import("LightPass.fs");
    
    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    
    GLint colorBufferLoc;
    GLint rmsBufferLoc;
    GLint positionBufferLoc;
    GLint normalBufferLoc;
    
    GLint viewportSizeLoc;
    
    GLint lightPositionLoc;
    GLint lightRadiusLoc;
    GLint lightAreaRadiusLoc;
    GLint lightColorLoc;
    GLint lightEnergyLoc;
    
    GBuffer gbuffer;
    LightManager lightManager;
    ShapeSphere lightVolume;

    this(GBuffer gbuffer, LightManager lightManager, Owner o)
    {
        super(o);
        
        this.gbuffer = gbuffer;
        this.lightManager = lightManager;
        this.lightVolume = New!ShapeSphere(1.0f, 8, 4, false, this);
        
        vertices[0] = Vector2f(0, 0);
        vertices[1] = Vector2f(0, 1);
        vertices[2] = Vector2f(1, 0);
        vertices[3] = Vector2f(1, 1);
        
        texcoords[0] = Vector2f(0, 1);
        texcoords[1] = Vector2f(0, 0);
        texcoords[2] = Vector2f(1, 1);
        texcoords[3] = Vector2f(1, 0);
        
        indices[0][0] = 0;
        indices[0][1] = 1;
        indices[0][2] = 2;
        
        indices[1][0] = 2;
        indices[1][1] = 1;
        indices[1][2] = 3;
        
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof * 2, vertices.ptr, GL_STATIC_DRAW); 

        glGenBuffers(1, &tbo);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glBufferData(GL_ARRAY_BUFFER, texcoords.length * float.sizeof * 2, texcoords.ptr, GL_STATIC_DRAW);

        glGenBuffers(1, &eao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * uint.sizeof * 3, indices.ptr, GL_STATIC_DRAW);

        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
    
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
    
        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
        
        const(char*)pvs = lightPassVsText.ptr;
        const(char*)pfs = lightPassFsText.ptr;
        
        char[1000] infobuffer = 0;
        int infobufferlen = 0;

        lightPassShaderVert = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(lightPassShaderVert, 1, &pvs, null);
        glCompileShader(lightPassShaderVert);
        GLint success = 0;
        glGetShaderiv(lightPassShaderVert, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            GLint logSize = 0;
            glGetShaderiv(lightPassShaderVert, GL_INFO_LOG_LENGTH, &logSize);
            glGetShaderInfoLog(lightPassShaderVert, 999, &logSize, infobuffer.ptr);
            writeln("Error in vertex shader:");
            writeln(infobuffer[0..logSize]);
        }

        lightPassShaderFrag = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(lightPassShaderFrag, 1, &pfs, null);
        glCompileShader(lightPassShaderFrag);
        success = 0;
        glGetShaderiv(lightPassShaderFrag, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            GLint logSize = 0;
            glGetShaderiv(lightPassShaderFrag, GL_INFO_LOG_LENGTH, &logSize);
            glGetShaderInfoLog(lightPassShaderFrag, 999, &logSize, infobuffer.ptr);
            writeln("Error in fragment shader:");
            writeln(infobuffer[0..logSize]);
        }

        lightPassShaderProgram = glCreateProgram();
        glAttachShader(lightPassShaderProgram, lightPassShaderVert);
        glAttachShader(lightPassShaderProgram, lightPassShaderFrag);
        glLinkProgram(lightPassShaderProgram);
        
        modelViewMatrixLoc = glGetUniformLocation(lightPassShaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(lightPassShaderProgram, "projectionMatrix");

        viewportSizeLoc = glGetUniformLocation(lightPassShaderProgram, "viewSize");
        
        colorBufferLoc = glGetUniformLocation(lightPassShaderProgram, "colorBuffer");
        rmsBufferLoc = glGetUniformLocation(lightPassShaderProgram, "rmsBuffer");
        positionBufferLoc = glGetUniformLocation(lightPassShaderProgram, "positionBuffer");
        normalBufferLoc = glGetUniformLocation(lightPassShaderProgram, "normalBuffer");
        
        lightPositionLoc = glGetUniformLocation(lightPassShaderProgram, "lightPosition");
        lightRadiusLoc = glGetUniformLocation(lightPassShaderProgram, "lightRadius");
        lightEnergyLoc = glGetUniformLocation(lightPassShaderProgram, "lightEnergy");
        lightAreaRadiusLoc = glGetUniformLocation(lightPassShaderProgram, "lightAreaRadius");
        lightColorLoc = glGetUniformLocation(lightPassShaderProgram, "lightColor");
    }
    
    ~this()
    {
        glDeleteVertexArrays(1, &vao);
        glDeleteBuffers(1, &vbo);
        glDeleteBuffers(1, &tbo);
        glDeleteBuffers(1, &eao);
    }
    
    void render(RenderingContext* rc2d, RenderingContext* rc3d)
    {    
        glUseProgram(lightPassShaderProgram);

        glUniformMatrix4fv(projectionMatrixLoc, 1, 0, rc3d.projectionMatrix.arrayof.ptr);
        
        Vector2f viewportSize;
        
        viewportSize = Vector2f(rc3d.eventManager.windowWidth, rc3d.eventManager.windowHeight);
        glUniform2fv(viewportSizeLoc, 1, viewportSize.arrayof.ptr);

        // Texture 0 - color buffer
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, gbuffer.colorTexture);
        glUniform1i(colorBufferLoc, 0);
        
        // Texture 1 - roughness-metallic-specularity buffer
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, gbuffer.rmsTexture);
        glUniform1i(rmsBufferLoc, 1);
        
        // Texture 2 - position buffer
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, gbuffer.positionTexture);
        glUniform1i(positionBufferLoc, 2);
        
        // Texture 3 - normal buffer
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, gbuffer.normalTexture);
        glUniform1i(normalBufferLoc, 3);
        
        glActiveTexture(GL_TEXTURE0);

        glDisable(GL_DEPTH_TEST);
        glDepthMask(GL_FALSE);
        
        glEnable(GL_CULL_FACE);
        glCullFace(GL_FRONT);
        
        glEnablei(GL_BLEND, 0);
        glEnablei(GL_BLEND, 1);
        glBlendFunci(0, GL_ONE, GL_ONE);
        glBlendFunci(1, GL_ONE, GL_ONE);
        
        foreach(light; lightManager.lightSources.data)
        {
            Matrix4x4f modelViewMatrix = 
                rc3d.viewMatrix *
                translationMatrix(light.position) * 
                scaleMatrix(Vector3f(light.radius, light.radius, light.radius));
            glUniformMatrix4fv(modelViewMatrixLoc, 1, 0, modelViewMatrix.arrayof.ptr);
            
            Vector3f lightPositionEye = light.position * rc3d.viewMatrix;
            
            glUniform3fv(lightPositionLoc, 1, lightPositionEye.arrayof.ptr);
            glUniform1f(lightRadiusLoc, light.radius);
            glUniform1f(lightAreaRadiusLoc, light.areaRadius);
            glUniform3fv(lightColorLoc, 1, light.color.arrayof.ptr);
            glUniform1f(lightEnergyLoc, light.energy);
            
            lightVolume.render(rc3d);
        }
        
        glDisablei(GL_BLEND, 0);
        glDisablei(GL_BLEND, 1);
        
        glCullFace(GL_BACK);
        glDisable(GL_CULL_FACE);
        
        glDepthMask(GL_TRUE);
        glEnable(GL_DEPTH_TEST);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE0);
        
        glUseProgram(0);
    }
}
