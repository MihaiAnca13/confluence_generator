package main

import "core:os"
import "core:fmt"
import "core:strings"
import "base:runtime"
import "core:mem"
import "core:encoding/json"
import curl "../libs/odin-curl"

BASE_URL :: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

Part :: struct {
    text: string,
}

Content :: struct {
    parts: []Part,
}

Candidate :: struct {
    content: Content,
}

Response :: struct {
    candidates: []Candidate,
}

DataContext :: struct {
    data: []u8,
    ctx:  runtime.Context,
}

write_callback :: proc "c" (contents: rawptr, size: uint, nmemb: uint, userp: rawptr) -> uint {
    dc := transmute(^DataContext)userp
    context = dc.ctx
    total_size := size * nmemb
    content_str := transmute([^]u8)contents
    dc.data = make([]u8, int(total_size)) // <-- ALLOCATION
    mem.copy(&dc.data[0], content_str, int(total_size))
    return total_size
}


read_env :: proc (filepath : string = ".env") -> map[string]string {
    env_vars := make(map[string]string)

    // Read the entire file
    data, ok := os.read_entire_file(filepath)
    if !ok {
        fmt.printf("Failed to read file: %s\n", filepath)
        return env_vars
    }
    defer delete(data)

    // Convert to string
    content := string(data)

    // Split into lines
    lines := strings.split_lines(content)
    defer delete(lines)

    for line in lines {
    // Skip empty lines and comments
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 || strings.has_prefix(trimmed, "#") {
            continue
        }

        // Find the = separator
        eq_pos := strings.index_byte(trimmed, '=')
        if eq_pos == -1 {
            continue
        }

        // Extract key and value
        key := strings.trim_space(trimmed[:eq_pos])
        value := strings.trim_space(trimmed[eq_pos + 1:])

        // Remove quotes if present
        if len(value) >= 2 {
            if (strings.has_prefix(value, "\"") && strings.has_suffix(value, "\"")) ||
            (strings.has_prefix(value, "'") && strings.has_suffix(value, "'")) {
                value = value[1:len(value) - 1]
            }
        }

        env_vars[strings.clone(key)] = strings.clone(value)
    }

    return env_vars
}


call_llm :: proc (prompt : string, api_key : string) -> string {
    json_data := fmt.tprintf(`{{
        "contents": [{{
            "parts": [{{
                "text": "{}"
            }}]
        }}],
        "generationConfig": {{
            "responseMimeType": "application/json",
            "responseSchema": {{
                "type": "ARRAY",
                "items": {{
                    "type": "STRING"
                }}
            }}
        }}
    }}`, prompt)

    // Initialize curl
    curl_handle := curl.easy_init()
    if curl_handle == nil {
        fmt.println("Failed to initialize curl")
        return ""
    }
    defer curl.easy_cleanup(curl_handle)

    // Prepare headers
    headers: ^curl.curl_slist
    api_header := fmt.tprintf("x-goog-api-key: %s", api_key)
    headers = curl.slist_append(nil, "Content-Type: application/json")
    headers = curl.slist_append(headers, strings.clone_to_cstring(api_header))
    defer curl.slist_free_all(headers)

    response_data := DataContext{nil, context}
    defer delete(response_data.data)

    // Set curl options
    curl.easy_setopt(curl_handle, .URL,                         BASE_URL)
    curl.easy_setopt(curl_handle, .HTTPHEADER,                headers)
    curl.easy_setopt(curl_handle, .POSTFIELDS,                json_data)
    curl.easy_setopt(curl_handle, .WRITEFUNCTION,             write_callback)
    curl.easy_setopt(curl_handle, .WRITEDATA,                 &response_data)

    curl.easy_setopt(curl_handle, curl.CURLoption.SSL_VERIFYPEER, 0)

    // Send the request
    res := curl.easy_perform(curl_handle)
    if res != .OK {
        fmt.printf("curl.easy_perform() failed: %s\n", curl.easy_strerror(res))
        return ""
    }

    // Check status code
    response_code: i64
    curl.easy_getinfo(curl_handle, .RESPONSE_CODE, &response_code)
    if response_code != 200 {
        fmt.printf("HTTP Error: %d\n", response_code)
        fmt.printf("Response: %s\n", string(response_data.data))
        return ""
    }

    // Parse the JSON response
    llm_response: Response
    err := json.unmarshal(response_data.data, &llm_response)
    if err != nil {
        fmt.printf("JSON Unmarshal failed: %v\n", err)
        return ""
    }

    // Extract the generated text
    if len(llm_response.candidates) > 0 {
        first_candidate := llm_response.candidates[0]
        if len(first_candidate.content.parts) > 0 {
            first_part := first_candidate.content.parts[0]
            return first_part.text
        }
    }

    return ""
}


main :: proc () {
    env_vars := read_env()
    response := call_llm("Please solve these problems: 1) 12+1512/12 2) 2 + 2 * x = 1 3) x^2 + 2x + 1 = 0", env_vars["GEMINI_API"])
    fmt.printf("Response: %s\n", response)
}