package main

import linalg "core:math/linalg"
import "core:math"
import "core:math/rand"
import "core:fmt"

PI :: 3.141592653589793

sqrt :: proc (x: f64) -> f64 {
    return math.sqrt(cast(f64) x)
}

ceil :: proc (x: f64) -> f64 {
    return math.ceil(cast(f64) x)
}

floor :: proc (x: f64) -> f64 {
    return math.floor(cast(f64) x)
}

make_3d_array :: proc(dim1, dim2, dim3: int, $T: typeid) -> [dynamic][dynamic][dynamic]Maybe(T) {
    arr: [dynamic][dynamic][dynamic]Maybe(T)
    resize(&arr, dim1)

    for i in 0 ..< dim1 {
        resize(&arr[i], dim2)
        for j in 0 ..< dim2 {
            resize(&arr[i][j], dim3)
        }
    }
    return arr
}

lab_squared_distance :: proc (a, b: LAB) -> f64 {
    return math.pow(a.L - b.L, 2) +
        math.pow(a.a - b.a, 2) +
        math.pow(a.b - b.b, 2)
}

poisson_disc_sampling_3d :: proc (r: f64, k: int, is_valid: proc (LAB) -> bool) -> [dynamic]LAB {
/*
Args:
    r: minimum distance between two points
    k: the number of attempts to find a valid point
    is_valid: a function that returns true if the point is within the gamut
*/

// define the bounds
    min_L, max_L := 0.0, 100.0
    min_a, max_a := -128.0, 127.0
    min_b, max_b := -128.0, 127.0

    // compute cell size to guarantee at most one point per cell
    cell_size := r / sqrt(3.0)

    // grid dimensions
    grid_L := cast(int) ceil((max_L - min_L) / cell_size)
    grid_a := cast(int) ceil((max_a - min_a) / cell_size)
    grid_b := cast(int) ceil((max_b - min_b) / cell_size)

    grid := make_3d_array(grid_L, grid_a, grid_b, LAB)
    defer delete(grid)
    active_list : [dynamic]LAB
    defer delete(active_list)
    samples : [dynamic]LAB

    for len(active_list) == 0 {
    // first point is randomly chosen
        first_point : LAB
        first_point.L = rand.float64_range(min_L, max_L)
        first_point.a = rand.float64_range(min_a, max_a)
        first_point.b = rand.float64_range(min_b, max_b)

        if is_valid(first_point) {
            append(&active_list, first_point)
            append(&samples, first_point)
        }
    }

    fmt.printf("Starting search in grid of size %v x %v x %v\n", grid_L, grid_a, grid_b)

    for len(active_list) > 0 {
        index := cast(int) floor(rand.float64_range(0, cast(f64) len(active_list) - 1))
        current_point := active_list[index]

        candidate_found := false
        for i in 0 ..< k {
            candidate_point : LAB
            // Generate a candidate point in a spherical shell around the active point
            // This uses spherical coordinates to ensure uniform distribution on the sphere surface
            radius := rand.float64_range(r, 2 * r)
            theta := rand.float64_range(0.0, 2 * PI) // Azimuthal angle
            phi := math.acos(2 * rand.float64() - 1) // Polar angle

            dx := radius * math.sin(phi) * math.cos(theta)
            dy := radius * math.sin(phi) * math.sin(theta)
            dz := radius * math.cos(phi)

            candidate_point.L = current_point.L + dx
            candidate_point.a = current_point.a + dy
            candidate_point.b = current_point.b + dz

            // check if the candidate point is within the bounds
            if !is_valid(candidate_point) {
                continue
            }

            // check the 5x5x5 grid around the candidate point
            grid_x := cast(int) floor((candidate_point.L - min_L) / cell_size)
            grid_y := cast(int) floor((candidate_point.a - min_a) / cell_size)
            grid_z := cast(int) floor((candidate_point.b - min_b) / cell_size)

            is_too_close := false
            grid_search: for x in grid_x - 2 ..= grid_x + 2 {
                for y in grid_y - 2 ..= grid_y + 2 {
                    for z in grid_z - 2 ..= grid_z + 2 {
                        if x < 0 || x >= grid_L || y < 0 || y >= grid_a || z < 0 || z >= grid_b {
                            continue
                        }
                        if value, ok := grid[x][y][z].?; ok {
                            distance := lab_squared_distance(candidate_point, value)
                            if distance < math.pow(r, 2) {
                                is_too_close = true
                                break grid_search
                            }
                        }
                    }
                }
            }

            if is_too_close {
                continue
            }

            candidate_found = true
            append(&active_list, candidate_point)
            append(&samples, candidate_point)
            grid[grid_x][grid_y][grid_z] = candidate_point
            fmt.printf("Found point %v. Total: %v\n", candidate_point, len(samples))
        }

        if !candidate_found {
            // remove current point from the active list
            unordered_remove(&active_list, index)
        }
    }

    return samples
}