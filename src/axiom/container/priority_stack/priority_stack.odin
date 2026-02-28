package priority_stack

import "base:runtime"
import "base:builtin"

Entry :: struct($E: typeid) {
	value: E,
	index: u64,
}

Priority_Stack :: struct($T: typeid) {
	internal_stack: [dynamic]Entry(T),
	user_less:      proc(a, b: T) -> bool,
	user_swap:      proc(q: []T, i, j: int),
	counter:        u64,
}

DEFAULT_CAPACITY :: 16

default_swap_proc :: proc($T: typeid) -> proc(q: []T, i, j: int) {
	return proc(q: []T, i, j: int) {
		q[i], q[j] = q[j], q[i]
	}
}

_internal_less :: proc(pq: ^Priority_Stack($T), a, b: Entry(T)) -> bool {
	if pq.user_less(a.value, b.value) {
		return true
	}
	if pq.user_less(b.value, a.value) {
		return false
	}
	// For LIFO: higher index (later insertion) is considered "smaller" (better, popped first)
	return a.index > b.index
}

_internal_swap :: proc(pq: ^Priority_Stack($T), q: []Entry(T), i, j: int) {
	// Swap values using user-provided swap
	val1 := q[i].value
	val2 := q[j].value
	temp_slice := []T{val1, val2}
	pq.user_swap(temp_slice, 0, 1)
	q[i].value = temp_slice[0]
	q[j].value = temp_slice[1]
	// Swap indices
	q[i].index, q[j].index = q[j].index, q[i].index
}

init :: proc(pq: ^$Q/Priority_Stack($T), less: proc(a, b: T) -> bool, swap: proc(q: []T, i, j: int), capacity := DEFAULT_CAPACITY, allocator := context.allocator) -> (err: runtime.Allocator_Error) {
	if pq.internal_stack.allocator.procedure == nil {
		pq.internal_stack.allocator = allocator
	}
	reserve(pq, capacity) or_return
	pq.user_less = less
	pq.user_swap = swap
	pq.counter = 0
	return .None
}

init_from_dynamic_array :: proc(pq: ^$Q/Priority_Stack($T), values: [dynamic]T, less: proc(a, b: T) -> bool, swap: proc(q: []T, i, j: int)) {
	pq.user_less = less
	pq.user_swap = swap
	pq.counter = 0
	pq.internal_stack.allocator = values.allocator
	reserve(&pq.internal_stack, cap(values))
	for v in values {
		append(&pq.internal_stack, Entry(T){v, pq.counter})
		pq.counter += 1
	}
	n := builtin.len(pq.internal_stack)
	for i := n/2 - 1; i >= 0; i -= 1 {
		_shift_down(pq, i, n)
	}
}

destroy :: proc(pq: ^$Q/Priority_Stack($T)) {
	clear(pq)
	delete(pq.internal_stack)
}

reserve :: proc(pq: ^$Q/Priority_Stack($T), capacity: int) -> (err: runtime.Allocator_Error) {
	return builtin.reserve(&pq.internal_stack, capacity)
}

clear :: proc(pq: ^$Q/Priority_Stack($T)) {
	builtin.clear(&pq.internal_stack)
	pq.counter = 0
}

len :: proc(pq: $Q/Priority_Stack($T)) -> int {
	return builtin.len(pq.internal_stack)
}

cap :: proc(pq: $Q/Priority_Stack($T)) -> int {
	return builtin.cap(pq.internal_stack)
}

_shift_down :: proc(pq: ^$Q/Priority_Stack($T), i0, n: int) -> bool {
	// O(n log n)
	if 0 > i0 || i0 > n {
		return false
	}
	i := i0
	stack := pq.internal_stack[:]
	for {
		j1 := 2*i + 1
		if j1 < 0 || j1 >= n {
			break
		}
		j := j1
		if j2 := j1+1; j2 < n && _internal_less(pq, stack[j2], stack[j1]) {
			j = j2
		}
		if !_internal_less(pq, stack[j], stack[i]) {
			break
		}
		_internal_swap(pq, stack, i, j)
		i = j
	}
	return i > i0
}

_shift_up :: proc(pq: ^$Q/Priority_Stack($T), j: int) {
	j := j
	stack := pq.internal_stack[:]
	for 0 <= j {
		i := (j-1)/2
		if i == j || !_internal_less(pq, stack[j], stack[i]) {
			break
		}
		_internal_swap(pq, stack, i, j)
		j = i
	}
}

// NOTE(bill): When an element at index 'i' has changed its value, this will fix the
// the heap ordering. This is using a basic "heapsort" with shift up and a shift down parts.
fix :: proc(pq: ^$Q/Priority_Stack($T), i: int) {
	if !_shift_down(pq, i, builtin.len(pq.internal_stack)) {
		_shift_up(pq, i)
	}
}

push :: proc(pq: ^$Q/Priority_Stack($T), value: T) -> (err: runtime.Allocator_Error) {
	append(&pq.internal_stack, Entry(T){value, pq.counter}) or_return
	pq.counter += 1
	_shift_up(pq, builtin.len(pq.internal_stack)-1)
	return .None
}

pop :: proc(pq: ^$Q/Priority_Stack($T), loc := #caller_location) -> (value: T) {
	assert(condition=builtin.len(pq.internal_stack)>0, loc=loc)
	n := builtin.len(pq.internal_stack)-1
	_internal_swap(pq, pq.internal_stack[:], 0, n)
	_shift_down(pq, 0, n)
	return builtin.pop(&pq.internal_stack).value
}

pop_safe :: proc(pq: ^$Q/Priority_Stack($T), loc := #caller_location) -> (value: T, ok: bool) {
	if builtin.len(pq.internal_stack) > 0 {
		n := builtin.len(pq.internal_stack)-1
		_internal_swap(pq, pq.internal_stack[:], 0, n)
		_shift_down(pq, 0, n)
		return builtin.pop_safe(&pq.internal_stack).value, true
	}
	return
}

remove :: proc(pq: ^$Q/Priority_Stack($T), i: int) -> (value: T, ok: bool) {
	n := builtin.len(pq.internal_stack)
	if 0 <= i && i < n {
		_internal_swap(pq, pq.internal_stack[:], i, n-1)
		_shift_down(pq, i, n-1)
		_shift_up(pq, i)
		value, ok = builtin.pop(&pq.internal_stack).value, true
	}
	return
}

peek_safe :: proc(pq: $Q/Priority_Stack($T), loc := #caller_location) -> (res: T, ok: bool) {
	if builtin.len(pq.internal_stack) > 0 {
		return pq.internal_stack[0].value, true
	}
	return
}

peek :: proc(pq: $Q/Priority_Stack($T), loc := #caller_location) -> (res: T) {
	assert(condition=builtin.len(pq.internal_stack)>0, loc=loc)
	if builtin.len(pq.internal_stack) > 0 {
		return pq.internal_stack[0].value
	}
	return
}

peek_ptr :: proc(pq: $Q/Priority_Stack($T), loc := #caller_location) -> (res: ^T) {
	assert(condition=builtin.len(pq.internal_stack)>0, loc=loc)
	if builtin.len(pq.internal_stack) > 0 {
		return &pq.internal_stack[0].value
	}
	return
}
