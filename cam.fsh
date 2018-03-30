#version 150

in vec4 colourV;
in vec2 varTexcoord;
out vec4 fragColour;

uniform sampler2DRect luma;
//uniform sampler2D chroma;

const bool yFlipped = true;
const bool xFlipped = false;

void main(void)
{
    vec2 dims = textureSize(luma);

    vec2 tc = varTexcoord + vec2(
        float(xFlipped) * (-2 * varTexcoord.s + 1),
        float(yFlipped) * (-2 * varTexcoord.t + 1)
    );

    fragColour = colourV;
    fragColour = 0.25 *  colourV + 0.75 * texture(luma, tc * dims);
//    fragColour = colourV;
}
