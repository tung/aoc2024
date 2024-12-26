const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;

fn Pair(comptime T: type) type {
    return struct { T, T };
}

const Pairs = struct {
    curr: u8,
    src: []const u8,
    end: ?u8,

    const Self = @This();

    pub fn init(src: []const u8, end: ?u8) Self {
        return .{
            .curr = 'A',
            .src = src,
            .end = end,
        };
    }

    pub fn next(self: *Self) ?Pair(u8) {
        if (self.src.len == 0) {
            if (self.end) |end| {
                const out: Pair(u8) = .{ self.curr, end };
                self.end = null;
                return out;
            } else {
                return null;
            }
        } else {
            const out: Pair(u8) = .{ self.curr, self.src[0] };
            self.curr = self.src[0];
            self.src = self.src[1..];
            return out;
        }
    }
};

test "Pairs" {
    var a = Pairs.init("", null);
    try expectEqual(null, a.next());

    var b = Pairs.init("", 'X');
    try expectEqual(.{ 'A', 'X' }, b.next());
    try expectEqual(null, b.next());

    var c = Pairs.init("BC", null);
    try expectEqual(.{ 'A', 'B' }, c.next());
    try expectEqual(.{ 'B', 'C' }, c.next());
    try expectEqual(null, c.next());

    var d = Pairs.init("DE", 'F');
    try expectEqual(.{ 'A', 'D' }, d.next());
    try expectEqual(.{ 'D', 'E' }, d.next());
    try expectEqual(.{ 'E', 'F' }, d.next());
    try expectEqual(null, d.next());
}

const Layout = struct {
    corner_gap: Pair(usize),
    keys: []const u8,
    key_coords: []const Pair(usize),
};

fn pad_presses(layout: Layout, pair: Pair(u8), pads_left: u8) !usize {
    if (pads_left == 0) return 1;
    if (pair[0] == pair[1]) return 1;

    const from_idx = std.mem.indexOfScalar(u8, layout.keys, pair[0]) orelse return error.BadFrom;
    const to_idx = std.mem.indexOfScalar(u8, layout.keys, pair[1]) orelse return error.BadTo;
    const from_x = layout.key_coords[from_idx][0];
    const from_y = layout.key_coords[from_idx][1];
    const to_x = layout.key_coords[to_idx][0];
    const to_y = layout.key_coords[to_idx][1];

    if (to_x == from_x) {
        // vertical movement
        if (to_y < from_y) {
            // move up
            const start = try dpad_presses(.{ 'A', '^' }, pads_left - 1);
            const mid = from_y - to_y - 1;
            const end = try dpad_presses(.{ '^', 'A' }, pads_left - 1);
            return start + mid + end;
        } else {
            // to_y > from_y // move down
            const start = try dpad_presses(.{ 'A', 'v' }, pads_left - 1);
            const mid = to_y - from_y - 1;
            const end = try dpad_presses(.{ 'v', 'A' }, pads_left - 1);
            return start + mid + end;
        }
    } else if (to_y == from_y) {
        // horizontal movement
        if (to_x < from_x) {
            // move left
            const start = try dpad_presses(.{ 'A', '<' }, pads_left - 1);
            const mid = from_x - to_x - 1;
            const end = try dpad_presses(.{ '<', 'A' }, pads_left - 1);
            return start + mid + end;
        } else {
            // to_x > from_x // move right
            const start = try dpad_presses(.{ 'A', '>' }, pads_left - 1);
            const mid = to_x - from_x - 1;
            const end = try dpad_presses(.{ '>', 'A' }, pads_left - 1);
            return start + mid + end;
        }
    } else {
        // diagonal movement
        // go horizontal then vertical or vice versa, whichever is less presses
        const h: u8 = if (to_x < from_x) '<' else '>';
        const v: u8 = if (to_y < from_y) '^' else 'v';
        const h_moves = @max(to_x, from_x) - @min(to_x, from_x) - 1;
        const v_moves = @max(to_y, from_y) - @min(to_y, from_y) - 1;
        const hv = blk: {
            if (layout.corner_gap[0] == to_x and layout.corner_gap[1] == from_y) {
                break :blk std.math.maxInt(usize);
            }
            const hv_start = try dpad_presses(.{ 'A', h }, pads_left - 1);
            const hv_turn = try dpad_presses(.{ h, v }, pads_left - 1);
            const hv_end = try dpad_presses(.{ v, 'A' }, pads_left - 1);
            break :blk hv_start + h_moves + hv_turn + v_moves + hv_end;
        };
        const vh = blk: {
            if (layout.corner_gap[0] == from_x and layout.corner_gap[1] == to_y) {
                break :blk std.math.maxInt(usize);
            }
            const vh_start = try dpad_presses(.{ 'A', v }, pads_left - 1);
            const vh_turn = try dpad_presses(.{ v, h }, pads_left - 1);
            const vh_end = try dpad_presses(.{ h, 'A' }, pads_left - 1);
            break :blk vh_start + v_moves + vh_turn + h_moves + vh_end;
        };
        return @min(hv, vh);
    }
}

fn dpad_presses(pair: Pair(u8), pads_left: u8) error{BadFrom, BadTo}!usize {
    const dpad_layout: Layout = .{
        .corner_gap = .{ 0, 0 },
        .keys = "^<v>A",
        .key_coords = &.{
            .{ 1, 0 }, // '^'
            .{ 0, 1 }, // '<'
            .{ 1, 1 }, // 'v'
            .{ 2, 1 }, // '>'
            .{ 2, 0 }, // 'A'
        },
    };
    return try pad_presses(dpad_layout, pair, pads_left);
}

fn numpad_presses(pair: Pair(u8), pads_left: u8) error{BadFrom, BadTo}!usize {
    const numpad_layout: Layout = .{
        .corner_gap = .{ 0, 3 },
        .keys = "0123456789A",
        .key_coords = &.{
            .{ 1, 3 }, // '0'
            .{ 0, 2 }, // '1'
            .{ 1, 2 }, // '2'
            .{ 2, 2 }, // '3'
            .{ 0, 1 }, // '4'
            .{ 1, 1 }, // '5'
            .{ 2, 1 }, // '6'
            .{ 0, 0 }, // '7'
            .{ 1, 0 }, // '8'
            .{ 2, 0 }, // '9'
            .{ 2, 3 }, // 'A'
        },
    };
    return try pad_presses(numpad_layout, pair, pads_left);
}

test "numpad_presses" {
    const cases = [_]struct {
        expected: usize,
        pair: Pair(u8),
        pads_left: u8,
    }{
        // 0 pads_left = direct human presses
        .{ .expected = 1, .pair = .{ 'A', 'A' }, .pads_left = 0 },
        .{ .expected = 1, .pair = .{ '0', '9' }, .pads_left = 0 },
        .{ .expected = 1, .pair = .{ '9', '0' }, .pads_left = 0 },
        // repeat presses = 1 human press
        .{ .expected = 1, .pair = .{ '5', '5' }, .pads_left = 0 },
        .{ .expected = 1, .pair = .{ '5', '5' }, .pads_left = 1 },
        .{ .expected = 1, .pair = .{ '5', '5' }, .pads_left = 2 },
        .{ .expected = 1, .pair = .{ '5', '5' }, .pads_left = 3 },
        // 1 pads_left going up from '0'
        .{ .expected = 2, .pair = .{ '0', '2' }, .pads_left = 1 },
        .{ .expected = 3, .pair = .{ '0', '5' }, .pads_left = 1 },
        .{ .expected = 4, .pair = .{ '0', '8' }, .pads_left = 1 },
        // 1 pads_left going down from '8'
        .{ .expected = 2, .pair = .{ '8', '5' }, .pads_left = 1 },
        .{ .expected = 3, .pair = .{ '8', '2' }, .pads_left = 1 },
        .{ .expected = 4, .pair = .{ '8', '0' }, .pads_left = 1 },
        // 1 pads_left going left from '6'
        .{ .expected = 2, .pair = .{ '6', '5' }, .pads_left = 1 },
        .{ .expected = 3, .pair = .{ '6', '4' }, .pads_left = 1 },
        // 1 pads_left going right from '4'
        .{ .expected = 2, .pair = .{ '4', '5' }, .pads_left = 1 },
        .{ .expected = 3, .pair = .{ '4', '6' }, .pads_left = 1 },
        // 1 pads_left going up-right to '9'
        .{ .expected = 3, .pair = .{ '5', '9' }, .pads_left = 1 },
        .{ .expected = 5, .pair = .{ '1', '9' }, .pads_left = 1 },
        // 1 pads_left going down-left to '1'
        .{ .expected = 3, .pair = .{ '5', '1' }, .pads_left = 1 },
        .{ .expected = 5, .pair = .{ '9', '1' }, .pads_left = 1 },
        // 1 pads_left going up-left to '7'
        .{ .expected = 3, .pair = .{ '5', '7' }, .pads_left = 1 },
        .{ .expected = 5, .pair = .{ '3', '7' }, .pads_left = 1 },
        // 1 pads_left going down-right to '3'
        .{ .expected = 3, .pair = .{ '5', '3' }, .pads_left = 1 },
        .{ .expected = 5, .pair = .{ '7', '3' }, .pads_left = 1 },
    };

    for (cases) |case| {
        expectEqual(case.expected, numpad_presses(case.pair, case.pads_left)) catch |err| {
            print("FAIL: expected {d}\tpair {c} {c}\tpads_left {d}\n", .{
                case.expected, case.pair[0], case.pair[1], case.pads_left
            });
            return err;
        };
    }
}

fn do_lines(input: []const u8, pads_left: u8) !usize {
    var total: usize = 0;

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const a_idx = std.mem.indexOfScalar(u8, line, 'A').?;
        const num = try std.fmt.parseInt(usize, line[0..a_idx], 10);

        var value: usize = 0;
        var pairs = Pairs.init(line, null);
        while (pairs.next()) |pair| {
            value += try numpad_presses(pair, pads_left);
        }

        total += num * value;
    }

    return total;
}

test "do_lines" {
    const input =
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
        \\
        ;
    try expectEqual(126384, try do_lines(input, 3));
}

pub fn main() !void {
    print("{d}\n", .{try do_lines(@embedFile("input21.txt"), 3)});
}

test "decls" {
    std.testing.refAllDecls(@This());
}
