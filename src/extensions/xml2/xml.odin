package xml2
import "core:fmt"
import "core:encoding/xml"
import "core:strconv"

get_f32_attr :: proc(doc: ^xml.Document, parent_id: xml.Element_ID, key: string) -> f32{
    v, f := xml.find_attribute_val_by_key(doc, parent_id, key)
    if log_if_not_found(f, key) do return 0
    return f32(strconv.atof(v))
}
get_str_attr :: proc(doc: ^xml.Document, parent_id: xml.Element_ID, key: string) -> string {
    v, f := xml.find_attribute_val_by_key(doc, parent_id, key)
    if log_if_not_found(f, key) do return ""
    return v
}
get_i32_attr :: proc(doc: ^xml.Document, parent_id: xml.Element_ID, key: string) -> i32 {
    v, f := xml.find_attribute_val_by_key(doc, parent_id, key)
    if log_if_not_found(f, key) do return 0
    return i32(strconv.atoi(v))
}

log_if_err :: proc(e : xml.Error, loc := #caller_location) -> bool{
    if e != xml.Error.None {
        fmt.eprintln("Error: ", e, " at location : ", loc)
        return true
    }
    return false
}
log_if_not_found :: proc(f : bool, msg : string, loc := #caller_location) -> bool{
    if !f {
        fmt.eprintln("Error: ", msg, "not found at location: ", loc)
        return true
    }
    return false
}