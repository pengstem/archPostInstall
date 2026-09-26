#language slang 2026
// Small click ripple centred on the last left-button press. Sized in pixels, so
// it looks the same in any window size (physical pixels: 1.5x scaling makes them
// look smaller), and alpha-composited so it works on a translucent background.
// Pair with animation_curve linear: the easing is done here, which keeps the
// SONAR rings evenly staggered.

import kitty_custom_shader_types;

// 0 = RING  - one thin ring that expands and fades
// 1 = SONAR - SONAR_RINGS staggered rings
// 2 = DROP  - a water drop: the text under the rim is refracted, with a faint rim light
static const int STYLE = 0;

static const float MAX_RADIUS = 120.0;                       // final ring radius, px
static const float RING_WIDTH = 2.0;                         // ring core half-thickness, px
static const float GLOW = 12.0;                              // soft glow falloff around the core, px
static const float3 RING_COLOR = float3(0.908, 0.867, 0.805); // #f4efe7 (cursor_trail_color) in linear RGB
static const float RING_OPACITY = 0.85;
static const int SONAR_RINGS = 3;
static const float SONAR_STAGGER = 0.2; // start delay between SONAR rings, fraction of the animation
static const float REFRACTION = 12.0;   // DROP displacement at the rim, px

float
ease_out(float x) {
    float y = 1.0 - x;
    return 1.0 - y * y * y;
}

// Coverage of a ring of radius r: antialiased core plus a soft glow
float
ring(float dist, float r) {
    float e = abs(dist - r);
    float core = 1.0 - smoothstep(RING_WIDTH - 0.5, RING_WIDTH + 0.5, e);
    float glow = 0.35 * exp(-e * e / (GLOW * GLOW));
    return max(core, glow);
}

// src-over on straight (non-premultiplied) alpha, which is what kitty passes
// through the pipeline
float4
over(float4 dst, float3 rgb, float a) {
    float out_a = a + dst.a * (1.0 - a);
    return float4((rgb * a + dst.rgb * dst.a * (1.0 - a)) / max(out_a, 1e-4), out_a);
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 px = float2(d.viewport_size_pixels) * t.viewport.zw;
    float2 delta = (t.pos - d.mouse_pos.zw) * px;
    float dist = length(delta);
    if (dist > MAX_RADIUS + 3.0 * GLOW + REFRACTION) return color;
    float p = t.animation_progress;

    if (STYLE == 1) {
        float span = 1.0 - float(SONAR_RINGS - 1) * SONAR_STAGGER;
        float cov = 0.0;
        for (int i = 0; i < SONAR_RINGS; i++) {
            float q = saturate((p - float(i) * SONAR_STAGGER) / span);
            if (q <= 0.0) continue;
            float fade = 1.0 - q;
            cov = max(cov, ring(dist, MAX_RADIUS * ease_out(q)) * fade);
        }
        return over(color, RING_COLOR, cov * RING_OPACITY);
    }

    float r = MAX_RADIUS * ease_out(p);
    float fade = 1.0 - p;

    if (STYLE == 2) {
        // Derivative-of-Gaussian profile: pixels on both sides of the rim sample
        // from towards it, so the text bulges like it is seen through a lens
        float e = dist - r;
        float s = GLOW * 1.5;
        float bend = -(e / s) * exp(0.5 - e * e / (2.0 * s * s));
        float2 dir = delta / max(dist, 1e-4);
        float2 offset = dir * bend * REFRACTION * fade / px;
        float4 refracted = t.backbuffer.Sample(t.pos + offset); // premultiplied
        refracted.rgb /= max(refracted.a, 1e-4);
        return over(refracted, RING_COLOR, ring(dist, r) * fade * RING_OPACITY * 0.5);
    }

    return over(color, RING_COLOR, ring(dist, r) * fade * RING_OPACITY);
}
