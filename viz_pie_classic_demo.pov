#version 3.7;

global_settings {
  max_trace_level 12
  assumed_gamma 1.0
  ambient_light rgb <0.020, 0.025, 0.035>
}

// ── Camera ──────────────────────────────────────────────────────────────────
camera {
  perspective
  location <10.5, 9.5, -15>
  look_at  <0, 0.65, 0>
  right x * image_width / image_height
  angle 40
}

// ── Lights ──────────────────────────────────────────────────────────────────
light_source {
  <5, 28, -6>  color rgb <1.00, 0.96, 0.90> * 2.6
  spotlight  point_at <0, 0.5, 0>  radius 14  falloff 28  tightness 9
}
light_source { <-16, 8, -14>  color rgb <0.24, 0.40, 0.74> * 0.22 }
light_source { <13,  5,  16>  color rgb <0.74, 0.50, 0.24> * 0.13 }

// ── Environment ──────────────────────────────────────────────────────────────
plane {
  y, -0.15
  pigment { color rgb <0.038, 0.043, 0.054> }
  finish { ambient 0 diffuse 0.55 specular 0.15 roughness 0.07 reflection 0.12 }
}
plane {
  z, 22
  pigment { color rgb <0.015, 0.017, 0.022> }
  finish { ambient 0 diffuse 0.4 }
}

// ── Base slab ────────────────────────────────────────────────────────────────
#declare SlabW = 5.6;
difference {
  box { <-SlabW, -0.14, -SlabW>, <SlabW, 0.00, SlabW> }
  box { <-SlabW+0.14, -0.15, -SlabW+0.14>, <SlabW-0.14, 0.01, SlabW-0.14> }
  pigment { color rgb <0.060, 0.068, 0.090> }
  finish { ambient 0 diffuse 0.50 specular 0.92 roughness 0.013 reflection 0.34 metallic }
}
box {
  <-SlabW+0.14, -0.001, -SlabW+0.14>, <SlabW-0.14, 0.001, SlabW-0.14>
  pigment { color rgb <0.030, 0.034, 0.046> }
  finish { ambient 0 diffuse 0.60 specular 0.28 roughness 0.09 reflection 0.08 }
}

// ── Macro: solid pie wedge via prism ─────────────────────────────────────────
// Angles in degrees; prism cross-section is in the XZ plane.
#macro PieWedge(Rad, H, StartDeg, EndDeg, NSides)
  #local dA = (EndDeg - StartDeg) / NSides;
  prism {
    linear_sweep  linear_spline
    0, H,  NSides + 3,
    <0, 0>,
    #local S = 0;
    #while (S <= NSides)
      #local A = (StartDeg + S * dA) * pi / 180;
      <Rad * cos(A), Rad * sin(A)>,
    #local S = S + 1;
    #end
    <0, 0>
  }
#end

// ── Dataset: annual budget allocation ────────────────────────────────────────
#declare NSlices = 5;
#declare Vals    = array[5] { 28, 32, 18, 12, 10 }
#declare Total   = 100;
#declare PieR    = 3.40;
#declare PieH    = 1.00;
#declare ArcRes  = 36;
#declare Gap     = 0.70;   // degrees trimmed from each side of every slice

// Jewel palette:  crimson / sapphire / emerald / amber / violet
#declare Col = array[5] {
  rgb <0.82, 0.11, 0.17>,
  rgb <0.10, 0.28, 0.90>,
  rgb <0.06, 0.72, 0.34>,
  rgb <0.95, 0.66, 0.04>,
  rgb <0.60, 0.14, 0.88>
}

// ── Render slices ─────────────────────────────────────────────────────────────
#declare CumA = 0;
#declare I = 0;
#while (I < NSlices)
  #declare WDeg = Vals[I] / Total * 360;
  #declare SA   = CumA + Gap;
  #declare EA   = CumA + WDeg - Gap;
  object {
    PieWedge(PieR, PieH, SA, EA, ArcRes)
    texture {
      pigment {
        gradient y
        color_map {
          [0.00  color Col[I] * 0.55]
          [0.68  color Col[I]]
          [1.00  color Col[I] * 1.15]
        }
        scale PieH
      }
      finish {
        ambient 0.04  diffuse 0.78
        specular 0.68  roughness 0.036
        reflection { 0.06, 0.22 fresnel on }
      }
    }
  }
  // Glow indicator on top face at slice midpoint
  #declare MidR = (CumA + WDeg * 0.5) * pi / 180;
  sphere {
    <PieR * 0.60 * cos(MidR), PieH + 0.10, PieR * 0.60 * sin(MidR)>, 0.12
    pigment { color Col[I] * 1.55 }
    finish { ambient 0.28 diffuse 0.72 specular 1.0 roughness 0.018 }
  }
  #declare CumA = CumA + WDeg;
#declare I = I + 1;
#end

// ── Chrome rim rings (top + bottom) ──────────────────────────────────────────
torus {
  PieR + 0.042, 0.046
  pigment { color rgb <0.84, 0.88, 0.96> }
  finish { ambient 0.07 diffuse 0.50 specular 1.0 roughness 0.010 reflection 0.52 metallic }
}
torus {
  PieR + 0.042, 0.046
  translate y * PieH
  pigment { color rgb <0.84, 0.88, 0.96> }
  finish { ambient 0.07 diffuse 0.50 specular 1.0 roughness 0.010 reflection 0.52 metallic }
}

// ── Legend swatches (right side of slab) ─────────────────────────────────────
#declare Labels = array[5] { "Marketing  28%", "Engineering 32%", "Sales       18%", "Operations 12%", "R&D        10%" }
#declare LX = PieR + 1.00;
#declare I = 0;
#while (I < NSlices)
  #declare LZ = -1.60 + I * 0.80;
  box {
    <LX, 0.01, LZ - 0.22>, <LX + 0.38, 0.32, LZ + 0.22>
    pigment { color Col[I] }
    finish { ambient 0.12 diffuse 0.78 specular 0.50 roughness 0.06 }
  }
  text {
    ttf "crystal.ttf" Labels[I] 0.04, 0
    scale <0.26, 0.26, 0.05>
    rotate <90, 0, 0>
    translate <LX + 0.48, 0.26, LZ + 0.14>
    pigment { color rgb <0.80, 0.84, 0.96> }
    finish { ambient 0.40 diffuse 0.60 }
  }
#declare I = I + 1;
#end

// ── Title ─────────────────────────────────────────────────────────────────────
text {
  ttf "crystal.ttf" "Annual Budget Allocation" 0.04, 0
  scale <0.34, 0.34, 0.05>
  rotate <90, 0, 0>
  translate <-3.20, 0.005, -PieR - 0.80>
  pigment { color rgb <0.72, 0.78, 0.96> }
  finish { ambient 0.45 diffuse 0.55 }
}
