/*
Copyright (c) 2019-2020 Timur Gafarov

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

module dagon.render.shaders.geometry;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.image.color;
import dlib.text.str;

import dagon.core.bindings;
import dagon.graphics.material;
import dagon.graphics.shader;
import dagon.graphics.state;

class GeometryShader: Shader
{
    String vs, fs;

    this(Owner owner)
    {
        vs = Shader.load("data/__internal/shaders/Geometry/Geometry.vert.glsl");
        fs = Shader.load("data/__internal/shaders/Geometry/Geometry.frag.glsl");

        auto prog = New!ShaderProgram(vs, fs, this);
        super(prog, owner);
    }

    ~this()
    {
        vs.free();
        fs.free();
    }

    override void bindParameters(GraphicsState* state)
    {
        auto idiffuse = "diffuse" in state.material.inputs;
        auto inormal = "normal" in state.material.inputs;
        auto iheight = "height" in state.material.inputs;
        auto iroughnessMetallic = "roughnessMetallic" in state.material.inputs;
        auto iroughness = "roughness" in state.material.inputs;
        auto imetallic = "metallic" in state.material.inputs;
        auto ispecularity = "specularity" in state.material.inputs;
        auto itransparency = "transparency" in state.material.inputs;
        auto iclipThreshold = "clipThreshold" in state.material.inputs;
        auto itranslucency = "translucency" in state.material.inputs;
        auto itextureScale = "textureScale" in state.material.inputs;
        auto iparallax = "parallax" in state.material.inputs;
        auto iemission = "emission" in state.material.inputs;
        auto ienergy = "energy" in state.material.inputs;
        auto isphericalNormal = "sphericalNormal" in state.material.inputs;

        setParameter("modelViewMatrix", state.modelViewMatrix);
        setParameter("projectionMatrix", state.projectionMatrix);
        setParameter("normalMatrix", state.normalMatrix);
        setParameter("viewMatrix", state.viewMatrix);
        setParameter("invViewMatrix", state.invViewMatrix);
        setParameter("prevModelViewMatrix", state.prevModelViewMatrix);

        setParameter("layer", cast(float)(state.layer));
        setParameter("textureScale", itextureScale.asVector2f);
        setParameter("blurMask", state.blurMask);

        int parallaxMethod = iparallax.asInteger;
        if (parallaxMethod > ParallaxOcclusionMapping)
            parallaxMethod = ParallaxOcclusionMapping;
        if (parallaxMethod < 0)
            parallaxMethod = 0;

        setParameter("sphericalNormal", cast(int)isphericalNormal.asBool);

        // Transparency
        float materialOpacity = 1.0f;
        if (itransparency)
            materialOpacity = itransparency.asFloat;
        setParameter("opacity", state.opacity * materialOpacity);
        
        float clipThreshold = 0.5f;
        if (iclipThreshold)
            clipThreshold = iclipThreshold.asFloat;
        setParameter("clipThreshold", clipThreshold);

        // Diffuse
        if (idiffuse.texture)
        {
            glActiveTexture(GL_TEXTURE0);
            idiffuse.texture.bind();
            setParameter("diffuseTexture", cast(int)0);
            setParameterSubroutine("diffuse", ShaderType.Fragment, "diffuseColorTexture");
        }
        else
        {
            setParameter("diffuseVector", idiffuse.asVector4f);
            setParameterSubroutine("diffuse", ShaderType.Fragment, "diffuseColorValue");
        }

        // Normal/height
        bool haveHeightMap = inormal.texture !is null;
        if (haveHeightMap)
            haveHeightMap = inormal.texture.image.channels == 4;

        if (!haveHeightMap)
        {
            if (inormal.texture is null)
            {
                if (iheight.texture !is null) // we have height map, but no normal map
                {
                    Color4f color = Color4f(0.5f, 0.5f, 1.0f, 0.0f); // default normal pointing upwards
                    inormal.texture = state.material.makeTexture(color, iheight.texture);
                    haveHeightMap = true;
                }
            }
            else
            {
                if (iheight.texture !is null) // we have both normal and height maps
                {
                    inormal.texture = state.material.makeTexture(inormal.texture, iheight.texture);
                    haveHeightMap = true;
                }
            }
        }

        if (inormal.texture)
        {
            setParameter("generateTBN", 1);
            setParameter("normalTexture", 1);
            setParameterSubroutine("normal", ShaderType.Fragment, "normalMap");

            glActiveTexture(GL_TEXTURE1);
            inormal.texture.bind();
        }
        else
        {
            setParameter("generateTBN", 0);
            setParameter("normalVector", state.material.normal.asVector3f);
            setParameterSubroutine("normal", ShaderType.Fragment, "normalValue");
        }
        
        if (state.material.invertNormalY)
            setParameter("normalYSign", -1.0f);
        else
            setParameter("normalYSign", 1.0f);

        // Height and parallax
        // TODO: make these material properties
        float parallaxScale = 0.03f;
        float parallaxBias = -0.01f;
        setParameter("parallaxScale", parallaxScale);
        setParameter("parallaxBias", parallaxBias);

        if (haveHeightMap)
        {
            setParameterSubroutine("height", ShaderType.Fragment, "heightMap");
        }
        else
        {
            float h = 0.0f; //-parallaxBias / parallaxScale;
            setParameter("heightScalar", h);
            setParameterSubroutine("height", ShaderType.Fragment, "heightValue");
            parallaxMethod = ParallaxNone;
        }

        if (parallaxMethod == ParallaxSimple)
            setParameterSubroutine("parallax", ShaderType.Fragment, "parallaxSimple");
        else if (parallaxMethod == ParallaxOcclusionMapping)
            setParameterSubroutine("parallax", ShaderType.Fragment, "parallaxOcclusionMapping");
        else
            setParameterSubroutine("parallax", ShaderType.Fragment, "parallaxNone");

        // PBR
        if (iroughnessMetallic is null)
        {
            state.material.setInput("roughnessMetallic", 0.0f);
            iroughnessMetallic = "roughnessMetallic" in state.material.inputs;
        }
        if (iroughnessMetallic.texture is null)
        {
            iroughnessMetallic.texture = state.material.makeTexture(*ispecularity, *iroughness, *imetallic, *itranslucency);
        }
        glActiveTexture(GL_TEXTURE2);
        iroughnessMetallic.texture.bind();
        setParameter("pbrTexture", 2);
        
        setParameterSubroutine("specularity", ShaderType.Fragment, "specularityMap");
        setParameterSubroutine("metallic", ShaderType.Fragment, "metallicMap");
        setParameterSubroutine("roughness", ShaderType.Fragment, "roughnessMap");
        setParameterSubroutine("translucency", ShaderType.Fragment, "translucencyMap");
        
        // TODO: specularity, translucensy

        // Emission
        if (iemission.texture)
        {
            glActiveTexture(GL_TEXTURE3);
            iemission.texture.bind();
            setParameter("emissionTexture", cast(int)3);
            setParameterSubroutine("emission", ShaderType.Fragment, "emissionColorTexture");
        }
        else
        {
            setParameter("emissionVector", iemission.asVector4f);
            setParameterSubroutine("emission", ShaderType.Fragment, "emissionColorValue");
        }
        setParameter("energy", ienergy.asFloat);

        glActiveTexture(GL_TEXTURE0);

        super.bindParameters(state);
    }

    override void unbindParameters(GraphicsState* state)
    {
        super.unbindParameters(state);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE0);
    }
}
