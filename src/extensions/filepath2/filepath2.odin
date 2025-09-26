package filepath2
import "core:os"
import "core:fmt"
import "core:mem"
import "core:strings"

get_dir_files :: proc (directory: string) -> []os.File_Info {
    dir_handle, err := os.open(directory, os.O_RDONLY)
    if err != os.ERROR_NONE {
        fmt.println("Error opening directory:", err)
        return nil
    }
    defer os.close(dir_handle)

    entries, read_err := os.read_dir(dir_handle, 64, context.allocator)
    if read_err != 0 {
        fmt.println("Error reading directory:", read_err)
        return nil
    }
    return entries
}

get_file_stem :: proc (file_path : string, alloc : mem.Allocator) -> string
{
    context.allocator = alloc
    i := len(file_path)
    index := 0
    for j in 0..<i
    {
        if file_path[j] == '.'
        {
            index = j
            break
        }
    }
    sub , ok := strings.substring(file_path, index, len(file_path))
    return sub
}

get_file_name :: proc (f : os.File_Info, alloc : mem.Allocator) -> string
{
    context.allocator = alloc
    i := len(f.name)
    index := 0
    for j in 0..<i
    {
        if f.name[j] == '.'
        {
            index = j
            break
        }
    }
    sub, ok := strings.substring(f.name, 0, index)
    return sub
}
