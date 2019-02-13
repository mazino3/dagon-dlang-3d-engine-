/*
Copyright (c) 2019 Mateusz Muszyński

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

module dagon.core.input;

import std.stdio;
import std.ascii;
import std.conv : to;
import std.math : abs;
import std.algorithm.searching : startsWith;
import dlib.core.memory;
import dlib.container.dict;
import dlib.container.array;
import dlib.text.lexer;
import dlib.text.unmanagedstring;
import dagon.core.event;
import dagon.core.libs;
import dagon.core.ownership;
import dagon.resource.asset;
import dagon.resource.config;

enum BindingType
{
    None,
    Keyboard,
    MouseButton,
    MouseAxis,
    GamepadButton,
    GamepadAxis
}

struct Binding
{
    BindingType type;
    union
    {
        int key;
        int button;
        int axis;
    }
}

class InputManager
{
    EventManager eventManager;

    alias Bindings = DynamicArray!Binding;

    Dict!(Bindings, string) bindings;

    Configuration config;

    this(EventManager em)
    {
        eventManager = em;
        bindings = dict!(Bindings, string)();

        config = New!Configuration(null);
        if (!config.fromFile("input.conf"))
        {
            writeln("Warning: no \"input.conf\" found");
        }

        foreach(name, value; config.props.props)
        {
            setBinding(name, value.data);
        }
    }

    ~this()
    {
        bindings.free();
        Delete(config);
    }

    void setBinding(string name, BindingType type, int value)
    {
        if(auto binding = name in bindings)
        {
            binding.insertBack(Binding(type, value));
        }
        else
        {
            auto b = Bindings();
            b.insertBack(Binding(type, value));
            bindings[name] = b;
        }
    }

    void setBinding(string name, string value)
    {
        // Binding format consist of device type and name(or number)
        // coresponding to button or axis of this device
        // eg. kb_up, kb_w, ma_0, mb_1, gb_a, gb_x, ga_leftx, ga_lefttrigger
        // kb -> keybaord
        // ma -> mouse axis
        // mb -> mouse button
        // ga -> gamepad axis
        // gb -> gamepad button

        BindingType type = BindingType.None;
        int result = -1;

        auto lexer = New!Lexer(value, ["_", ","]);
        lexer.ignoreWhitespaces = true;

        String svalue;
        char* cvalue;

        while(true)
        {
            auto lexeme = lexer.getLexeme();
            switch(lexeme)
            {
                case "kb": type = BindingType.Keyboard; break;
                case "ma": type = BindingType.MouseAxis; break;
                case "mb": type = BindingType.MouseButton; break;
                case "ga": type = BindingType.GamepadAxis; break;
                case "gb": type = BindingType.GamepadButton; break;

                default: goto check;
            }

            lexeme = lexer.getLexeme();

            if(lexeme != "_")
            {
                goto check;
            }

            lexeme = lexer.getLexeme();

            svalue = String(lexeme);
            cvalue = svalue.cString;

            switch(type)
            {
                case BindingType.Keyboard:      result = cast(int)SDL_GetScancodeFromName(cvalue); break;
                case BindingType.MouseAxis:     result = to!int(lexeme); break;
                case BindingType.MouseButton:   result = to!int(lexeme); break;
                case BindingType.GamepadAxis:   result = cast(int)SDL_GameControllerGetAxisFromString(cvalue); break;
                case BindingType.GamepadButton: result = cast(int)SDL_GameControllerGetButtonFromString(cvalue); break;

                default: break;
            }

        check:
            if(type == BindingType.None || result <= 0)
            {
                writefln("Error: wrong binding format \"%s\"", value);
                break;
            }
            setBinding(name, type, result);

            lexeme = lexer.getLexeme();
            if(lexeme != ",")
                break;
        }
        svalue.free();
        Delete(lexer);
    }

    bool getButton(string name)
    {
        auto b = name in bindings;
        if (!b)
            return false;

        for(int i = 0; i < b.length; i++)
        {
            auto binding = (*b)[i];

            switch(binding.type)
            {
                case BindingType.Keyboard:
                    if(eventManager.keyPressed[binding.key]) return true;
                    break;

                case BindingType.MouseButton:
                    if(eventManager.mouseButtonPressed[binding.button]) return true;
                    break;

                case BindingType.MouseAxis:
                    if (binding.axis == 0)
                    {
                        if(eventManager.mouseRelX != 0) return true;
                    }
                    else if (binding.axis == 1)
                    {
                        if(eventManager.mouseRelY != 0) return true;
                    }
                    break;

                case BindingType.GamepadButton:
                    if(eventManager.controllerButtonPressed[binding.button]) return true;
                    break;

                case BindingType.GamepadAxis:
                    if (eventManager.gameControllerAvailable)
                        if(eventManager.gameControllerAxis(binding.axis) > 0.01)
                            return true;
                    break;

                default:
                    break;
            }
        }

        return false;
    }

    bool getButtonUp(string name)
    {
        auto b = name in bindings;
        if (!b)
            return false;

        for(int i = 0; i < b.length; i++)
        {
            auto binding = (*b)[i];
            switch(binding.type)
            {
                case BindingType.Keyboard:
                    if(eventManager.keyUp[binding.key]) return true;
                    break;

                case BindingType.MouseButton:
                    if(eventManager.mouseButtonUp[binding.button]) return true;
                    break;

                case BindingType.MouseAxis:
                    // Do we want to track this?
                    break;

                case BindingType.GamepadButton:
                    if(eventManager.controllerButtonUp[binding.button]) return true;
                    break;

                case BindingType.GamepadAxis:
                    // And track that?
                    break;

                default:
                    break;
            }
        }

        return false;
    }

    bool getButtonDown(string name)
    {
        auto b = name in bindings;
        if (!b)
            return false;

        for(int i = 0; i < b.length; i++)
        {
            auto binding = (*b)[i];

            switch(binding.type)
            {
                case BindingType.Keyboard:
                    if(eventManager.keyDown[binding.key]) return true;
                    break;

                case BindingType.MouseButton:
                    if(eventManager.mouseButtonDown[binding.button]) return true;
                    break;

                case BindingType.MouseAxis:
                    break;

                case BindingType.GamepadButton:
                    if(eventManager.controllerButtonDown[binding.button]) return true;
                    break;

                case BindingType.GamepadAxis:
                    break;

                default:
                    break;
            }
        }

        return false;
    }

    float getAxis(string name)
    {
        auto b = name in bindings;
        if (!b)
            return false;

        float result = 0.0f;
        float aresult = 0.0f; // absolute result

        for(int i = 0; i < b.length; i++)
        {
            auto binding = (*b)[i];
            float value = 0.0f;

            switch(binding.type)
            {
                case BindingType.Keyboard:
                    value = eventManager.keyPressed[binding.key] ? 1.0f : 0.0f;
                    break;

                case BindingType.MouseButton:
                    value = eventManager.mouseButtonPressed[binding.button] ? 1.0f : 0.0f;
                    break;

                case BindingType.MouseAxis:
                    if (binding.axis == 0)
                        value = eventManager.mouseRelX / (eventManager.windowWidth * 0.5f); // map to -1 to 1 range
                    else if (binding.axis == 1)
                        value = eventManager.mouseRelY / (eventManager.windowHeight * 0.5f);
                    break;

                case BindingType.GamepadButton:
                    value = eventManager.controllerButtonPressed[binding.button] ? 1.0f : 0.0f;
                    break;

                case BindingType.GamepadAxis:
                    if (eventManager.gameControllerAvailable)
                        value = eventManager.gameControllerAxis(binding.axis);
                    break;

                default:
                    break;
            }
            float avalue = abs(value);
            if(avalue > aresult)
            {
                result = value;
                aresult = avalue;
            }
        }

        return result;
    }
}
