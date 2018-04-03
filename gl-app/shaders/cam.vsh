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

struct Rect
{
    float left;
    float right;
    float top;
    float bottom;
};

Rect
screen2d (vec2 resolution)
{
    float aspect = resolution.x / resolution.y;
    float horizontal = float(aspect > 1.0);
    float vertical   = float(aspect <= 1.0);

    return Rect(
        -aspect * horizontal - 1.0            * vertical,
         aspect * horizontal + 1.0            * vertical,
          1.0   * horizontal + (1.0 / aspect) * vertical,
         -1.0   * horizontal - (1.0 / aspect) * vertical
    );
}

mat3
orthographic2d (Rect screen)
{
    float w = 1.0 / (screen.right - screen.left);
    float h = 1.0 / (screen.top   - screen.bottom);

    float x = (screen.left + screen.right) * w;
    float y = (screen.top  + screen.bottom) * h;

    return mat3(
        2 * w,     0,  -x,
            0, 2 * h,  -y,
            0,     0,   1
    );
}

void main (void)
{
    Rect screen = screen2d(u_resolution);

    mat3 projection = orthographic2d(screen);

    vec2 size = textureSize(u_frame);
    
    vec2 aspect = vec2(size.x == size.y) * vec2(1.0, 1.0)
        + vec2(size.x > size.y) * vec2(1.0                    , 1.0 * (size.y / size.x))
        + vec2(size.x < size.y) * vec2(1.0 * (size.x / size.y), 1.0
    );
    
    float fit = min(
        (screen.right - screen.left  ) / (aspect.x * 2.0),
        (screen.top   - screen.bottom) / (aspect.y * 2.0)
    );
    
    mat3 scaling = scale2d(fit * aspect);

    vec2 offset = vec2(0.5 * sin(u_time), 0.5 * cos(u_time));
    mat3 translation = translate2d(vec2(wandering) * offset);

    gl_Position = vec4((scaling * vec3(in_position.xy, 1) * translation * projection).xy, 0, 1);

    var_color = in_color;
    var_uv = in_uv;
}
