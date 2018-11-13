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

module dagon;

public
{
    import dagon.core.libs;

    import dlib.core;
    import dlib.math;
    import dlib.geometry;
    import dlib.image;
    import dlib.container;

    import dmech;

    import dagon.core.ownership;
    import dagon.core.interfaces;
    import dagon.core.application;
    import dagon.core.event;
    import dagon.core.keycodes;
    import dagon.core.vfs;

    import dagon.resource.scene;
    import dagon.resource.asset;
    import dagon.resource.textasset;
    import dagon.resource.textureasset;
    import dagon.resource.obj;
    import dagon.resource.iqm;
    import dagon.resource.fontasset;
    import dagon.resource.entityasset;
    import dagon.resource.materialasset;
    import dagon.resource.packageasset;
    import dagon.resource.props;

    import dagon.logics.entity;
    import dagon.logics.behaviour;
    import dagon.logics.controller;
    import dagon.logics.rigidbodycontroller;
    import dagon.logics.charactercontroller;

    import dagon.graphics.rc;
    import dagon.graphics.tbcamera;
    import dagon.graphics.freeview;
    import dagon.graphics.fpcamera;
    import dagon.graphics.fpview;
    import dagon.graphics.shapes;
    import dagon.graphics.screensurface;
    import dagon.graphics.texture;
	import dagon.graphics.shader;
    import dagon.graphics.material;
    import dagon.graphics.environment;
    import dagon.graphics.mesh;
    import dagon.graphics.animmodel;
    import dagon.graphics.view;
    import dagon.graphics.shadow;
    import dagon.graphics.light;
    import dagon.graphics.framebuffer;
    import dagon.graphics.postproc;
    import dagon.graphics.particles;
    import dagon.graphics.gbuffer;
    import dagon.graphics.deferred;
    import dagon.graphics.renderer;

    import dagon.graphics.materials.generic;

    import dagon.graphics.shaders.geometrypass;
    import dagon.graphics.shaders.environmentpass;
    import dagon.graphics.shaders.lightpass;
    import dagon.graphics.shaders.standard;
    import dagon.graphics.shaders.sky;
    import dagon.graphics.shaders.rayleigh;
    import dagon.graphics.shaders.particle;
    import dagon.graphics.shaders.water;

    import dagon.graphics.filters.fxaa;
    import dagon.graphics.filters.lens;
    import dagon.graphics.filters.hdr;
    import dagon.graphics.filters.blur;
    import dagon.graphics.filters.finalizer;

    import dagon.ui.font;
    import dagon.ui.ftfont;
    import dagon.ui.textline;
}
