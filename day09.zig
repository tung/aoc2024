const std = @import("std");
const input = @embedFile("input09.txt");

const Filled = struct { pos: u32, id: u32 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var initial = std.ArrayListUnmanaged(Filled).empty;
    defer initial.deinit(alloc);

    var gaps = std.ArrayListUnmanaged(u32).empty;
    defer gaps.deinit(alloc);

    var next_pos: u32 = 0;
    var next_id: u32 = 0;
    var c: usize = 0;
    while (c < input.len and input[c] >= '0' and input[c] <= '9') {
        for (0..input[c] - '0') |_| {
            try initial.append(alloc, .{ .pos = next_pos, .id = next_id });
            next_pos += 1;
        }
        next_id += 1;

        c += 1;
        if (c >= input.len or input[c] < '0' or input[c] > '9') break;

        for (0..input[c] - '0') |_| {
            try gaps.append(alloc, next_pos);
            next_pos += 1;
        }

        c += 1;
    }

    var fill = std.ArrayListUnmanaged(Filled).empty;
    defer fill.deinit(alloc);

    for (gaps.items) |gap| {
        if (gap > initial.items[initial.items.len - 1].pos) break;
        try fill.append(alloc, .{ .pos = gap, .id = (initial.popOrNull() orelse break).id });
    }

    var checksum: usize = 0;
    for (initial.items) |i| checksum += i.pos * i.id;
    for (fill.items) |f| checksum += f.pos * f.id;
    std.debug.print("{d}\n", .{checksum});
}
