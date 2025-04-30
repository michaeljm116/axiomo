package main
import math"core:math/linalg"
import "core:strings"
import "core:log"
import "core:os"
import "core:io"
import "core:fmt"
import "core:encoding/csv"
import "core:bytes"
import "core:bufio"
import "core:encoding/ini"
import "core:encoding/xml"
import "core:mem"

//----------------------------------------------------------------------------\\
// /LoadModel /lm
//----------------------------------------------------------------------------\\
load_pmodel :: proc(file_name : string)
{
    // Set up initial variables 
    mod : Model
    intro_length : i32 = 0
    name_length : i32 = 0
    num_Mesh : i32 = 0
    unique_id : i32 = 0
    skeleton_id : i32 = 0
    skinned : b8 = false

    // Set up bionary io
    binaryio, err := os.open(file_name, os.O_RDONLY)
    log_if_err(err)
    defer os.close(binaryio)

    // Dont really need the intro but do it anyways
    total_read : int
    total_read, err = os.read(binaryio, mem.ptr_to_bytes(&intro_length))
    log_if_err(err)
    c : u8  
    if intro_length > 0 {
        for b in 0..<intro_length { 
            total_read, err = os.read(binaryio, mem.ptr_to_bytes(&c) )
            log_if_err(err)
            fmt.print(rune(c))
        }
    }
  

}

read_i32 :: proc(fd: os.Handle) -> (i32, bool) {
    bytes: [4]u8
    n, err := os.read(fd, bytes[:])
    if err != os.ERROR_NONE || n != 4 {
        return 0, false
    }
    return 1, true
   // return mem.slice_to_cast([]u8{bytes[0], bytes[1], bytes[2], bytes[3]}, i32), true
}

log_if_err :: proc(e : os.Error, loc := #caller_location){
    if e != os.ERROR_NONE {fmt.eprintln("Error: ", e, " at location : ", loc)}
}
