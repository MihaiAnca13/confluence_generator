package main

sRGB :: struct {
    r, g, b: f32
}

LinearRGB :: sRGB

Vector3 :: struct {
    x, y, z: f32
}

LAB :: struct {
    L, a, b: f32
}

// Reference white D65
D65_WHITE : Vector3 : {95.047, 100.0, 108.883}

to_sRGB :: proc (c: f32) -> f32 {
    return 0.0
}


