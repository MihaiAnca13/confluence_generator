#+feature dynamic-literals
package main

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:encoding/json"
import "core:os"

COMBINATIONS :: 10

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

    env_vars := read_env()
    defer delete(env_vars)

    points : [dynamic]LAB
    for {
        points = poisson_disc_sampling_3d(16.8, 100, is_lab_in_gamut)
        if len(points) >= 145 {
            break
        }
    }
    resize(&points, 145)
    fmt.printf("Found %v points\n", len(points))

    // order points based on L+a+b
    slice.sort_by_key(points[:], proc (point: LAB) -> f64 {
        return point.L + (point.a + 128) / 255 * 10 + (point.b + 128) / 255
    })

    create_svg(points)

    essences := read_file("essences.txt", true)
    defer delete(essences)
    prompt := read_file("prompt.txt")[0]
    defer delete(prompt)

    file, err := os.open("output.txt", os.O_APPEND | os.O_CREATE | os.O_WRONLY)
    if err != nil {
        fmt.eprintln("Error opening file for appending:", err)
        return
    }
    defer os.close(file)

    // create array of 10, and once full, call llm, then clear the array and continue
    combinations : [COMBINATIONS]string
    combinations_index := 0
    essence_loop: for i in 0..<len(essences) {
        for j in i+1..<len(essences) {
            for k in j+1..<len(essences) {
                combinations[combinations_index] = fmt.tprintf("%s, %s and %s", essences[i], essences[j], essences[k])
                combinations_index += 1

                if combinations_index == COMBINATIONS {
                    builder := strings.Builder{}
                    fmt.sbprintf(&builder, "%s\n", prompt)
                    for i in 0..<COMBINATIONS {
                        fmt.sbprintf(&builder, "%s\n", combinations[i])
                    }
                    combinations_index = 0

                    modified_prompt := strings.to_string(builder)

                    response := call_llm(modified_prompt, env_vars["GEMINI_API"])

                    inner_strings: []string
                    inner_err := json.unmarshal(transmute([]u8)response, &inner_strings)

                    if inner_err != nil {
                        fmt.println("Error unmarshalling inner 'text' field:", inner_err)
                        continue
                    }

                    for i in 0..<len(inner_strings) {
                        builder2 := strings.Builder{}
                        fmt.sbprintf(&builder2, "%s: %s\n", combinations[i], inner_strings[i])
//                        fmt.printf("%s: %s\n", combinations[i], inner_strings[i])
                        bytes_written, write_err := os.write(file, transmute([]u8)strings.to_string(builder2))
                        if write_err != os.ERROR_NONE {
                            fmt.printf("Failed to write: %v\n", write_err)
                            return
                        }
                    }
                }
            }
        }
    }
}


