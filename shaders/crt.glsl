extern float time;

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    float distortion = 1.0 + r2 * strength;
    return centered * distortion + 0.5;
}

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    vec2 uv = tex_coords;

    uv = barrelDistort(uv, 0.12);

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    vec3 texcolor = Texel(texture, uv).rgb;

    float scanline = sin(screen_coords.y * 2.0) * 0.04;
    texcolor -= scanline;

    float pixelScan = mod(screen_coords.y, 2.0);
    if (pixelScan < 1.0) {
        texcolor *= 0.96;
    }

    float grain = rand(uv + fract(time)) * 0.03 - 0.015;
    texcolor += grain;

    vec2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * 1.0;
    vignette = clamp(vignette, 0.0, 1.0);
    vignette = smoothstep(0.0, 1.0, vignette);
    texcolor *= mix(0.65, 1.0, vignette);

    texcolor *= 1.05;

    texcolor.rgb *= color.rgb;
    return vec4(texcolor, 1.0);
}
