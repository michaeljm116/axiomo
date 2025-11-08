package xxhash2
import "core:hash/xxhash"

str_to_u32 :: proc(s : string) -> u32
{
    return u32(xxhash.XXH32(transmute([]byte)(s)))
}
