package main

import "core:math"
import "core:math/rand"
import linalg "core:math/linalg"
import "core:fmt"

sRGB :: struct {
    r, g, b: f32
}

LinearRGB :: sRGB

LAB :: struct {
    L, a, b: f32
}

GamutPoint :: struct {
    rgb : sRGB,
    lab : LAB
}

// Reference white D65
D65_WHITE : linalg.Vector3f32 : { 95.047, 100.0, 108.883 }

to_sRGB :: proc (c: f32) -> f32 {
    if c <= 0.0031308 {
        return c * 12.92
    }
    return 1.055 * math.pow(c, 1.0 / 2.4) - 0.055
}

f_inv :: proc (t: f32) -> f32 {
    return t > 0.206893034 ? math.pow(t, 3.0) : (t - 16.0 / 116.0) / 7.787
}


lab_to_xyz :: proc (lab: LAB) -> linalg.Vector3f32 {
    fy := (lab.L + 16.0) / 116.0
    fx := lab.a / 500.0 + fy
    fz := fy - lab.b / 200.0

    xyz : linalg.Vector3f32
    xyz.x = D65_WHITE.x * f_inv(fx)
    xyz.y = D65_WHITE.y * f_inv(fy)
    xyz.z = D65_WHITE.z * f_inv(fz)

    return xyz
}


xyz_to_linear_rgb :: proc (xyz: linalg.Vector3f32) -> LinearRGB {
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

sample_in_gamut :: proc () -> (GamutPoint, bool) {
    attempts := 0

    for attempts < 10 {
        // pick random point in CIELAB space
        lab : LAB
        lab.L = rand.float32_range(0, 100)
        lab.a = rand.float32_range(-128, 127)
        lab.b = rand.float32_range(-128, 127)

        xyz_color := lab_to_xyz(lab)

        linear_color := xyz_to_linear_rgb(xyz_color)

        if is_in_gamut(linear_color) {
            srgb := sRGB{to_sRGB(linear_color.r), to_sRGB(linear_color.g), to_sRGB(linear_color.b)}
            return GamutPoint{rgb=srgb, lab=lab}, true
        }
    }
    fmt.printf("Failed to find in-gamut color after %d attempts\n", attempts)
    return GamutPoint{}, false
}