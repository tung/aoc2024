const std = @import("std");
const input = @embedFile("input11.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var curr = std.ArrayListUnmanaged(usize).empty;
    defer curr.deinit(alloc);
    var next = std.ArrayListUnmanaged(usize).empty;
    defer next.deinit(alloc);

    var nums = std.mem.tokenizeAny(u8, input, " \n");
    while (nums.next()) |num_str| try curr.append(alloc, try std.fmt.parseInt(usize, num_str, 10));

    for (0..25) |_| {
        for (curr.items) |c| {
            if (c == 0) {
                try next.append(alloc, 1);
                continue;
            }
            const num_digits = std.math.log10_int(c) + 1;
            if (num_digits & 1 == 0) {
                const factor = std.math.pow(usize, 10, num_digits / 2);
                const right = @mod(c, factor);
                const left = @divFloor(c - right, factor);
                try next.append(alloc, left);
                try next.append(alloc, right);
            } else {
                try next.append(alloc, c * 2024);
            }
        }
        std.mem.swap(std.ArrayListUnmanaged(usize), &curr, &next);
        next.items.len = 0;
    }

    std.debug.print("{d}\n", .{curr.items.len});
}
