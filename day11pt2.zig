const std = @import("std");
const input = @embedFile("input11.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var curr = std.AutoHashMapUnmanaged(usize, usize).empty;
    defer curr.deinit(alloc);
    var next = std.AutoHashMapUnmanaged(usize, usize).empty;
    defer next.deinit(alloc);

    var nums = std.mem.tokenizeAny(u8, input, " \n");
    while (nums.next()) |num_str| {
        const num = try std.fmt.parseInt(usize, num_str, 10);
        try curr.put(alloc, num, 1);
    }

    for (0..75) |_| {
        var curr_entries = curr.iterator();
        while (curr_entries.next()) |c| {
            const mark = c.key_ptr.*;
            const stones = c.value_ptr.*;
            if (mark == 0) {
                const one_entry = try next.getOrPutValue(alloc, 1, 0);
                one_entry.value_ptr.* += stones;
                continue;
            }
            const num_digits = std.math.log10_int(mark) + 1;
            if (num_digits & 1 == 0) {
                const factor = std.math.pow(usize, 10, num_digits / 2);
                const right = @mod(mark, factor);
                const left = @divFloor(mark - right, factor);
                const left_entry = try next.getOrPutValue(alloc, left, 0);
                left_entry.value_ptr.* += stones;
                const right_entry = try next.getOrPutValue(alloc, right, 0);
                right_entry.value_ptr.* += stones;
            } else {
                const multiply_entry = try next.getOrPutValue(alloc, mark * 2024, 0);
                multiply_entry.value_ptr.* += stones;
            }
        }
        std.mem.swap(std.AutoHashMapUnmanaged(usize, usize), &curr, &next);
        next.clearRetainingCapacity();
    }

    var total: usize = 0;
    var curr_values = curr.valueIterator();
    while (curr_values.next()) |c| total += c.*;

    std.debug.print("{d}\n", .{total});
}
