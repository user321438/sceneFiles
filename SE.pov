#version 3.7;

global_settings {
  max_trace_level 12
  assumed_gamma 1.0
  ambient_light rgb <0, 0, 0>
}

camera {
  perspective
  location <-4.5, 3.7, -7.0>
  look_at  <0, 0.4, 0.5>
  right x * image_width / image_height
  angle 48
}

light_source {
  <-5.5, 3.5, -0.5>
  color rgb <1.0, 0.97, 0.94> * 2.2
  spotlight
  point_at <4.0, -1.2, 0>
  radius 30
  falloff 50
  tightness 5
}

plane {
  z, 20
  pigment { color rgb <0.03, 0.035, 0.04> }
  finish { ambient 0.0 diffuse 0.5 }
}

plane {
  y, 0
  pigment { color rgb <0.06, 0.065, 0.07> }
  finish {
    ambient 0.0
    diffuse 0.6
    specular 0.15
    roughness 0.08
    reflection { 0.08 }
  }
}

#declare DiscRadius = 6.0;
#declare DiscHeight = 0.15;

cylinder {
  <0, 0, 0>, <0, DiscHeight, 0>, DiscRadius
  texture {
    pigment {
      brick
        color rgb <0.75, 0.04, 0.04>
        color rgb <0.04, 0.045, 0.05>
      brick_size <0.5, 0.1, 0.25>
      mortar 0.02
    }
    finish {
      ambient 0.0
      diffuse 0.35
      specular 0.7
      roughness 0.008
      reflection { 0.6 }
      metallic
    }
  }
}

difference {
  cylinder { <0, 0, 0>, <0, DiscHeight, 0>, DiscRadius }
  cylinder { <0, -0.01, 0>, <0, DiscHeight + 0.01, 0>, DiscRadius - 0.15 }
  texture {
    pigment { color rgb <0.03, 0.035, 0.04> }
    finish {
      ambient 0.0
      diffuse 0.4
      specular 0.5
      roughness 0.02
      reflection { 0.2 }
    }
  }
}

torus {
  DiscRadius * 0.78, 0.05
  translate y * (DiscHeight + 0.005)
  texture {
    pigment { color rgb <0.15, 0.16, 0.18> }
    finish {
      ambient 0.0
      diffuse 0.35
      specular 0.6
      roughness 0.01
      reflection { 0.4 }
      metallic
    }
  }
}

torus {
  DiscRadius - 0.08, 0.06
  translate y * DiscHeight
  texture {
    pigment { color rgb <0.45, 0.47, 0.50> }
    finish {
      ambient 0.0
      diffuse 0.3
      specular 0.9
      roughness 0.004
      reflection { 0.7 }
      metallic
    }
  }
}

// ── Shared text texture ────────────────────────────────────────────────────────
#declare TxtTex = texture {
  pigment { color rgb <0.88, 0.92, 1.00> }
  finish {
    ambient 0.05  diffuse 0.60
    specular 1.0  roughness 0.012
    reflection { 0.30, 0.58 fresnel on }
    metallic
  }
}

// ── "Solution" — top line ──────────────────────────────────────────────────────
text {
  ttf "crystal.ttf" "Solution" 0.45, 0
  scale 1.10
  translate <-1.94, 1.65, -0.12>
  texture { TxtTex }
}

// ── "Engineering" — bottom line ────────────────────────────────────────────────
text {
  ttf "crystal.ttf" "Engineering" 0.45, 0
  scale 1.10
  translate <-2.64, 0.60, -0.12>
  texture { TxtTex }
}
