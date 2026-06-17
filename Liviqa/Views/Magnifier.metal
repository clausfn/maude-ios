//  Magnifier.metal — the Flighty tab-bar lens.
//  A SwiftUI layerEffect shader that, inside a horizontal CAPSULE region centred on
//  the finger, MAGNIFIES the tab-bar pixels behind it and splits the RGB channels
//  radially toward the rim (chromatic aberration), with a faint glass body + edge
//  highlight. Outside the capsule it passes the layer through untouched.
//
//  Real pixel work (not the frosted .glassEffect), so it renders the same on the
//  Simulator and on device, and works on the iOS 17 floor (layerEffect is iOS 17+).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 tabMagnifier(float2 pos, SwiftUI::Layer layer,
                   float2 center, float halfLen, float capR,
                   float mag, float ca) {
    // Capsule signed distance: a horizontal segment of half-length `halfLen`,
    // inflated by `capR`. Inside ⇔ dist < capR.
    float2 q = pos - center;
    float dx = max(abs(q.x) - halfLen, 0.0);
    float dist = length(float2(dx, q.y));

    half4 base = layer.sample(pos);
    if (dist > capR) { return base; }                 // outside the lens

    float t = clamp(dist / capR, 0.0, 1.0);           // 0 centre … 1 rim

    // Magnify: sample from a point pulled toward the centre.
    float2 rel = pos - center;
    float2 src = center + rel / mag;

    // Chromatic aberration: offset R/B radially, strongest near the rim.
    float len = length(rel);
    float2 dir = (len > 0.001) ? rel / len : float2(0.0, 0.0);
    float caAmt = ca * t * t;

    half4 col;
    col.r = layer.sample(src + dir * caAmt).r;
    col.g = layer.sample(src).g;
    col.b = layer.sample(src - dir * caAmt).b;
    col.a = layer.sample(src).a;

    // Faint glass body so the capsule reads even between icons.
    col.rgb = mix(col.rgb, half3(0.82h), 0.06h);
    col.a = max(col.a, 0.10h);

    // Specular edge highlight on the rim.
    float rim = smoothstep(capR - 3.0, capR, dist);
    col.rgb += half3(rim) * 0.30h;
    col.a = max(col.a, half(rim) * 0.55h);

    return col;
}
