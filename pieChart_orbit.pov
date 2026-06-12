// ?????????????????????????????????????????????????????????????????????????????
// Orbit Scene ? Generated 2026-06-12 10:05:23
// Source:  C:\0000-Files\9999-PovRay\Scenes\working\pieChart.pov
// Mode:    Slow Rise and Hover (v7)
// Rise:    45%  Pullback: -12%
// Hover:   ?8.1?  Cycles: 6  Speed: 0.1
// ?????????????????????????????????????????????????????????????????????????????

// ?????????????????????????????????????????????????????????????????????????????
// Pie Scene ? Generated 2026-05-27 13:40:22
// Template: C:\0000-Files\9999-PovRay\Scenes\working\pie_chart_template.pov
// CSV:      C:\0000-Files\0009-Work\0000-GitHub\renderDotnet\PovCliNet.Web\templateData\pieChart\pie_market_share.csv
// Radius:   4  Height: 1  Style: V1 Solid  Position: Flat
// Start:    0?
// ?????????????????????????????????????????????????????????????????????????????




#version 3.7;

global_settings {
  max_trace_level 12
  assumed_gamma 1.0
  ambient_light rgb <0.12, 0.12, 0.15>
}








light_source {
  <0, 18, 4>
  color rgb <1.0, 0.97, 0.94> * 1.8
  spotlight
  point_at <0, 0, 0>
  radius 15
  falloff 30
  tightness 8
}


light_source {
  <-8, 6, -8>
  color rgb <0.50, 0.55, 0.65> * 0.12
}


light_source {
  <7, 4, -4>
  color rgb <0.45, 0.48, 0.55> * 0.08
}




plane {
  z, 18
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



#declare DiscRadius = 5.5;
#declare DiscHeight = 0.12;
#declare DiscReflectivity = 1.0000;


cylinder {
  <0, 0, 0>, <0, DiscHeight, 0>, DiscRadius
  texture {
    pigment {
      brick
        color rgb <0.07, 0.08, 0.09>
        color rgb <0.04, 0.045, 0.05>
      brick_size <0.5, 0.1, 0.25>
      mortar 0.02
    }
    finish {
      ambient 0.0
      diffuse 0.35
      specular 0.7
      roughness 0.008
      reflection { 0.6 * DiscReflectivity }
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
      reflection { 0.2 * DiscReflectivity }
    }
  }
}


torus {
  DiscRadius * 0.85, 0.05
  translate y * (DiscHeight + 0.005)
  texture {
    pigment { color rgb <0.15, 0.16, 0.18> }
    finish {
      ambient 0.0
      diffuse 0.35
      specular 0.6
      roughness 0.01
      reflection { 0.4 * DiscReflectivity }
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
      reflection { 0.7 * DiscReflectivity }
      metallic
    }
  }
}



#macro DataPie(Placeholder)
#end
// Slice 0: Apple (31.2%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 1.9000, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 1.9000, 0>, <0, 2.2500, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 1.9000, 0> }
  }
  plane { <0.0000, 0, -1.0000>, -0.0000 }
  plane { <-0.9251, 0, -0.3798>, -0.0000 }
  texture {
    pigment { color rgb <0.2000, 0.6000, 0.8600> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate <0.3341, 0, 0.4984>
  translate y * DiscHeight
}

// Slice 1: Samsung (20.8%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 1.5250, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 1.5250, 0>, <0, 1.8750, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 1.5250, 0> }
  }
  plane { <0.9251, 0, 0.3798>, -0.0000 }
  plane { <0.1253, 0, -0.9921>, -0.0000 }
  texture {
    pigment { color rgb <0.9500, 0.4500, 0.1400> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}

// Slice 2: Xiaomi (12.5%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 1.1500, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 1.1500, 0>, <0, 1.5000, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 1.1500, 0> }
  }
  plane { <-0.1253, 0, 0.9921>, -0.0000 }
  plane { <0.7902, 0, -0.6129>, -0.0000 }
  texture {
    pigment { color rgb <0.1700, 0.7300, 0.3700> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}

// Slice 3: OPPO (9.7%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 1.0000, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 1.0000, 0>, <0, 1.3500, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 1.0000, 0> }
  }
  plane { <-0.7902, 0, 0.6129>, -0.0000 }
  plane { <0.9987, 0, -0.0502>, -0.0000 }
  texture {
    pigment { color rgb <0.8600, 0.2000, 0.2400> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}

// Slice 4: Vivo (8.4%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 0.8500, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 0.8500, 0>, <0, 1.2000, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 0.8500, 0> }
  }
  plane { <-0.9987, 0, 0.0502>, -0.0000 }
  plane { <0.8881, 0, 0.4596>, -0.0000 }
  texture {
    pigment { color rgb <0.5800, 0.4000, 0.7400> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}

// Slice 5: Other (7.0%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 0.7750, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 0.7750, 0>, <0, 1.1250, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 0.7750, 0> }
  }
  plane { <-0.8881, 0, -0.4596>, -0.0000 }
  plane { <0.6079, 0, 0.7940>, -0.0000 }
  texture {
    pigment { color rgb <0.9000, 0.7500, 0.1000> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}

// Slice 6: Huawei (6.1%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 0.7000, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 0.7000, 0>, <0, 1.0500, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 0.7000, 0> }
  }
  plane { <-0.6079, 0, -0.7940>, -0.0000 }
  plane { <0.2669, 0, 0.9637>, -0.0000 }
  texture {
    pigment { color rgb <0.1300, 0.6900, 0.6800> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}

// Slice 7: Motorola (4.3%)
intersection {
  union {
    cylinder { <0, 0.3500, 0>, <0, 0.5500, 0>, 4.0000 }
    cylinder { <0, 0, 0>, <0, 0.3500, 0>, 3.6500 }
    cylinder { <0, 0.5500, 0>, <0, 0.9000, 0>, 3.6500 }
    torus { 3.6500, 0.3500 translate <0, 0.3500, 0> }
    torus { 3.6500, 0.3500 translate <0, 0.5500, 0> }
  }
  plane { <-0.2669, 0, -0.9637>, -0.0000 }
  plane { <-0.0000, 0, 1.0000>, -0.0000 }
  texture {
    pigment { color rgb <0.8800, 0.3500, 0.6000> }
    finish { ambient 0.02 diffuse 0.68 specular 0.65 roughness 0.008 reflection { 0.12 } }
  }
  translate y * DiscHeight
}
// Rise-and-hover animation:
// Phase 1 (clock 0?0.5): camera lifts from side position to risen height.
// Phase 2 (clock 0.5?1.0): camera holds risen height, oscillates ?8.1? left/right (6 cycle(s) at speed 0.1).
// Start offset from look_at: <0.001000, 0, -14.000000> at height 7.600000.
// End: XZ collapses to 112% of start, rises 3.42 units.
// Generated by OrbitSceneBuilder (RiseMode + Hover).
#declare _orb_tx      = 0.000000;
#declare _orb_ty      = 0.900000;
#declare _orb_tz      = 0.000000;
#declare _orb_lx      = 0.001000;
#declare _orb_ly      = 7.600000;
#declare _orb_lz      = -14.000000;
#declare _orb_rise    = 3.420000;
#declare _orb_in      = -0.120000;
#declare _orb_r       = 14.000000;
#declare _orb_h       = 7.600000;
#declare _orb_a0      = 3.141521;
#declare _orb_r_end   = 15.680000;
#declare _hover_rad    = 0.141372;
#declare _hover_cycles = 6.000000;
#declare _hover_speed  = 0.100000;
#declare _T_mid       = 0.500000;
#declare _c1          = min(clock, _T_mid) / _T_mid;
#declare _c2          = max(clock - _T_mid, 0.0) / (1.0 - _T_mid);
#declare _p1_x        = _orb_tx + _orb_lx * (1.0 - _c1 * _orb_in);
#declare _p1_y        = _orb_ly + _c1 * _orb_rise;
#declare _p1_z        = _orb_tz + _orb_lz * (1.0 - _c1 * _orb_in);
#declare _hover_a     = _orb_a0 + _hover_rad * sin(6.28318530717959 * _hover_cycles * _hover_speed * _c2);
#declare _p2_x        = _orb_tx + _orb_r_end * sin(_hover_a);
#declare _p2_y        = _orb_ly + _orb_rise;
#declare _p2_z        = _orb_tz + _orb_r_end * cos(_hover_a);
#declare _cam_x       = select(clock - _T_mid, _p1_x, _p2_x);
#declare _cam_y       = select(clock - _T_mid, _p1_y, _p2_y);
#declare _cam_z       = select(clock - _T_mid, _p1_z, _p2_z);
camera {
  perspective
  location <_cam_x, _cam_y, _cam_z>
  look_at  <_orb_tx, _orb_ty, _orb_tz>
  right x*image_width/image_height
  angle 42.0000
}
