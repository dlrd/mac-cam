#version 150

uniform vec2 u_origin;

in vec4 in_position;
in vec4 in_color;

out vec4 var_color;

void main (void)
{
    var_color = in_color;
    gl_Position = vec4(u_origin, 0.0, 0.0) + in_position;
}
