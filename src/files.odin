package main


import "core:os"
import "core:fmt"
import "core:strings"


read_file :: proc (path: string, split_lines: bool = false) -> []string {
    data, ok := os.read_entire_file(path)
    res := make([]string, 1)
    if !ok {
        fmt.printf("Failed to read file: %s\n", path)
        res[0] = ""
        return res
    }

    if split_lines {
        return strings.split_lines(string(data))
    }

    res[0] = string(data)
    return res
}