#version 3.7;

global_settings {
  max_trace_level 12
  assumed_gamma 1.0
  ambient_light rgb <0.018, 0.022, 0.030>
}

// ── Camera — lower, more dramatic angle ──────────────────────────────────────
camera {
  perspective
  location <12.0, 7.5, -16.0>
  look_at  <0, 0.55, 0>
  right x * image_width / image_height
  angle 42
}

// ── Lights ──────────────────────────────────────────────────────────────────
light_source {
  <-4, 30, -8>  color rgb <0.98, 0.93, 1.00> * 2.8
  spotlight  point_at <0, 0.5, 0>  radius 16  falloff 30  tightness 10
}
light_source { <-18, 7, -10>  color rgb <0.30, 0.44, 0.80> * 0.24 }
light_source { <14,  4,  18>  color rgb <0.80, 0.54, 0.28> * 0.14 }

// ── Environment ──────────────────────────────────────────────────────────────
plane {
  y, -0.15
  pigment { color rgb <0.035, 0.040, 0.052> }
  finish { ambient 0 diffuse 0.55 specular 0.14 roughness 0.08 reflection 0.14 }
}
plane {
  z, 24
  pigment { color rgb <0.012, 0.015, 0.020> }
  finish { ambient 0 diffuse 0.4 }
}

// ── Base slab ────────────────────────────────────────────────────────────────
#declare SlabW = 6.0;
difference {
  box { <-SlabW, -0.14, -SlabW>, <SlabW, 0.00, SlabW> }
  box { <-SlabW+0.14, -0.15, -SlabW+0.14>, <SlabW-0.14, 0.01, SlabW-0.14> }
  pigment { color rgb <0.055, 0.062, 0.085> }
  finish { ambient 0 diffuse 0.50 specular 0.94 roughness 0.012 reflection 0.36 metallic }
}
box {
  <-SlabW+0.14, -0.001, -SlabW+0.14>, <SlabW-0.14, 0.001, SlabW-0.14>
  pigment { color rgb <0.028, 0.032, 0.044> }
  finish { ambient 0 diffuse 0.60 specular 0.25 roughness 0.09 reflection 0.08 }
}

// ── Macro: solid pie wedge via prism ─────────────────────────────────────────
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

// ── Dataset: quarterly revenue ───────────────────────────────────────────────
#declare NSlices    = 4;
#declare Vals       = array[4] { 35, 25, 22, 18 }
#declare Labels     = array[4] { "Q1  35%", "Q2  25%", "Q3  22%", "Q4  18%" }
#declare Total      = 100;
#declare PieR       = 3.40;
#declare PieH       = 1.05;
#declare ArcRes     = 36;
#declare Gap        = 0.70;
#declare ExplodeDst = 0.72;   // radial pull distance for highlighted slice

// Vivid warm-cool palette: coral / sky / teal / gold
#declare Col = array[4] {
  rgb <0.96, 0.32, 0.18>,
  rgb <0.16, 0.56, 0.96>,
  rgb <0.08, 0.76, 0.64>,
  rgb <0.96, 0.74, 0.08>
}

// ── Render slices ─────────────────────────────────────────────────────────────
#declare CumA = 0;
#declare I = 0;
#while (I < NSlices)
  #declare WDeg = Vals[I] / Total * 360;
  #declare SA   = CumA + Gap;
  #declare EA   = CumA + WDeg - Gap;
  #declare MidR = (CumA + WDeg * 0.5) * pi / 180;

  // Pull the first (largest) slice outward
  #declare Expl = 0;
  #if (I = 0) #declare Expl = ExplodeDst; #end

  object {
    PieWedge(PieR, PieH, SA, EA, ArcRes)
    texture {
      pigment {
        gradient y
        color_map {
          [0.00  color Col[I] * 0.50]
          [0.65  color Col[I]]
          [1.00  color Col[I] * 1.18]
        }
        scale PieH
      }
      finish {
        ambient 0.04  diffuse 0.76
        specular 0.75  roughness 0.032
        reflection { 0.08, 0.26 fresnel on }
      }
    }
    translate <Expl * cos(MidR), 0, Expl * sin(MidR)>
  }

  // Glow halo ring around exploded slice (top edge)
  #if (I = 0)
    // Leader line from original edge to pulled slice
    cylinder {
      <PieR * 0.5 * cos(MidR), 0.02, PieR * 0.5 * sin(MidR)>,
      <(PieR * 0.5 + Expl) * cos(MidR), 0.02, (PieR * 0.5 + Expl) * sin(MidR)>,
      0.018
      pigment { color rgb <1.0, 0.9, 0.7> * 0.6 }
      finish { ambient 0.50 diffuse 0.50 }
    }
  #end

  // Label indicator on slice top
  sphere {
    <(Expl + PieR * 0.58) * cos(MidR), PieH + 0.11, (Expl + PieR * 0.58) * sin(MidR)>, 0.13
    pigment { color Col[I] * 1.6 }
    finish { ambient 0.30 diffuse 0.70 specular 1.0 roughness 0.016 }
  }

  #declare CumA = CumA + WDeg;
#declare I = I + 1;
#end

// ── Chrome rim ring (bottom only — exploded top looks cleaner without) ────────
torus {
  PieR + 0.042, 0.046
  pigment { color rgb <0.80, 0.84, 0.94> }
  finish { ambient 0.07 diffuse 0.50 specular 1.0 roughness 0.010 reflection 0.54 metallic }
}

// ── "Exploded" callout arc around the pulled slice ────────────────────────────
// Dashed arc drawn as a thin torus segment approximating the Q1 extent
#declare ArcS = Gap * pi / 180;
#declare ArcE = (Vals[0] / Total * 360 - Gap) * pi / 180;
#declare ArcSteps = 18;
#declare ArcSt = 0;
#while (ArcSt < ArcSteps)
  #declare T0 = ArcS + ArcSt * (ArcE - ArcS) / ArcSteps;
  #declare T1 = ArcS + (ArcSt + 0.6) * (ArcE - ArcS) / ArcSteps;
  #declare R1 = PieR + 0.32 + ExplodeDst;
  cylinder {
    <R1 * cos(T0), PieH * 0.5, R1 * sin(T0)>,
    <R1 * cos(T1), PieH * 0.5, R1 * sin(T1)>,
    0.022
    pigment { color rgb <1.0, 0.88, 0.60> * 0.75 }
    finish { ambient 0.45 diffuse 0.55 specular 0.6 roughness 0.04 }
  }
#declare ArcSt = ArcSt + 1;
#end

// ── Legend ────────────────────────────────────────────────────────────────────
#declare LX = PieR + 1.10;
#declare I = 0;
#while (I < NSlices)
  #declare LZ = -1.40 + I * 0.82;
  box {
    <LX, 0.01, LZ - 0.22>, <LX + 0.38, 0.32, LZ + 0.22>
    pigment { color Col[I] }
    finish { ambient 0.12 diffuse 0.78 specular 0.50 roughness 0.06 }
  }
  text {
    ttf "crystal.ttf" Labels[I] 0.04, 0
    scale <0.28, 0.28, 0.05>
    rotate <90, 0, 0>
    translate <LX + 0.50, 0.26, LZ + 0.14>
    pigment { color rgb <0.82, 0.86, 0.98> }
    finish { ambient 0.40 diffuse 0.60 }
  }
#declare I = I + 1;
#end

// ── Title ─────────────────────────────────────────────────────────────────────
text {
  ttf "crystal.ttf" "Quarterly Revenue" 0.04, 0
  scale <0.36, 0.36, 0.05>
  rotate <90, 0, 0>
  translate <-2.80, 0.005, -PieR - 0.90>
  pigment { color rgb <0.76, 0.80, 0.98> }
  finish { ambient 0.45 diffuse 0.55 }
}
