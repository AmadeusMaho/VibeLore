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

    uv = barrelDistort(uv, 0.15);

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    float aberration = 0.0012;
    float r = Texel(texture, vec2(uv.x + aberration, uv.y)).r;
    float g = Texel(texture, uv).g;
    float b = Texel(texture, vec2(uv.x - aberration, uv.y)).b;
    vec3 texcolor = vec3(r, g, b);

    float scanline = sin(screen_coords.y * 2.0) * 0.06;
    texcolor -= scanline;

    float pixelScan = mod(screen_coords.y, 2.0);
    if (pixelScan < 1.0) {
        texcolor *= 0.95;
    }

    float grain = rand(uv + fract(time)) * 0.04 - 0.02;
    texcolor += grain;

    vec2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * 1.2;
    vignette = clamp(vignette, 0.0, 1.0);
    vignette = smoothstep(0.0, 1.0, vignette);
    texcolor *= mix(0.6, 1.0, vignette);

    texcolor *= 1.08;

    texcolor.r *= 1.02;
    texcolor.b *= 0.98;

    texcolor.rgb *= color.rgb;
    return vec4(texcolor, 1.0);
}
