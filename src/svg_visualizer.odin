package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

BAND_WIDTH :: 50
IMAGE_WIDTH :: 500

create_svg :: proc (boxes: [dynamic]LAB) {
    nr_boxes := len(boxes)
    boxes_per_row := cast(int) math.ceil(cast(f64) IMAGE_WIDTH / BAND_WIDTH)
    rows := cast(int) math.ceil(cast(f64) nr_boxes / cast(f64) boxes_per_row)
    image_height := rows * BAND_WIDTH

    // Use a string builder for efficient string construction
    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    // Write the SVG header
    fmt.sbprintfln(
    &builder,
    `<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">`,
    IMAGE_WIDTH,
    image_height,
    )

    // Add more content
    for i in 0 ..< nr_boxes {
        if srgb, ok := lab_to_srgb(boxes[i]); ok {
            srgb255 := srgb_to_255(srgb)
            x := i % boxes_per_row
            y := i / boxes_per_row
            fmt.sbprintfln(&builder, `<rect x="%d" y="%d" width="50" height="50" fill="rgb(%d, %d, %d)" stroke-width="4" stroke="white" />`, x * BAND_WIDTH, y * BAND_WIDTH, srgb255.r, srgb255.g, srgb255.b)
        }
    }
    fmt.sbprintfln(&builder, `</svg>`)

    // Get the final string
    svg_content := strings.to_string(builder)

    // Write to file
    ok := os.write_entire_file("output.svg", transmute([]u8)svg_content)
    if !ok {
        fmt.println("Failed to write SVG file")
    } else {
        fmt.println("SVG file created successfully")
    }
}
