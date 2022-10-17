/*
Copyright (c) 2021-2022 Timur Gafarov

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

module dagon.ext.newton.constraint;

import dlib.core.ownership;
import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import bindbc.newton;
import dagon.ext.newton.world;
import dagon.ext.newton.rigidbody;

abstract class NewtonConstraint: Owner
{
    NewtonPhysicsWorld world;
    NewtonJoint* joint;
    
    this(NewtonPhysicsWorld world)
    {
        super(world);
        this.world = world;
    }
    
    float stiffness()
    {
        return NewtonJointGetStiffness(joint);
    }
    void stiffness(float s)
    {
        NewtonJointSetStiffness(joint, s);
    }
}

class NewtonBallConstraint: NewtonConstraint
{
    NewtonRigidBody body1;
    NewtonRigidBody body2;
    Vector3f pivotPoint;
    
    this(NewtonPhysicsWorld world, NewtonRigidBody body1, NewtonRigidBody body2, Vector3f pivotPoint)
    {
        super(world);
        this.body1 = body1;
        this.body2 = body2;
        this.pivotPoint = pivotPoint;
        this.joint = NewtonConstraintCreateBall(world.newtonWorld, pivotPoint.arrayof.ptr, body1.newtonBody, body2.newtonBody);
        NewtonJointSetCollisionState(this.joint, 1);
    }
    
    void setConeLimits(Vector3f axis, float maxConeAngle, float maxTwistAngle)
    {
        NewtonBallSetConeLimits(joint, axis.arrayof.ptr, maxConeAngle, maxTwistAngle);
    }
}

class NewtonSliderConstraint: NewtonConstraint
{
    NewtonRigidBody body1;
    NewtonRigidBody body2;
    Vector3f pivotPoint;
    Vector3f pivotAxis;
    
    this(NewtonPhysicsWorld world, NewtonRigidBody body1, NewtonRigidBody body2, Vector3f pivotPoint, Vector3f pivotAxis)
    {
        super(world);
        this.body1 = body1;
        this.body2 = body2;
        this.pivotPoint = pivotPoint;
        this.pivotAxis = pivotAxis;
        this.joint = NewtonConstraintCreateSlider(world.newtonWorld, pivotPoint.arrayof.ptr, pivotAxis.arrayof.ptr, body1.newtonBody, body2.newtonBody);
        NewtonJointSetCollisionState(this.joint, 1);
    }
}

class NewtonCorkscrewConstraint: NewtonConstraint
{
    NewtonRigidBody body1;
    NewtonRigidBody body2;
    Vector3f pivotPoint;
    Vector3f pivotAxis;
    
    this(NewtonPhysicsWorld world, NewtonRigidBody body1, NewtonRigidBody body2, Vector3f pivotPoint, Vector3f pivotAxis)
    {
        super(world);
        this.body1 = body1;
        this.body2 = body2;
        this.pivotPoint = pivotPoint;
        this.pivotAxis = pivotAxis;
        this.joint = NewtonConstraintCreateCorkscrew(world.newtonWorld, pivotPoint.arrayof.ptr, pivotAxis.arrayof.ptr, body1.newtonBody, body2.newtonBody);
        NewtonJointSetCollisionState(this.joint, 1);
    }
}

class NewtonUniversalConstraint: NewtonConstraint
{
    NewtonRigidBody body1;
    NewtonRigidBody body2;
    Vector3f pivotPoint;
    Vector3f pivotAxis1;
    Vector3f pivotAxis2;
    
    this(NewtonPhysicsWorld world, NewtonRigidBody body1, NewtonRigidBody body2, Vector3f pivotPoint, Vector3f pivotAxis1, Vector3f pivotAxis2)
    {
        super(world);
        this.body1 = body1;
        this.body2 = body2;
        this.pivotPoint = pivotPoint;
        this.pivotAxis1 = pivotAxis1;
        this.pivotAxis2 = pivotAxis2;
        this.joint = NewtonConstraintCreateUniversal(world.newtonWorld, pivotPoint.arrayof.ptr, pivotAxis1.arrayof.ptr, pivotAxis2.arrayof.ptr, body1.newtonBody, body2.newtonBody);
        NewtonJointSetCollisionState(this.joint, 1);
    }
}

class NewtonUpVectorConstraint: NewtonConstraint
{
    NewtonRigidBody body1;
    Vector3f pivotAxis;
    
    this(NewtonPhysicsWorld world, NewtonRigidBody body1, Vector3f pivotAxis)
    {
        super(world);
        this.body1 = body1;
        this.pivotAxis = pivotAxis;
        this.joint = NewtonConstraintCreateUpVector(world.newtonWorld, pivotAxis.arrayof.ptr, body1.newtonBody);
    }
}

class NewtonUserJointConstraint: NewtonConstraint
{
    NewtonRigidBody body1;
    NewtonRigidBody body2;
    
    this(NewtonPhysicsWorld world, NewtonRigidBody body1, NewtonRigidBody body2, uint maxDOF)
    {
        super(world);
        this.body1 = body1;
        this.body2 = body2;
        NewtonBody* parentBody = null;
        if (body2)
            parentBody = body2.newtonBody;
        this.joint = NewtonConstraintCreateUserJoint(world.newtonWorld, maxDOF, &getInfo, body1.newtonBody, parentBody);
        NewtonJointSetUserData(this.joint, cast(void*)this);
    }
    
    void addLinearRow(Vector3f pivot0, Vector3f pivot1, Vector3f dir)
    {
        NewtonUserJointAddLinearRow(joint, pivot0.arrayof.ptr, pivot1.arrayof.ptr, dir.arrayof.ptr);
    }
    
    void setMaximumFriction(float maxFriction)
    {
        NewtonUserJointSetRowMaximumFriction(joint, maxFriction);
    }
    
    void setMinimumFriction(float minFriction)
    {
        NewtonUserJointSetRowMinimumFriction(joint, minFriction);
    }
    
    void submit(float timestep, int threadIndex)
    {
        //
    }
    
    static extern(C) void getInfo(const NewtonJoint* joint, float timestep, int threadIndex)
    {
        NewtonUserJointConstraint ujc = cast(NewtonUserJointConstraint)NewtonJointGetUserData(joint);
        ujc.submit(timestep, threadIndex);
    }
}