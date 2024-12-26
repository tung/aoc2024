const std = @import("std");
const input = @embedFile("input08.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = input.len / (w + 1);

const Vec2 = struct {
    x: i16,
    y: i16,

    const Self = @This();

    pub inline fn is_in_bounds(self: Self) bool {
        return self.x >= 0 and self.x < w and self.y >= 0 and self.y < h;
    }

    pub inline fn add(self: Self, other: Self) Self {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub inline fn sub(self: Self, other: Self) Self {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var antennas = std.AutoHashMapUnmanaged(u8, std.ArrayListUnmanaged(Vec2)).empty;
    defer {
        var antennas_iter = antennas.valueIterator();
        while (antennas_iter.next()) |list| list.deinit(alloc);
        antennas.deinit(alloc);
    }

    // Find antennas and store their positions.
    for (0..h) |uy| {
        for (0..w) |ux| {
            switch (input[uy * (w + 1) + ux]) {
                '0'...'9', 'A'...'Z', 'a'...'z' => |c| {
                    const gop_res = try antennas.getOrPut(alloc, c);
                    if (!gop_res.found_existing) gop_res.value_ptr.* = .empty;
                    try gop_res.value_ptr.append(alloc, .{
                        .x = @intCast(ux),
                        .y = @intCast(uy),
                    });
                },
                else => {},
            }
        }
    }

    var antinodes = std.AutoHashMapUnmanaged(Vec2, void).empty;
    defer antinodes.deinit(alloc);

    // Calculate and store unique antinode positions.
    var same_freq_antennas = antennas.valueIterator();
    while (same_freq_antennas.next()) |positions| {
        for (positions.items[0..positions.items.len - 1], 0..) |a, a_idx| {
            for (positions.items[a_idx + 1..positions.items.len]) |b| {
                const a_past_b = b.add(b.sub(a));
                const b_past_a = a.add(a.sub(b));
                if (a_past_b.is_in_bounds()) try antinodes.put(alloc, a_past_b, {});
                if (b_past_a.is_in_bounds()) try antinodes.put(alloc, b_past_a, {});
            }
        }
    }

    std.debug.print("{d}\n", .{antinodes.count()});
}

test "decls" {
    std.testing.refAllDecls(@This());
}
