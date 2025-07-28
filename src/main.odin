#+feature dynamic-literals
package main

import "core:fmt"
import "core:mem"
import "core:slice"

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    points : [dynamic]LAB
    for {
        points = poisson_disc_sampling_3d(16.8, 100, is_lab_in_gamut)
        if len(points) >= 150 {
            break
        }
    }
    resize(&points, 150)
    fmt.printf("Found %v points\n", len(points))

    // order points based on L+a+b
    slice.sort_by_key(points[:], proc (point: LAB) -> f64 {
        return point.L + (point.a + 128) / 255 * 10 + (point.b + 128) / 255
    })


    create_svg(points)

}


