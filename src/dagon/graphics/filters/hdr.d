/*
Copyright (c) 2017-2018 Timur Gafarov

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

module dagon.graphics.filters.hdr;

import dagon.core.libs;
import dagon.core.ownership;
import dagon.graphics.postproc;
import dagon.graphics.framebuffer;
import dagon.graphics.texture;
import dagon.graphics.rc;

enum Tonemapper
{
    Reinhard = 0,
    Hable = 1,
    ACES = 2,
    Parametric = 3
}

class PostFilterHDR: PostFilter
{
    private string vs = import("HDR.vs");
    private string fs = import("HDR.fs");

    override string vertexShader()
    {
        return vs;
    }

    override string fragmentShader()
    {
        return fs;
    }

    GLint fbPositionLoc;
    GLint colorTableLoc;
    GLint exposureLoc;
    GLint tonemapFunctionLoc;
    GLint useLUTLoc;
    GLint vignetteLoc;
    GLint useVignetteLoc;
    GLint fbVelocityLoc;
    GLint useMotionBlurLoc;
    GLint motionBlurSamplesLoc;
    GLint shutterFpsLoc;
    GLint timeStepLoc;
    GLint parametricCurveKLoc;

    bool autoExposure = false;

    float minLuminance = 0.1f;
    float maxLuminance = 100000.0f;
    float keyValue = 0.5f;
    float adaptationSpeed = 4.0f;

    float exposure = 0.5f;
    Tonemapper tonemapFunction = Tonemapper.ACES;
    float parametricTonemapperLinearity = 0.2;

    GLuint velocityTexture;
    bool mblurEnabled = false;
    int motionBlurSamples = 20;
    float shutterFps = 60.0;
    float shutterSpeed = 1.0 / 60.0;

    Texture colorTable;
    Texture vignette;

    this(Framebuffer inputBuffer, Framebuffer outputBuffer, Owner o)
    {
        super(inputBuffer, outputBuffer, o);

        fbPositionLoc = glGetUniformLocation(shaderProgram, "fbPosition");
        colorTableLoc = glGetUniformLocation(shaderProgram, "colorTable");
        exposureLoc = glGetUniformLocation(shaderProgram, "exposure");
        tonemapFunctionLoc = glGetUniformLocation(shaderProgram, "tonemapFunction");
        useLUTLoc = glGetUniformLocation(shaderProgram, "useLUT");
        vignetteLoc = glGetUniformLocation(shaderProgram, "vignette");
        useVignetteLoc = glGetUniformLocation(shaderProgram, "useVignette");
        fbVelocityLoc = glGetUniformLocation(shaderProgram, "fbVelocity");
        useMotionBlurLoc = glGetUniformLocation(shaderProgram, "useMotionBlur");
        motionBlurSamplesLoc = glGetUniformLocation(shaderProgram, "motionBlurSamples");
        shutterFpsLoc = glGetUniformLocation(shaderProgram, "shutterFps");
        timeStepLoc = glGetUniformLocation(shaderProgram, "timeStep");
        parametricCurveKLoc = glGetUniformLocation(shaderProgram, "parametricCurveK");
    }

    override void bind(RenderingContext* rc)
    {
        super.bind(rc);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, velocityTexture);

        glActiveTexture(GL_TEXTURE3);
        if (colorTable)
            colorTable.bind();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glActiveTexture(GL_TEXTURE0);

        glActiveTexture(GL_TEXTURE4);
        if (vignette)
            vignette.bind();

        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, inputBuffer.gbuffer.positionTexture);

        glActiveTexture(GL_TEXTURE0);

        glUniform1i(fbPositionLoc, 5);
        glUniform1i(fbVelocityLoc, 2);
        glUniform1i(colorTableLoc, 3);
        glUniform1f(exposureLoc, exposure);
        glUniform1i(tonemapFunctionLoc, tonemapFunction);
        glUniform1i(useLUTLoc, (colorTable !is null));
        glUniform1i(vignetteLoc, 4);
        glUniform1i(useVignetteLoc, (vignette !is null));
        glUniform1i(useMotionBlurLoc, mblurEnabled);
        glUniform1i(motionBlurSamplesLoc, motionBlurSamples);
        glUniform1f(shutterFpsLoc, shutterFps);
        glUniform1f(timeStepLoc, rc.eventManager.deltaTime);
        glUniform1f(parametricCurveKLoc, 1.0 - parametricTonemapperLinearity);
    }

    override void unbind(RenderingContext* rc)
    {
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE3);
        if (colorTable)
            colorTable.unbind();

        glActiveTexture(GL_TEXTURE4);
        if (vignette)
            vignette.unbind();

        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE0);
    }
}
