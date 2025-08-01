#version 330 core
out vec4 FragColor;

in vec3 ourColor;
in vec2 TexCoord;

uniform sampler2D container_texture;
uniform sampler2D emoji_texture;

void main()
{
    FragColor = mix(texture(container_texture, TexCoord), texture(emoji_texture, TexCoord), 0.2);
}
