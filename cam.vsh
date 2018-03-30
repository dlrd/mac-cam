#version 150

const bool wandering = true;

uniform vec2          u_resolution;
uniform float         u_time;
uniform sampler2DRect u_frame;

in vec4 in_position;
in vec4 in_color;
in vec2 in_uv;

out vec4 var_color;
out vec2 var_uv;

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
    vec2 size = textureSize(u_frame);
    vec2 offset = vec2(0.5 * sin(u_time), 0.5 * cos(u_time));
    mat3 scaling = scale2d(vec2(size.x / size.y, 1.0));
    mat3 translation = translate2d(vec2(wandering) * offset);
    mat3 projection = orthographic2d(u_resolution);
    
    gl_Position = vec4((scaling * vec3(in_position.xy, 1) * translation * projection).xy, 0, 1);
    var_color = in_color;
    var_uv = in_uv;
}
