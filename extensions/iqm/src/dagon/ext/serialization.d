/*
Copyright (c) 2017-2022 Timur Gafarov

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

module dagon.ext.serialization;

import std.traits;
import std.bitmanip;

import dlib.core.stream;

// Stream-based serialization and deserialization

struct Series(T, bool fixedSize = false)
{
    union
    {
        T _value;
        static if (isDynamicArray!T)
            ubyte[] _bytes;
        else
            ubyte[T.sizeof] _bytes;
    }

    this(T val)
    {
        value = val;
    }

    T opAssign(T val)
    {
        return (value = val);
    }

    this(InputStream istrm)
    {
        readFrom(istrm);
    }

    @property T value(T v)
    {
        static if (isIntegral!T)
        {
            _bytes = nativeToLittleEndian!T(v);
        }
        else
            _value = v;
        return _value;
    }

    @property T value()
    {
        T res;
        static if (isIntegral!T)
        {
            res = littleEndianToNative!T(_bytes);
        }
        else
            res = _value;
        return res;
    }

    size_t writeTo(OutputStream ostrm)
    {
        size_t n = 0;
        static if (isDynamicArray!T)
        {
            n += Series!(uint)(cast(uint)_value.length).writeTo(ostrm);
            foreach(v; _value)
                n += Series!(Unqual!(typeof(v)))(v).writeTo(ostrm);
            return n;
        }
        else
        static if (is(T == struct) || is(T == class))
        {
            static if (is(T == class))
                if (_value is null)
                    throw new Exception("null reference in input");

            // TODO: make automatic check
            static if (is(T == struct) && fixedSize)
            {
                n = ostrm.writeBytes(_bytes.ptr, _bytes.length);
            }
            else
            {
                foreach(v; _value.tupleof)
                    n += Series!(typeof(v))(v).writeTo(ostrm);
            }
            return n;
        }
        else
        {
            return ostrm.writeBytes(_bytes.ptr, _bytes.length);
        }
    }

    size_t readFrom(InputStream istrm)
    {
        static if (isSomeString!T)
        {
            uint len = Series!(uint)(istrm).value;
            size_t pos = 4;
            ubyte[] buff = new ubyte[len];
            istrm.fillArray(buff);
            T str = cast(T)buff;
            _value = str;
            pos += len;
            return pos;
        }
        else
        static if (isDynamicArray!T)
        {
            uint len = Series!(uint)(istrm).value;
            size_t pos = 4;
            alias FT = ForeachType!T;
            if (len == 0)
                return pos;

            _value = new FT[len];

            foreach(ref v; _value)
            {
                Series!(FT) se;
                size_t s = se.readFrom(istrm);
                v = se.value;
                pos += s;
            }

            return pos;
        }
        else
        static if (is(T == struct) || is(T == class))
        {
            size_t pos = 0;
            static if (is(T == class))
                if (_value is null)
                    throw new Exception("null reference in output");

            static if (is(T == struct) && fixedSize)
            {
                pos += istrm.readBytes(_bytes.ptr, T.sizeof);
            }
            else
            foreach(ref v; _value.tupleof)
            {
                Series!(typeof(v)) se;
                static if (is(typeof(v) == class))
                {
                    if (v is null)
                        throw new Exception("null reference in output");
                    se._value = v;
                }
                size_t s = se.readFrom(istrm);
                v = se.value;
                pos += s;
            }

            return pos;
        }
        else
        {
            return istrm.readBytes(_bytes.ptr, T.sizeof);
        }
    }
}

T read(T, bool fixedSize = false)(InputStream istrm)
{
    auto s = Series!(T, fixedSize)(istrm);
    return s.value;
}

size_t write(T, bool fixedSize = false)(InputStream istrm, T val)
{
    auto s = Series!(T, fixedSize)(val);
    return s.writeTo(istrm);
}

