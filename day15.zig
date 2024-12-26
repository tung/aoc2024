const std = @import("std");
const input = @embedFile("input15.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = blk: {
    @setEvalBranchQuota(10000);
    break :blk std.mem.indexOf(u8, input, "\n\n").? / w;
};

const Vec2 = struct {
    x: i32,
    y: i32,
    const Self = @This();
    const List = std.ArrayListUnmanaged(Self);
    const Set = std.AutoHashMapUnmanaged(Self, void);
    pub fn from_u8(c: u8) ?Self {
        return switch (c) {
            '^' => .{ .x = 0, .y = -1 },
            'v' => .{ .x = 0, .y = 1 },
            '<' => .{ .x = -1, .y = 0 },
            '>' => .{ .x = 1, .y = 0 },
            else => null,
        };
    }
    pub fn add(s: Self, o: Self) Self {
        return .{ .x = s.x + o.x, .y = s.y + o.y };
    }
};

fn char_at(pos: Vec2) !u8 {
    if (pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h) return error.OutOfBounds;
    const x: usize = @intCast(pos.x);
    const y: usize = @intCast(pos.y);
    return input[y * (w + 1) + x];
}

fn do_move(alloc: std.mem.Allocator, pos: Vec2, dir: Vec2, boxes: *Vec2.Set) !bool {
    if (pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h) return false;
    if ((try char_at(pos)) == '#') return false;
    if (boxes.contains(pos)) {
        const next_pos = pos.add(dir);
        if (!try do_move(alloc, next_pos, dir, boxes)) return false;
        _ = boxes.remove(pos);
        try boxes.put(alloc, next_pos, {});
    }
    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var boxes = Vec2.Set.empty;
    defer boxes.deinit(alloc);

    for (0..h) |uy| {
        for (0..w) |ux| {
            const pos: Vec2 = .{ .x = @intCast(ux), .y = @intCast(uy) };
            if ((try char_at(pos)) == 'O') try boxes.put(alloc, pos, {});
        }
    }

    var moves = Vec2.List.empty;
    defer moves.deinit(alloc);

    for (input[(w + 1) * h..]) |c| {
        if (Vec2.from_u8(c)) |dir| try moves.append(alloc, dir);
    }

    var robot: Vec2 = blk: {
        const idx = std.mem.indexOfScalar(u8, input, '@').?;
        break :blk .{
            .x = @intCast(idx % (w + 1)),
            .y = @intCast(idx / (w + 1)),
        };
    };

    for (moves.items) |move| {
        const new_robot = robot.add(move);
        if (try do_move(alloc, new_robot, move, &boxes)) robot = new_robot;
    }

    var sum_coords: isize = 0;
    var box_iter = boxes.keyIterator();
    while (box_iter.next()) |b| sum_coords += b.x + b.y * 100;
    std.debug.print("{d}\n", .{sum_coords});
}

test "decls" { std.testing.refAllDecls(@This()); }
