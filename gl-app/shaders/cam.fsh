#version 150

const bool yFlipped = true;
const bool xFlipped = false;

uniform sampler2DRect u_frame;

in vec4 var_color;
in vec2 var_uv;

out vec4 out_rgba;

void main(void)
{
    vec2 uv = var_uv + vec2(
        float(xFlipped) * (-2 * var_uv.s + 1),
        float(yFlipped) * (-2 * var_uv.t + 1)
    );

    out_rgba = 0.25 *  var_color + 0.75 * texture(u_frame, uv * textureSize(u_frame));
}
