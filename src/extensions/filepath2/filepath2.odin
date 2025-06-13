package filepath2
import "core:os"
import "core:fmt"
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