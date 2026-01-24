package queue2_tests

import "core:testing"
import "core:container/queue"
import "../queue2"

// Test basic initialization with nil queue
@(test)
test_init_nil :: proc(t: ^testing.T) {
    cursor: queue2.Queue2(int)
    queue2.init_empty(&cursor)
    testing.expect(t, cursor.idx == -1, "idx should be -1 for nil queue")
    testing.expect(t, queue2.len(&cursor) == 0, "len should be 0 for nil queue")
}

// Test initialization with empty queue
@(test)
test_init_empty :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)
    testing.expect(t, cursor.idx == -1, "idx should be -1 for empty queue")
    testing.expect(t, queue2.len(&cursor) == 0, "len should be 0 for empty queue")
}

// Test initialization with non-empty queue
@(test)
test_init_nonempty :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 1)
    queue.push(&q, 2)
    queue.push(&q, 3)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)
    testing.expect(t, cursor.idx == 0, "idx should be 0 for non-empty queue")
    testing.expect(t, queue2.len(&cursor) == 3, "len should be 3")
}

// Test current element retrieval
@(test)
test_current :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 10)
    queue.push(&q, 20)
    queue.push(&q, 30)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    // Test initial current
    testing.expect(t, queue2.current(&cursor) == 10, "current should be first element")

    // Test current after moving cursor
    cursor.idx = 1
    testing.expect(t, queue2.current(&cursor) == 20, "current should be second element")

    // Test current on empty queue
    empty_q: queue.Queue(int)
    queue2.init(&cursor, &empty_q)
    testing.expect(t, queue2.current(&cursor) == 0, "current should return zero value for empty queue")
}

// Test next navigation with wrapping
@(test)
test_next :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 1)
    queue.push(&q, 2)
    queue.push(&q, 3)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    // Test sequential next calls
    testing.expect(t, queue2.next(&cursor) == 2, "next should return second element")
    testing.expect(t, queue2.next(&cursor) == 3, "next should return third element")
    testing.expect(t, queue2.next(&cursor) == 1, "next should wrap to first element")

    // Test next on empty queue
    empty_q: queue.Queue(int)
    queue2.init(&cursor, &empty_q)
    testing.expect(t, queue2.next(&cursor) == 0, "next should return zero value for empty queue")
    testing.expect(t, cursor.idx == -1, "idx should be -1 for empty queue")
}

// Test previous navigation with wrapping
@(test)
test_prev :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 1)
    queue.push(&q, 2)
    queue.push(&q, 3)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    // Test sequential prev calls (should wrap backwards)
    testing.expect(t, queue2.prev(&cursor) == 3, "prev should wrap to last element")
    testing.expect(t, queue2.prev(&cursor) == 2, "prev should return second element")
    testing.expect(t, queue2.prev(&cursor) == 1, "prev should return first element")

    // Test prev on empty queue
    empty_q: queue.Queue(int)
    queue2.init(&cursor, &empty_q)
    testing.expect(t, queue2.prev(&cursor) == 0, "prev should return zero value for empty queue")
    testing.expect(t, cursor.idx == -1, "idx should be -1 for empty queue")
}

// Test next_nonzero functionality
@(test)
test_next_nonzero :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 0)
    queue.push(&q, 5)
    queue.push(&q, 0)
    queue.push(&q, 10)
    queue.push(&q, 0)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    // Should skip zero values
    testing.expect(t, queue2.next_nonzero(&cursor) == 5, "should find first non-zero")
    testing.expect(t, queue2.next_nonzero(&cursor) == 10, "should find next non-zero")
    testing.expect(t, queue2.next_nonzero(&cursor) == 5, "should wrap and find non-zero again")

    // Test with all zeros
    all_zero_q: queue.Queue(int)
    queue.push(&all_zero_q, 0)
    queue.push(&all_zero_q, 0)
    queue2.init(&cursor, &all_zero_q)
    testing.expect(t, queue2.next_nonzero(&cursor) == 0, "should return zero when all are zero")
}

// Test clamp functionality
@(test)
test_clamp :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 1)
    queue.push(&q, 2)
    queue.push(&q, 3)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    // Test clamping with positive out-of-range index
    cursor.idx = 5
    queue2.clamp(&cursor)
    testing.expect(t, cursor.idx == 2, "should clamp index 5 to 2 (5 % 3)")

    // Test clamping with negative index
    cursor.idx = -2
    queue2.clamp(&cursor)
    testing.expect(t, cursor.idx == 1, "should clamp index -2 to 1")

    // Test clamping with empty queue
    empty_q: queue.Queue(int)
    queue2.init(&cursor, &empty_q)
    cursor.idx = 5
    queue2.clamp(&cursor)
    testing.expect(t, cursor.idx == -1, "should set idx to -1 for empty queue")
}

// Test adjust_after_remove functionality
@(test)
test_adjust_after_remove :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 1)
    queue.push(&q, 2)
    queue.push(&q, 3)
    queue.push(&q, 4)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    // Test adjustment when removed index is before cursor
    cursor.idx = 3  // pointing to element 4
    queue2.adjust_after_remove(&cursor, 1)  // remove element at index 1
    testing.expect(t, cursor.idx == 2, "cursor should shift left when element before it is removed")

    // Test adjustment when removed index equals cursor index
    cursor.idx = 2
    queue2.adjust_after_remove(&cursor, 2)  // remove element at cursor position
    testing.expect(t, cursor.idx == 2, "cursor should stay at same index when pointing element is removed")

    // Test adjustment when removed index is after cursor
    cursor.idx = 1
    queue2.adjust_after_remove(&cursor, 3)  // remove element after cursor
    testing.expect(t, cursor.idx == 1, "cursor should not change when element after it is removed")

    // Test with empty queue
    empty_q: queue.Queue(int)
    queue2.init(&cursor, &empty_q)
    queue2.adjust_after_remove(&cursor, 0)
    testing.expect(t, cursor.idx == -1, "should set idx to -1 for empty queue")
}

// Test with different data types (string)
@(test)
test_string_queue :: proc(t: ^testing.T) {
    q: queue.Queue(string)
    queue.push(&q, "hello")
    queue.push(&q, "world")
    queue.push(&q, "test")

    cursor: queue2.Queue2(string)
    queue2.init(&cursor, &q)

    testing.expect(t, queue2.current(&cursor) == "hello", "current should work with strings")
    testing.expect(t, queue2.next(&cursor) == "world", "next should work with strings")
    testing.expect(t, queue2.prev(&cursor) == "test", "prev should work with strings")
}

// Test edge case with single element
@(test)
test_single_element :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 42)

    cursor: queue2.Queue2(int)
    queue2.init(&cursor, &q)

    testing.expect(t, cursor.idx == 0, "idx should be 0 for single element")
    testing.expect(t, queue2.current(&cursor) == 42, "current should return the single element")
    testing.expect(t, queue2.next(&cursor) == 42, "next should return the same element")
    testing.expect(t, queue2.prev(&cursor) == 42, "prev should return the same element")
}

// Test cursor behavior after queue modifications
@(test)
test_cursor_independence :: proc(t: ^testing.T) {
    q: queue.Queue(int)
    queue.push(&q, 1)
    queue.push(&q, 2)
    queue.push(&q, 3)

    cursor1: queue2.Queue2(int)
    cursor2: queue2.Queue2(int)
    queue2.init(&cursor1, &q)
    queue2.init(&cursor2, &q)

    // Move first cursor
    queue2.next(&cursor1)
    queue2.next(&cursor1)

    // Verify cursors are independent
    testing.expect(t, cursor1.idx == 2, "first cursor should be at index 2")
    testing.expect(t, cursor2.idx == 0, "second cursor should remain at index 0")
    testing.expect(t, queue2.current(&cursor1) == 3, "first cursor should point to element 3")
    testing.expect(t, queue2.current(&cursor2) == 1, "second cursor should point to element 1")
}
