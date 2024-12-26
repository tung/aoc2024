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

    pub inline fn div_exact(self: Self, divisor: i16) Self {
        return .{ .x = @divExact(self.x, divisor), .y = @divExact(self.y, divisor) };
    }
};

fn gcd(in_a: i16, in_b: i16) i16 {
    if (in_a == 0 or in_b == 0) return 0;
    var a = in_a;
    var b = in_b;
    while (b != 0) {
        const tmp = b;
        b = @mod(a, b);
        a = tmp;
    }
    return a;
}

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
                // Start at a and step in the direction of b until out of bounds.
                var dir = b.sub(a);
                dir = dir.div_exact(gcd(
                    dir.x * std.math.sign(dir.x),
                    dir.y * std.math.sign(dir.y),
                ));
                var c = a;
                while (c.is_in_bounds()) {
                    try antinodes.put(alloc, c, {});
                    c = c.add(dir);
                }

                // Repeat, but go in the direction of b to a.
                dir = a.sub(b);
                dir = dir.div_exact(gcd(
                    dir.x * std.math.sign(dir.x),
                    dir.y * std.math.sign(dir.y),
                ));
                c = a;
                while (c.is_in_bounds()) {
                    try antinodes.put(alloc, c, {});
                    c = c.add(dir);
                }
            }
        }
    }

    std.debug.print("{d}\n", .{antinodes.count()});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "gcd" {
    try std.testing.expectEqual(21, gcd(1071, 462));
}
