/*
Copyright (c) 2019-2022 Timur Gafarov

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

module dagon.render.passes.light;

import std.stdio;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;

import dagon.core.bindings;
import dagon.graphics.screensurface;
import dagon.graphics.entity;
import dagon.graphics.light;
import dagon.graphics.shapes;
import dagon.render.pipeline;
import dagon.render.pass;
import dagon.render.framebuffer;
import dagon.render.gbuffer;
import dagon.render.shaders.sunlight;
import dagon.render.shaders.arealight;

class PassLight: RenderPass
{
    GBuffer gbuffer;
    ScreenSurface screenSurface;
    ShapeSphere lightVolume;
    SunLightShader sunLightShader;
    AreaLightShader areaLightShader;
    Framebuffer outputBuffer;
    Framebuffer occlusionBuffer;
    EntityGroup groupSunLights;
    EntityGroup groupAreaLights;

    this(RenderPipeline pipeline, GBuffer gbuffer)
    {
        super(pipeline);
        this.gbuffer = gbuffer;
        screenSurface = New!ScreenSurface(this);
        lightVolume = New!ShapeSphere(1.0f, 8, 4, false, this);
        sunLightShader = New!SunLightShader(this);
        areaLightShader = New!AreaLightShader(this);
    }

    override void render()
    {
        if (groupSunLights && groupAreaLights && outputBuffer && gbuffer)
        {
            outputBuffer.bind();

            state.colorTexture = gbuffer.colorTexture;
            state.depthTexture = gbuffer.depthTexture;
            state.normalTexture = gbuffer.normalTexture;
            state.pbrTexture = gbuffer.pbrTexture;
            if (occlusionBuffer)
                state.occlusionTexture = occlusionBuffer.colorTexture;
            else
                state.occlusionTexture = 0;
            state.environment = pipeline.environment;
            
            glScissor(0, 0, outputBuffer.width, outputBuffer.height);
            glViewport(0, 0, outputBuffer.width, outputBuffer.height);

            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE);

            sunLightShader.bind();
            foreach(entity; groupSunLights)
            {
                Light light = cast(Light)entity;
                if (light)
                {
                    if (light.shining)
                    {
                        state.light = light;
                        sunLightShader.bindParameters(&state);
                        screenSurface.render(&state);
                        sunLightShader.unbindParameters(&state);
                    }
                }
            }
            sunLightShader.unbind();

            glDisable(GL_DEPTH_TEST);
            glDepthMask(GL_FALSE);

            glEnable(GL_CULL_FACE);
            glCullFace(GL_FRONT);

            areaLightShader.bind();
            foreach(entity; groupAreaLights)
            {
                Light light = cast(Light)entity;
                if (light)
                {
                    if (light.shining)
                    {
                        state.light = light;

                        state.modelMatrix =
                            translationMatrix(light.positionAbsolute) *
                            scaleMatrix(Vector3f(light.volumeRadius, light.volumeRadius, light.volumeRadius));

                        state.modelViewMatrix = state.viewMatrix * state.modelMatrix;

                        state.normalMatrix = state.modelViewMatrix.inverse.transposed;

                        areaLightShader.bindParameters(&state);
                        lightVolume.render(&state);
                        areaLightShader.unbindParameters(&state);
                    }
                }
            }
            areaLightShader.unbind();

            glCullFace(GL_BACK);
            glDisable(GL_CULL_FACE);

            glDepthMask(GL_TRUE);
            glEnable(GL_DEPTH_TEST);

            glDisable(GL_BLEND);

            outputBuffer.unbind();
        }
    }
}