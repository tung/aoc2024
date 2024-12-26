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

fn count_shortcuts(dist_from_end: Vec2.Set(i32), min_save: i32, max_save: i32) usize {
    var count: usize = 0;
    var dist_iter = dist_from_end.iterator();
    while (dist_iter.next()) |pos| {
        const pos_dist = pos.value_ptr.*;
        for (Vec2.dirs) |dir| {
            const step_1 = pos.key_ptr.add(dir);
            const step_2 = step_1.add(dir);
            if (dist_from_end.contains(step_1)) continue;
            const step_2_dist = dist_from_end.get(step_2) orelse continue;
            const save = pos_dist - step_2_dist - 2;
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

    print("{d}\n", .{count_shortcuts(g.dist_from_end, 100, std.math.maxInt(i32))});
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

    const cases = [_]struct{ save: i32, expected: usize }{
        .{ .save = 2, .expected = 14 },
        .{ .save = 4, .expected = 14 },
        .{ .save = 6, .expected = 2 },
        .{ .save = 8, .expected = 4 },
        .{ .save = 10, .expected = 2 },
        .{ .save = 12, .expected = 3 },
        .{ .save = 20, .expected = 1 },
        .{ .save = 36, .expected = 1 },
        .{ .save = 38, .expected = 1 },
        .{ .save = 40, .expected = 1 },
        .{ .save = 64, .expected = 1 },
    };
    for (cases) |case| {
        try std.testing.expectEqual(
            case.expected,
            count_shortcuts(g.dist_from_end, case.save, case.save),
        );
    }
}
