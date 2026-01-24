package queue2
import "core:container/queue"

// Initialize index for a queue. If empty, returns -1, otherwise returns 0.
init :: proc(q: ^queue.Queue($T)) -> int {
    if q == nil || queue.len(q^) == 0 {
        return -1
    }
    return 0
}

// Return number of items or 0 if q is nil
len :: proc(q: ^queue.Queue($T)) -> int {
    if q == nil {
        return 0
    }
    return queue.len(q^)
}

// Ensure idx is valid for current queue; keep -1 for empty
clamp :: proc(q: ^queue.Queue($T), idx: int) -> int {
    n := len(q)
    if n == 0 { return -1 }
    // wrap in case idx out of range (can happen after removals)
    return (idx % n + n) % n
}

// Return current element (or zero value)
current :: proc(q: ^queue.Queue($T), idx: int) -> T {
    n := len(q)
    if n == 0 || idx < 0 {
        return {} // return zero value for T
    }
    return queue.get(q, idx)
}

// Advance to next element (wraps) and return it
next :: proc(q: ^queue.Queue($T), idx: int) -> (T, int) {
    n := len(q)
    if n == 0 { return {}, -1 }
    new_idx := (idx + 1) % n
    return queue.get(q, new_idx), new_idx
}

// Move to previous element (wraps) and return it
prev :: proc(q: ^queue.Queue($T), idx: int) -> (T, int) {
    n := len(q)
    if n == 0 { return {}, -1 }
    new_idx := (idx - 1 + n) % n
    return queue.get(q, new_idx), new_idx
}

// Simple version without function parameter - find next non-zero value
next_nonzero :: proc(q: ^queue.Queue($T), idx: int) -> (T, int) {
    n := len(q)
    if n == 0 { return {}, -1 }
    for i := 0; i < n; i += 1 {
        new_idx := (idx + 1) % n
        e := queue.get(q, new_idx)
        // Check if e is not zero (basic check)
        if e != {} { return e, new_idx }
        idx = new_idx
    }
    return {}, idx
}

// Call this after removing the element at `removed_index` from the queue.
// It adjusts the index so it still points to the intended element.
adjust_after_remove :: proc(q: ^queue.Queue($T), idx: int, removed_index: int) -> int {
    n := len(q)
    if n == 0 { return -1 }
    if removed_index < 0 { return clamp(q, idx) }
    if removed_index < idx {
        // indices shift left by one
        idx -= 1
    } else if removed_index == idx {
        // index pointed to the removed element: keep same index which now points to next element
        // if index is at end, wrap back to 0
        if idx >= n { idx = 0 }
    }
    return clamp(q, idx)
}
