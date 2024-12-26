const std = @import("std");
const input = @embedFile("input10.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = input.len / (w + 1);

const Vec2 = struct { x: i16, y: i16 };

inline fn char_at(pos: Vec2) u8 {
    return input[@as(usize, @intCast(pos.y)) * (w + 1) + @as(usize, @intCast(pos.x))];
}

fn trailhead_score(alloc: std.mem.Allocator, start: Vec2) !u32 {
    if (char_at(start) != '0') return 0;
    var curr = std.AutoHashMapUnmanaged(Vec2, void).empty;
    defer curr.deinit(alloc);
    var next = std.AutoHashMapUnmanaged(Vec2, void).empty;
    defer next.deinit(alloc);
    var next_height: u8 = '1';
    try curr.put(alloc, start, {});
    while (true) {
        var curr_keys = curr.keyIterator();
        while (curr_keys.next()) |curr_key| {
            const up: Vec2 = .{ .x = curr_key.x, .y = curr_key.y - 1 };
            const down: Vec2 = .{ .x = curr_key.x, .y = curr_key.y + 1 };
            const left: Vec2 = .{ .x = curr_key.x - 1, .y = curr_key.y };
            const right: Vec2 = .{ .x = curr_key.x + 1, .y = curr_key.y };
            if (curr_key.y > 0 and char_at(up) == next_height)
                try next.put(alloc, up, {});
            if (curr_key.y < h - 1 and char_at(down) == next_height)
                try next.put(alloc, down, {});
            if (curr_key.x > 0 and char_at(left) == next_height)
                try next.put(alloc, left, {});
            if (curr_key.x < w - 1 and char_at(right) == next_height)
                try next.put(alloc, right, {});
        }
        if (next_height == '9') break else next_height += 1;
        std.mem.swap(std.AutoHashMapUnmanaged(Vec2, void), &curr, &next);
        next.clearAndFree(alloc);
    }
    return next.count();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var total_score: u32 = 0;
    for (0..h) |y| {
        for (0..w) |x| {
            total_score += try trailhead_score(alloc, .{ .x = @intCast(x), .y = @intCast(y) });
        }
    }
    std.debug.print("{d}\n", .{total_score});
}

test "decls" {
    std.testing.refAllDecls(@This());
}
