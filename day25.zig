const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const Allocator = std.mem.Allocator;
const List = std.ArrayListUnmanaged;

const Globals = struct {
    size: u8,
    locks: List([]u8),
    keys: List([]u8),

    const Self = @This();

    fn free_list(alloc: Allocator, list: *List([]u8)) void {
        for (list.items) |i| alloc.free(i);
        list.deinit(alloc);
    }

    pub fn init(alloc: Allocator, input: []const u8) !Self {
        var locks = List([]u8).empty;
        errdefer free_list(alloc, &locks);

        var keys = List([]u8).empty;
        errdefer free_list(alloc, &keys);

        const width = std.mem.indexOfScalar(u8, input, '\n') orelse return error.NoLines;

        const tmp = try alloc.alloc(?u8, width);
        defer alloc.free(tmp);

        var blocks = std.mem.tokenizeSequence(u8, input, "\n\n");
        while (blocks.next()) |block| {
            const block_type = block[0];

            for (tmp) |*t| t.* = null;

            var line_num: u8 = 0;
            var lines = std.mem.tokenizeScalar(u8, block, '\n');
            _ = lines.next();
            while (lines.next()) |line| : (line_num += 1) {
                for (line, tmp) |c, *t| {
                    if (c != block_type and t.* == null) t.* = line_num;
                }
            }

            const nums = try alloc.alloc(u8, width);
            errdefer alloc.free(nums);

            switch (block_type) {
                '#' => {
                    for (tmp, nums) |t, *n| n.* = t.?;
                    try locks.append(alloc, nums);
                },
                '.' => {
                    for (tmp, nums) |t, *n| n.* = 5 - t.?;
                    try keys.append(alloc, nums);
                },
                else => return error.BadBlockType,
            }
        }

        return .{
            .size = @intCast(width),
            .locks = locks,
            .keys = keys,
        };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        free_list(alloc, &self.locks);
        free_list(alloc, &self.keys);
    }
};

fn count_combos(g: Globals) usize {
    var total: usize = 0;
    for (g.locks.items) |lock| {
        for (g.keys.items) |key| {
            for (lock, key) |l, k| {
                if (l + k > g.size) break;
            } else total += 1;
        }
    }
    return total;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var g = try Globals.init(alloc, @embedFile("input25.txt"));
    defer g.deinit(alloc);

    print("{d}\n", .{count_combos(g)});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "example" {
    const alloc = std.testing.allocator;
    const input =
        \\#####
        \\.####
        \\.####
        \\.####
        \\.#.#.
        \\.#...
        \\.....
        \\
        \\#####
        \\##.##
        \\.#.##
        \\...##
        \\...#.
        \\...#.
        \\.....
        \\
        \\.....
        \\#....
        \\#....
        \\#...#
        \\#.#.#
        \\#.###
        \\#####
        \\
        \\.....
        \\.....
        \\#.#..
        \\###..
        \\###.#
        \\###.#
        \\#####
        \\
        \\.....
        \\.....
        \\.....
        \\#....
        \\#.#..
        \\#.#.#
        \\#####
        \\
        ;
    var g = try Globals.init(alloc, input);
    defer g.deinit(alloc);

    try expectEqual(2, g.locks.items.len);
    try expectEqualSlices(u8, &.{ 0, 5, 3, 4, 3 }, g.locks.items[0]);
    try expectEqualSlices(u8, &.{ 1, 2, 0, 5, 3 }, g.locks.items[1]);

    try expectEqual(3, g.keys.items.len);
    try expectEqualSlices(u8, &.{ 5, 0, 2, 1, 3 }, g.keys.items[0]);
    try expectEqualSlices(u8, &.{ 4, 3, 4, 0, 2 }, g.keys.items[1]);
    try expectEqualSlices(u8, &.{ 3, 0, 2, 0, 1 }, g.keys.items[2]);

    try expectEqual(3, count_combos(g));
}
