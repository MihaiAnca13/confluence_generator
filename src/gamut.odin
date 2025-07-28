package main

import "core:math"
import "core:math/rand"
import linalg "core:math/linalg"
import "core:fmt"

lab_to_linear_cache : map[LAB]LinearRGB

// Reference white D65
D65_WHITE : linalg.Vector3f64 : { 95.047, 100.0, 108.883 }

sRGB :: struct {
    r, g, b: f64
}

LinearRGB :: sRGB

LAB :: struct {
    L, a, b: f64
}

GamutPoint :: struct {
    rgb : sRGB,
    lab : LAB
}

to_sRGB :: proc (c: f64) -> f64 {
    if c <= 0.0031308 {
        return c * 12.92
    }
    return 1.055 * math.pow(c, 1.0 / 2.4) - 0.055
}

f_inv :: proc (t: f64) -> f64 {
    return t > 0.206893034 ? math.pow(t, 3.0) : (t - 16.0 / 116.0) / 7.787
}


lab_to_xyz :: proc (lab: LAB) -> linalg.Vector3f64 {
    fy := (lab.L + 16.0) / 116.0
    fx := lab.a / 500.0 + fy
    fz := fy - lab.b / 200.0

    xyz : linalg.Vector3f64
    xyz.x = D65_WHITE.x * f_inv(fx)
    xyz.y = D65_WHITE.y * f_inv(fy)
    xyz.z = D65_WHITE.z * f_inv(fz)

    return xyz
}


xyz_to_linear_rgb :: proc (xyz: linalg.Vector3f64) -> LinearRGB {
    xyz := xyz
    xyz /= 100.0

    linear : LinearRGB
    linear.r = xyz.x * 3.2404542 + xyz.y * -1.5371385 + xyz.z * -0.4985314
    linear.g = xyz.x * -0.9692660 + xyz.y * 1.8760108 + xyz.z * 0.0415560
    linear.b = xyz.x * 0.0556434 + xyz.y * -0.2040259 + xyz.z * 1.0572252
    return linear
}

is_in_gamut :: proc (color: LinearRGB) -> bool {
    return color.r >= 0.0 && color.r <= 1.0 &&
    color.g >= 0.0 && color.g <= 1.0 &&
    color.b >= 0.0 && color.b <= 1.0
}


srgb_to_255 :: proc (rgb : sRGB) -> [3]int {
    res : [3]int
    res[0] = cast(int)(rgb.r * 255)
    res[1] = cast(int)(rgb.g * 255)
    res[2] = cast(int)(rgb.b * 255)
    return res
}

is_lab_in_gamut :: proc (lab: LAB) -> bool {
    if lab in lab_to_linear_cache {
        return is_in_gamut(lab_to_linear_cache[lab])
    }
    xyz_color := lab_to_xyz(lab)
    linear_color := xyz_to_linear_rgb(xyz_color)
    lab_to_linear_cache[lab] = linear_color
    return is_in_gamut(linear_color)
}

lab_to_srgb :: proc (lab: LAB) -> (sRGB, bool) {
    linear : LinearRGB
    if lab in lab_to_linear_cache {
        linear = lab_to_linear_cache[lab]
    }
    else {
        xyz := lab_to_xyz(lab)
        linear = xyz_to_linear_rgb(xyz)
        lab_to_linear_cache[lab] = linear
    }

    if is_in_gamut(linear) {
        return sRGB{ to_sRGB(linear.r), to_sRGB(linear.g), to_sRGB(linear.b) }, true
    }
    return sRGB{ 0, 0, 0 }, false
}
