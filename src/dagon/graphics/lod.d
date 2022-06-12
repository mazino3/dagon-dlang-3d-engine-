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

module dagon.graphics.lod;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.transformation;
import dlib.container.array;

import dagon.core.bindings;
import dagon.graphics.drawable;
import dagon.graphics.material;

struct LODLevel
{
    Drawable drawable;
    Material material;
    float startDistance;
    float endDistance;
    float fadeDistance;
}

class LODDrawable: Owner, Drawable
{
    Array!LODLevel levels;

    public:

    this(Owner owner)
    {
        super(owner);
    }

    ~this()
    {
        levels.free();
    }

    void addLevel(Drawable drawable, Material material, float startDist, float endDist, float fadeDist)
    {
        levels.append(LODLevel(drawable, material, startDist, endDist, fadeDist));
    }

    void renderLevel(LODLevel* level, float dist, GraphicsState* state)
    {
        if (level.drawable)
        {
            if (level.material)
            {
                level.material.bind(state);
                state.shader.bindParameters(state);
            }
            
            level.drawable.render(state);
            
            if (level.material)
            {
                state.shader.unbindParameters(state);
                level.material.unbind(state);
            }
        }
    }

    void render(GraphicsState* state)
    {
        float distanceToCam = distance(state.cameraPosition, state.modelMatrix.translation);
        
        for(size_t i = 0; i < levels.length; i++)
        {
            LODLevel* level = &levels.data[i];
            if (distanceToCam >= level.startDistance && distanceToCam < level.endDistance)
            {
                renderLevel(level, distanceToCam, state);
            }
        }
    }
}
