const std = @import("std");
const print = std.debug.print;

const Vec2 = struct {
    x: i16,
    y: i16,

    const Self = @This();
    const List = std.ArrayListUnmanaged(Self);
    const dirs = [_]Self{
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
    };

    pub fn Set(comptime T: type) type {
        return std.AutoHashMapUnmanaged(Self, T);
    }

    pub inline fn from_index(idx: usize, w: usize) Self {
        return .{
            .x = @intCast(@mod(idx, w + 1)),
            .y = @intCast(@divFloor(idx, w + 1)),
        };
    }

    pub inline fn eq(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub inline fn add(self: Self, other: Self) Self {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }
};

const Globals = struct {
    alloc: std.mem.Allocator,
    dist_from_end: Vec2.Set(i32),

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, input: []const u8) !Self {
        const w = std.mem.indexOfScalar(u8, input, '\n') orelse return error.MissingWidth;
        const start_idx = std.mem.indexOfScalar(u8, input, 'S') orelse return error.MissingStart;
        const end_idx = std.mem.indexOfScalar(u8, input, 'E') orelse return error.MissingEnd;
        const start = Vec2.from_index(start_idx, w);
        const end = Vec2.from_index(end_idx, w);

        var dist_from_end = Vec2.Set(i32).empty;
        errdefer dist_from_end.deinit(alloc);
        try dist_from_end.put(alloc, end, 0);

        var next = Vec2.List.empty;
        defer next.deinit(alloc);
        try next.append(alloc, end);
        while (next.popOrNull()) |n| {
            if (n.eq(start)) break;
            const dist = dist_from_end.get(n) orelse return error.MissingDistFromEnd;
            for (Vec2.dirs) |dir| {
                const new_pos = n.add(dir);
                if (dist_from_end.contains(new_pos)) continue;
                const ux: usize = @intCast(new_pos.x);
                const uy: usize = @intCast(new_pos.y);
                if (input[uy * (w + 1) + ux] == '#') continue;
                try dist_from_end.put(alloc, new_pos, dist + 1);
                try next.append(alloc, new_pos);
            }
        }

        return .{
            .alloc = alloc,
            .dist_from_end = dist_from_end,
        };
    }

    pub fn deinit(self: *Self) void {
        self.dist_from_end.deinit(self.alloc);
    }
};

fn count_shortcuts(
    dist_from_end: Vec2.Set(i32),
    max_len: i32,
    min_save: i32,
    max_save: i32,
) usize {
    var count: usize = 0;
    var dist_1_iter = dist_from_end.iterator();
    while (dist_1_iter.next()) |d1| {
        var dist_2_iter = dist_from_end.iterator();
        while (dist_2_iter.next()) |d2| {
            const pos_1 = d1.key_ptr.*;
            const pos_2 = d2.key_ptr.*;
            const pos_diff = @abs(pos_2.x - pos_1.x) + @abs(pos_2.y - pos_1.y);
            if (pos_diff > max_len) continue;

            const dist_1 = d1.value_ptr.*;
            const dist_2 = d2.value_ptr.*;
            const save = dist_1 - dist_2 - pos_diff;
            count += @intFromBool(save >= min_save and save <= max_save);
        }
    }
    return count;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var g = try Globals.init(alloc, @embedFile("input20.txt"));
    defer g.deinit();

    print("{d}\n", .{count_shortcuts(g.dist_from_end, 20, 100, std.math.maxInt(i32))});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "example" {
    const alloc = std.testing.allocator;
    const input =
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
        \\
        ;

    var g = try Globals.init(alloc, input);
    defer g.deinit();

    const cases = [_]struct{
        max_len: i32,
        save: i32,
        expected: usize,
    }{
        .{ .max_len = 2, .save = 2, .expected = 14 },
        .{ .max_len = 2, .save = 4, .expected = 14 },
        .{ .max_len = 2, .save = 6, .expected = 2 },
        .{ .max_len = 2, .save = 8, .expected = 4 },
        .{ .max_len = 2, .save = 10, .expected = 2 },
        .{ .max_len = 2, .save = 12, .expected = 3 },
        .{ .max_len = 2, .save = 20, .expected = 1 },
        .{ .max_len = 2, .save = 36, .expected = 1 },
        .{ .max_len = 2, .save = 38, .expected = 1 },
        .{ .max_len = 2, .save = 40, .expected = 1 },
        .{ .max_len = 2, .save = 64, .expected = 1 },
        .{ .max_len = 20, .save = 50, .expected = 32 },
        .{ .max_len = 20, .save = 52, .expected = 31 },
        .{ .max_len = 20, .save = 54, .expected = 29 },
        .{ .max_len = 20, .save = 56, .expected = 39 },
        .{ .max_len = 20, .save = 58, .expected = 25 },
        .{ .max_len = 20, .save = 60, .expected = 23 },
        .{ .max_len = 20, .save = 62, .expected = 20 },
        .{ .max_len = 20, .save = 64, .expected = 19 },
        .{ .max_len = 20, .save = 66, .expected = 12 },
        .{ .max_len = 20, .save = 68, .expected = 14 },
        .{ .max_len = 20, .save = 70, .expected = 12 },
        .{ .max_len = 20, .save = 72, .expected = 22 },
        .{ .max_len = 20, .save = 74, .expected = 4 },
        .{ .max_len = 20, .save = 76, .expected = 3 },
    };
    for (cases) |case| {
        try std.testing.expectEqual(
            case.expected,
            count_shortcuts(g.dist_from_end, case.max_len, case.save, case.save),
        );
    }
}
