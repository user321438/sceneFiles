#version 3.7;

global_settings {
  max_trace_level 12
  assumed_gamma 1.0
  ambient_light rgb <0.008, 0.010, 0.014>
}

// ── Camera — steeper angle to read concentric rings ───────────────────────────
camera {
  perspective
  location <6.5, 11.5, -16.0>
  look_at  <0, 0.50, 0>
  right x * image_width / image_height
  angle 42
}

// ── Lights ──────────────────────────────────────────────────────────────────
light_source {
  <-16, 18, 6>  color rgb <1.00, 0.96, 0.88> * 1.95
  spotlight  point_at <0, 0.5, 0>  radius 13  falloff 16  tightness 24
}
light_source { <-16, 8, -12>  color rgb <0.22, 0.38, 0.76> * 0.045 }
light_source { <10,  4,  18>  color rgb <0.80, 0.56, 0.22> * 0.03 }

// ── Environment ──────────────────────────────────────────────────────────────
plane {
  y, -0.15
  pigment { color rgb <0.034, 0.040, 0.054> }
  finish { ambient 0 diffuse 0.52 specular 0.14 roughness 0.08 reflection 0.13 }
}
plane {
  z, 22
  pigment { color rgb <0.013, 0.015, 0.020> }
  finish { ambient 0 diffuse 0.4 }
}

// ── Base slab ────────────────────────────────────────────────────────────────
#declare SlabW = 5.8;
difference {
  box { <-SlabW, -0.14, -SlabW>, <SlabW, 0.00, SlabW> }
  box { <-SlabW+0.14, -0.15, -SlabW+0.14>, <SlabW-0.14, 0.01, SlabW-0.14> }
  pigment { color rgb <0.058, 0.066, 0.090> }
  finish { ambient 0 diffuse 0.50 specular 0.92 roughness 0.013 reflection 0.34 metallic }
}
box {
  <-SlabW+0.14, -0.001, -SlabW+0.14>, <SlabW-0.14, 0.001, SlabW-0.14>
  pigment { color rgb <0.028, 0.032, 0.044> }
  finish { ambient 0 diffuse 0.60 specular 0.26 roughness 0.09 reflection 0.08 }
}

// ── Macro: donut ring segment ─────────────────────────────────────────────────
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

// ── Ring geometry ─────────────────────────────────────────────────────────────
#declare InRin  = 0.62;
#declare InRout = 2.00;
#declare InH    = 1.00;

#declare OuRin  = 2.18;
#declare OuRout = 3.80;
#declare OuH    = 0.72;   // thinner outer ring shows hierarchy

#declare ArcRes = 40;
#declare GapI   = 0.65;   // gap for inner ring segments (degrees each side)
#declare GapO   = 0.40;   // tighter gap for outer ring (more segments)

// ── Inner ring: 3 categories ──────────────────────────────────────────────────
// A=40%  B=35%  C=25%   (sum=100)
// Angles: A=144°  B=126°  C=90°
// Cumulative: A starts at 0°, B at 144°, C at 270°

// Inner palette: cobalt / teal / amber
#declare InCol = array[3] {
  rgb <0.14, 0.26, 0.84>,
  rgb <0.06, 0.70, 0.62>,
  rgb <0.92, 0.64, 0.06>
}
#declare InStart = array[3] { 0.0,   144.0, 270.0 }
#declare InEnd   = array[3] { 144.0, 270.0, 360.0 }

#declare I = 0;
#while (I < 3)
  object {
    DonutWedge(InRout, InRin, InH, InStart[I] + GapI, InEnd[I] - GapI, ArcRes)
    texture {
      pigment {
        gradient y
        color_map {
          [0.00  color InCol[I] * 0.52]
          [0.65  color InCol[I]]
          [1.00  color InCol[I] * 1.16]
        }
        scale InH
      }
      finish {
        ambient 0.04  diffuse 0.76
        specular 0.70  roughness 0.034
        reflection { 0.08, 0.24 fresnel on }
      }
    }
  }
#declare I = I + 1;
#end

// ── Outer ring: 6 subcategories ───────────────────────────────────────────────
// Derived from inner:
//   A split: A1=22% (0→79.2°)   A2=18% (79.2→144°)
//   B split: B1=20% (144→216°)  B2=15% (216→270°)
//   C split: C1=14% (270→320.4°) C2=11% (320.4→360°)

// Outer palette: lighter/darker variants of inner hues
#declare OuCol = array[6] {
  rgb <0.28, 0.44, 0.92>,   // A1 — lighter cobalt
  rgb <0.08, 0.18, 0.72>,   // A2 — deeper cobalt
  rgb <0.10, 0.84, 0.72>,   // B1 — bright teal
  rgb <0.04, 0.54, 0.50>,   // B2 — dark teal
  rgb <0.98, 0.80, 0.14>,   // C1 — bright gold
  rgb <0.76, 0.50, 0.04>    // C2 — deep gold
}
#declare OuStart = array[6] {   0.0,  79.2, 144.0, 216.0, 270.0, 320.4 }
#declare OuEnd   = array[6] {  79.2, 144.0, 216.0, 270.0, 320.4, 360.0 }

#declare I = 0;
#while (I < 6)
  object {
    DonutWedge(OuRout, OuRin, OuH, OuStart[I] + GapO, OuEnd[I] - GapO, ArcRes)
    texture {
      pigment {
        gradient y
        color_map {
          [0.00  color OuCol[I] * 0.50]
          [0.60  color OuCol[I] * 0.92]
          [1.00  color OuCol[I] * 1.18]
        }
        scale OuH
      }
      finish {
        ambient 0.04  diffuse 0.74
        specular 0.65  roughness 0.038
        reflection { 0.07, 0.22 fresnel on }
      }
    }
  }
#declare I = I + 1;
#end

// ── Center hub ────────────────────────────────────────────────────────────────
cylinder {
  <0, 0.00, 0>, <0, InH, 0>, InRin - 0.06
  pigment { color rgb <0.040, 0.050, 0.070> }
  finish { ambient 0.06 diffuse 0.50 specular 0.55 roughness 0.04 reflection 0.32 }
}
sphere {
  <0, InH + 0.16, 0>, 0.22
  pigment { color rgb <0.82, 0.86, 0.96> }
  finish { ambient 0.12 diffuse 0.52 specular 1.0 roughness 0.009 reflection 0.58 metallic }
}

// ── Chrome rim rings ─────────────────────────────────────────────────────────
// Outer ring rims
torus {
  OuRout + 0.042, 0.044
  pigment { color rgb <0.82, 0.86, 0.96> }
  finish { ambient 0.07 diffuse 0.48 specular 1.0 roughness 0.010 reflection 0.54 metallic }
}
torus {
  OuRout + 0.042, 0.044
  translate y * OuH
  pigment { color rgb <0.82, 0.86, 0.96> }
  finish { ambient 0.07 diffuse 0.48 specular 1.0 roughness 0.010 reflection 0.54 metallic }
}
// Gap ring (between inner and outer at the top of inner)
torus {
  InRout + 0.06, 0.030
  translate y * InH
  pigment { color rgb <0.68, 0.72, 0.84> }
  finish { ambient 0.06 diffuse 0.46 specular 1.0 roughness 0.014 reflection 0.46 metallic }
}

// ── Radial separator lines (thin cylinders from hub to outer edge) ─────────────
// Mark the 3 main category boundaries
#declare SepAngles = array[3] { 0.0, 144.0, 270.0 }
#declare K = 0;
#while (K < 3)
  #declare SA_rad = SepAngles[K] * pi / 180;
  cylinder {
    <InRin * cos(SA_rad), InH + 0.02, InRin * sin(SA_rad)>,
    <OuRout * cos(SA_rad), InH + 0.02, OuRout * sin(SA_rad)>,
    0.016
    pigment { color rgb <0.60, 0.64, 0.76> * 0.55 }
    finish { ambient 0.30 diffuse 0.70 }
  }
#declare K = K + 1;
#end

// ── Inner ring indicator dots (midpoint of each inner segment) ────────────────
#declare InMid = array[3] { 72.0, 207.0, 315.0 }
#declare K = 0;
#while (K < 3)
  #declare MR = InMid[K] * pi / 180;
  #declare DR = (InRin + InRout) * 0.5;
  sphere {
    <DR * cos(MR), InH + 0.12, DR * sin(MR)>, 0.14
    pigment { color InCol[K] * 1.55 }
    finish { ambient 0.28 diffuse 0.72 specular 1.0 roughness 0.016 }
  }
#declare K = K + 1;
#end

// ── Legend ────────────────────────────────────────────────────────────────────
#declare InLabels = array[3] { "Tech   40%", "Health 35%", "Energy 25%" }
#declare LX = OuRout + 0.80;
#declare K = 0;
#while (K < 3)
  #declare LZ = -0.80 + K * 0.82;
  box {
    <LX, 0.01, LZ - 0.20>, <LX + 0.36, 0.28, LZ + 0.20>
    pigment { color InCol[K] }
    finish { ambient 0.14 diffuse 0.76 specular 0.50 roughness 0.06 }
  }
  text {
    ttf "crystal.ttf" InLabels[K] 0.10, 0
    scale <0.26, 0.26, 0.14>
    rotate <90, 0, 0>
    translate <LX + 0.50, 0.24, LZ + 0.12>
    pigment { color rgb <0.80, 0.86, 1.00> }
    finish { ambient 0.42 diffuse 0.58 }
  }
#declare K = K + 1;
#end

// ── Title ─────────────────────────────────────────────────────────────────────
text {
  ttf "crystal.ttf" "Portfolio Allocation" 0.20, 0
  scale <0.52, 0.52, 0.30>
  rotate <90, 0, 0>
  translate <-3.20, 0.005, -OuRout - 1.10>
  pigment { color rgb <0.76, 0.82, 1.00> }
  finish { ambient 0.46 diffuse 0.54 }
}
