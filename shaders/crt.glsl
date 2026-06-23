extern float time;
extern vec2 playerScreenPos;
extern float playerLightRadius;
extern float dayMode;

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

    float dayAmbient = 1.0;
    float nightAmbient = 0.45;
    float ambient = mix(nightAmbient, dayAmbient, dayMode);

    vec2 toPlayer = playerScreenPos - screen_coords;
    float playerDist = length(toPlayer);
    float playerLight = smoothstep(playerLightRadius, playerLightRadius * 0.25, playerDist);
    float nightLight = playerLight * 0.55;
    float dayLight = 0.0;
    float extraLight = mix(nightLight, dayLight, dayMode);

    float light = ambient + extraLight;
    texcolor *= light;

    float grain = rand(uv + fract(time)) * 0.03 - 0.015;
    texcolor += grain;

    vec2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * 1.0;
    vignette = clamp(vignette, 0.0, 1.0);
    vignette = smoothstep(0.0, 1.0, vignette);
    float nightVignette = mix(0.55, 1.0, vignette);
    float dayVignette = mix(0.8, 1.0, vignette);
    float vig = mix(nightVignette, dayVignette, dayMode);
    texcolor *= vig;

    float nightFlicker = sin(time * 3.0) * 0.01 + 1.0;
    float dayFlicker = 1.0;
    float flicker = mix(nightFlicker, dayFlicker, dayMode);
    texcolor *= flicker;

    texcolor *= 1.05;

    texcolor.rgb *= color.rgb;
    return vec4(texcolor, 1.0);
}
