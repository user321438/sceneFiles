#version 3.7;

global_settings {
  max_trace_level 12
  assumed_gamma 1.0
  ambient_light rgb <0.016, 0.020, 0.030>
}

// ── Camera — slightly steeper to show ring shape ──────────────────────────────
camera {
  perspective
  location <9.5, 11.0, -14.5>
  look_at  <0, 0.50, 0>
  right x * image_width / image_height
  angle 38
}

// ── Lights ──────────────────────────────────────────────────────────────────
light_source {
  <4, 30, -5>  color rgb <0.96, 0.98, 1.00> * 2.8
  spotlight  point_at <0, 0.4, 0>  radius 12  falloff 26  tightness 10
}
light_source { <-18, 9, -12>  color rgb <0.26, 0.42, 0.80> * 0.24 }
light_source { <12,  4,  18>  color rgb <0.70, 0.46, 0.88> * 0.16 }

// ── Environment ──────────────────────────────────────────────────────────────
plane {
  y, -0.15
  pigment { color rgb <0.032, 0.038, 0.052> }
  finish { ambient 0 diffuse 0.52 specular 0.14 roughness 0.08 reflection 0.14 }
}
plane {
  z, 22
  pigment { color rgb <0.012, 0.014, 0.020> }
  finish { ambient 0 diffuse 0.4 }
}

// ── Base slab ────────────────────────────────────────────────────────────────
#declare SlabW = 5.4;
difference {
  box { <-SlabW, -0.14, -SlabW>, <SlabW, 0.00, SlabW> }
  box { <-SlabW+0.14, -0.15, -SlabW+0.14>, <SlabW-0.14, 0.01, SlabW-0.14> }
  pigment { color rgb <0.055, 0.064, 0.088> }
  finish { ambient 0 diffuse 0.50 specular 0.94 roughness 0.012 reflection 0.36 metallic }
}
box {
  <-SlabW+0.14, -0.001, -SlabW+0.14>, <SlabW-0.14, 0.001, SlabW-0.14>
  pigment { color rgb <0.028, 0.032, 0.046> }
  finish { ambient 0 diffuse 0.60 specular 0.26 roughness 0.09 reflection 0.08 }
}

// ── Macro: donut ring segment via prism + inverse cylinder ───────────────────
#macro DonutWedge(Rout, Rin, H, StartDeg, EndDeg, NSides)
  #local dA = (EndDeg - StartDeg) / NSides;
  intersection {
    prism {
      linear_sweep  linear_spline
      0, H,  NSides + 3,
      <0, 0>,
      #local S = 0;
      #while (S <= NSides)
        #local A = (StartDeg + S * dA) * pi / 180;
        <Rout * cos(A), Rout * sin(A)>,
      #local S = S + 1;
      #end
      <0, 0>
    }
    cylinder { <0, -0.001, 0>, <0, H+0.001, 0>, Rin  inverse }
  }
#end

// ── Dataset: regional market share ───────────────────────────────────────────
#declare NSlices = 4;
#declare Vals    = array[4] { 35, 28, 22, 15 }
#declare Labels  = array[4] { "Asia-Pacific 35%", "Americas     28%", "Europe       22%", "Rest         15%" }
#declare Total   = 100;
#declare Rout    = 3.20;
#declare Rin     = 1.75;
#declare PieH    = 0.80;
#declare ArcRes  = 40;
#declare Gap     = 0.65;

// Neon-on-dark palette: electric blue / hot magenta / neon teal / vivid lime
#declare Col = array[4] {
  rgb <0.14, 0.46, 0.98>,
  rgb <0.92, 0.16, 0.62>,
  rgb <0.04, 0.84, 0.72>,
  rgb <0.72, 0.94, 0.12>
}

// ── Render ring segments ──────────────────────────────────────────────────────
#declare CumA = 0;
#declare I = 0;
#while (I < NSlices)
  #declare WDeg = Vals[I] / Total * 360;
  #declare SA   = CumA + Gap;
  #declare EA   = CumA + WDeg - Gap;
  object {
    DonutWedge(Rout, Rin, PieH, SA, EA, ArcRes)
    texture {
      pigment {
        gradient y
        color_map {
          [0.00  color Col[I] * 0.45]
          [0.60  color Col[I] * 0.90]
          [1.00  color Col[I] * 1.20]
        }
        scale PieH
      }
      finish {
        ambient 0.04  diffuse 0.74
        specular 0.80  roughness 0.028
        reflection { 0.10, 0.30 fresnel on }
      }
    }
  }
  // Outer edge glow cylinder strip (thin emissive arc for neon look)
  #declare MidR = (CumA + WDeg * 0.5) * pi / 180;
  sphere {
    <(Rout + 0.12) * cos(MidR), PieH * 0.50, (Rout + 0.12) * sin(MidR)>, 0.10
    pigment { color Col[I] * 2.0 }
    finish { ambient 0.50 diffuse 0.50 specular 1.0 roughness 0.012 }
  }
  #declare CumA = CumA + WDeg;
#declare I = I + 1;
#end

// ── Center hub (dark metallic cylinder fills the hole) ────────────────────────
cylinder {
  <0, 0.0, 0>, <0, PieH, 0>, Rin - 0.08
  pigment { color rgb <0.040, 0.048, 0.068> }
  finish { ambient 0.06 diffuse 0.50 specular 0.55 roughness 0.045 reflection 0.30 }
}
// Hub top disc
cylinder {
  <0, PieH, 0>, <0, PieH + 0.012, 0>, Rin - 0.08
  pigment { color rgb <0.060, 0.072, 0.100> }
  finish { ambient 0.10 diffuse 0.50 specular 0.70 roughness 0.030 reflection 0.40 }
}
// Center pin sphere
sphere {
  <0, PieH + 0.14, 0>, 0.18
  pigment { color rgb <0.80, 0.84, 0.94> }
  finish { ambient 0.12 diffuse 0.55 specular 1.0 roughness 0.010 reflection 0.55 metallic }
}

// ── Chrome outer rim ─────────────────────────────────────────────────────────
torus {
  Rout + 0.042, 0.046
  pigment { color rgb <0.80, 0.84, 0.94> }
  finish { ambient 0.07 diffuse 0.48 specular 1.0 roughness 0.010 reflection 0.56 metallic }
}
torus {
  Rout + 0.042, 0.046
  translate y * PieH
  pigment { color rgb <0.80, 0.84, 0.94> }
  finish { ambient 0.07 diffuse 0.48 specular 1.0 roughness 0.010 reflection 0.56 metallic }
}
// Inner rim
torus {
  Rin - 0.09, 0.034
  pigment { color rgb <0.72, 0.76, 0.88> }
  finish { ambient 0.07 diffuse 0.46 specular 1.0 roughness 0.012 reflection 0.50 metallic }
}
torus {
  Rin - 0.09, 0.034
  translate y * PieH
  pigment { color rgb <0.72, 0.76, 0.88> }
  finish { ambient 0.07 diffuse 0.46 specular 1.0 roughness 0.012 reflection 0.50 metallic }
}

// ── Legend ────────────────────────────────────────────────────────────────────
#declare LX = Rout + 0.90;
#declare I = 0;
#while (I < NSlices)
  #declare LZ = -1.20 + I * 0.80;
  box {
    <LX, 0.01, LZ - 0.20>, <LX + 0.36, 0.28, LZ + 0.20>
    pigment { color Col[I] }
    finish { ambient 0.14 diffuse 0.76 specular 0.55 roughness 0.05 }
  }
  text {
    ttf "crystal.ttf" Labels[I] 0.04, 0
    scale <0.24, 0.24, 0.04>
    rotate <90, 0, 0>
    translate <LX + 0.48, 0.24, LZ + 0.12>
    pigment { color rgb <0.78, 0.84, 1.00> }
    finish { ambient 0.42 diffuse 0.58 }
  }
#declare I = I + 1;
#end

// ── Title ─────────────────────────────────────────────────────────────────────
text {
  ttf "crystal.ttf" "Regional Market Share" 0.04, 0
  scale <0.32, 0.32, 0.05>
  rotate <90, 0, 0>
  translate <-3.00, 0.005, -Rout - 0.90>
  pigment { color rgb <0.70, 0.78, 1.00> }
  finish { ambient 0.46 diffuse 0.54 }
}
