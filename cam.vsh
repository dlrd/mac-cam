#version 150

uniform vec2 resolution;
uniform vec2 p;
uniform sampler2DRect luma;

in vec4 position;
in vec4 colour;
in vec2  inTexcoord;

out vec4 colourV;
out vec2 varTexcoord;

const bool wandering = true;

mat3
orthographic2d (vec2 resolution)
{
    float aspect = resolution.x / resolution.y;

    float left = -aspect;
    float right = aspect;
    float top =  1.0;
    float bottom = -1.0;

    float w = 1.0 / (right - left);
    float h = 1.0 / (top - bottom);

    float x = (right + left) * w;
    float y = (top + bottom) * h;

    return mat3(
        2 * w,     0,  -x,
            0, 2 * h,  -y,
            0,     0,   1
    );
}

mat3
scale2d (vec2 s)
{
    return mat3(
        s.x, 0.0, 0.0,
        0.0, s.y, 0.0,
        0.0, 0.0, 1.0
    );
}

mat3
translate2d (vec2 t)
{
    return mat3(
        1.0, 0.0, t.x,
        0.0, 1.0, t.y,
        0.0, 0.0, 1.0
    );
}

void main (void)
{
    vec2 dims = textureSize(luma);

    mat3 scaling = scale2d(vec2(dims.x / dims.y, 1.0));
    mat3 translation = translate2d(vec2(wandering) * p);
    mat3 projection = orthographic2d(resolution);
    
    gl_Position = vec4((scaling * vec3(position.xy, 1) * translation * projection).xy, 0, 1);
    varTexcoord = inTexcoord;
    colourV = colour;
}
