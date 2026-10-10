#version 320 es

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;

// Button width divided by the card width. The neck aims at that button.
uniform float u_button_frac;
uniform float u_progress;
uniform float u_from_right;
uniform float u_opens_above;

out vec4 frag_color;

float ease_out_cubic(float t) {
  float p = 1.0 - t;
  return 1.0 - p * p * p;
}

float ease_in_out_cubic(float t) {
  return t < 0.5
      ? 4.0 * t * t * t
      : 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
#ifdef IMPELLER_TARGET_OPENGLES
  frag.y = u_size.y - frag.y;
#endif
  vec2 uv = frag / u_size;

  float t = clamp(u_progress, 0.0, 1.0);
  float btn = clamp(u_button_frac, 0.04, 0.8);

  // Pinch sits on the button. In this filter, y grows upward, so a card
  // that opens above the button flips y to put the neck on the button.
  vec2 p = uv;
  if (u_opens_above > 0.5) {
    p.y = 1.0 - p.y;
  }
  if (u_from_right < 0.5) {
    p.x = 1.0 - p.x;
  }

  float rise = ease_out_cubic(clamp(t / 0.78, 0.0, 1.0));
  float mouth_spread = ease_in_out_cubic(t);
  // The neck stays on the button, then opens into the card.
  float pinch_spread = smoothstep(0.55, 1.0, t);

  float reveal_h = mix(max(btn * 0.45, 0.06), 1.0, rise);
  float funnel_top = 1.0 - reveal_h;
  float local_v = (p.y - funnel_top) / max(reveal_h, 0.0001);
  float v = clamp(local_v, 0.0, 1.0);

  // After the x flip, the button sits on the right. Its center is inset by
  // half its width — not the card's right edge.
  float btn_cx = 1.0 - btn * 0.5;
  float btn_half = btn * 0.5;
  float mouth_cx = mix(btn_cx, 0.5, mouth_spread);
  float mouth_half = mix(btn_half * 0.92, 0.5, mouth_spread);
  float neck_cx = mix(btn_cx, 0.5, pinch_spread);
  // Wide enough to sit on the disk, still a point compared with the card.
  float neck_half = mix(max(btn_half * 0.42, 0.02), 0.5, pinch_spread);

  // Wide through the body, then both walls curve into the button center.
  float side = pow(v, 1.7);
  float half_w = mix(mouth_half, neck_half, side);
  float cx = mix(mouth_cx, neck_cx, side);
  float bow = sin(v * 3.14159265) * 0.035 * sin(t * 3.14159265);
  bow = min(bow, half_w * 0.4);
  float left = cx - half_w + bow;
  float right = cx + half_w - bow;

  if (p.y < funnel_top || p.y > 1.0 || p.x < left || p.x > right || local_v < 0.0) {
    frag_color = vec4(0.0);
    return;
  }

  float source_u = (p.x - left) / max(right - left, 0.0001);
  // 0 at the far edge, 1 in the neck on the button. The pack eases back to a
  // straight sample so the last warped frame already matches the settled card.
  float v_clamped = clamp(local_v, 0.0, 1.0);
  float squeezed = 1.0 - pow(1.0 - v_clamped, 0.72);
  float straighten = smoothstep(0.68, 1.0, t);
  float along = mix(squeezed, v_clamped, straighten);
  // Card top is texture v = 0. The far edge keeps the title, the neck keeps
  // the actions that sit against the button.
  float source_v = u_opens_above > 0.5 ? along : 1.0 - along;

  if (u_from_right < 0.5) {
    source_u = 1.0 - source_u;
  }

  vec2 src = clamp(vec2(source_u, source_v), vec2(0.0), vec2(1.0));
  float dist = min(min(p.x - left, right - p.x), min(p.y - funnel_top, 1.0 - p.y));
  float fw = 1.5 / max(min(u_size.x, u_size.y), 1.0);
  float alpha = mix(smoothstep(0.0, fw, dist), 1.0, straighten);
  frag_color = texture(u_texture, src) * alpha;
}
