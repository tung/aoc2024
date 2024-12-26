const std = @import("std");
const print = std.debug.print;
const input = @embedFile("input15.txt");
const input_w = std.mem.indexOfScalar(u8, input, '\n').?;
const input_h = blk: {
    @setEvalBranchQuota(10000);
    break :blk std.mem.indexOf(u8, input, "\n\n").? / input_w;
};
const w = input_w * 2;
const h = input_h;

const Vec2 = struct {
    x: i32,
    y: i32,
    const Self = @This();
    const List = std.ArrayListUnmanaged(Self);
    const Set = std.AutoHashMapUnmanaged(Self, void);
    const up = .{ .x = 0, .y = -1 };
    const down = .{ .x = 0, .y = 1 };
    const left = .{ .x = -1, .y = 0 };
    const right = .{ .x = 1, .y = 0 };
    pub fn from_xy(ux: usize, uy: usize) Self { return .{ .x = @intCast(ux), .y = @intCast(uy) }; }
    pub fn from_u8(c: u8) ?Self {
        return switch (c) {
            '^' => .up,
            'v' => .down,
            '<' => .left,
            '>' => .right,
            else => null,
        };
    }
    pub fn char_at(s: Self) !u8 {
        if (s.x < 0 or s.x >= input_w or s.y < 0 or s.y >= input_h) return error.OutOfBounds;
        const x: usize = @intCast(s.x);
        const y: usize = @intCast(s.y);
        return input[y * (input_w + 1) + x];
    }
    pub fn eq(s: Self, o: Self) bool { return s.x == o.x and s.y == o.y; }
    pub fn add(s: Self, o: Self) Self { return .{ .x = s.x + o.x, .y = s.y + o.y }; }
    pub fn double_x(s: Self) Self { return .{ .x = s.x * 2, .y = s.y }; }
    pub fn halve_x(s: Self) Self { return .{ .x = @divFloor(s.x, 2), .y = s.y }; }
};

fn render(robot: Vec2, boxes: Vec2.Set) !void {
    for (0..h) |uy| {
        for (0..w) |ux| {
            const pos = Vec2.from_xy(ux, uy);
            if (pos.eq(robot)) {
                print("@", .{});
            } else if (boxes.contains(pos)) {
                print("[", .{});
            } else if (boxes.contains(pos.add(.left))) {
                print("]", .{});
            } else if (try pos.halve_x().char_at() == '#') {
                print("#", .{});
            } else {
                print(".", .{});
            }
        }
        print("\n", .{});
    }
}

fn can_move(pos: Vec2, dir: Vec2, boxes: Vec2.Set) !bool {
    if (pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h) return false;
    if (try pos.halve_x().char_at() == '#') return false;
    const pos_left = pos.add(.left);
    if (boxes.contains(pos_left)) return can_move(pos_left, dir, boxes);
    if (boxes.contains(pos)) {
        if (dir.y != 0) {
            const vert = pos.add(dir);
            const vert_right = vert.add(.right);
            return try can_move(vert, dir, boxes) and try can_move(vert_right, dir, boxes);
        } else if (dir.eq(.left)) {
            return can_move(pos.add(.left), .left, boxes);
        } else if (dir.eq(.right)) {
            return can_move(pos.add(.right).add(.right), .right, boxes);
        } else {
            unreachable;
        }
    }
    return true;
}

fn push_any_box(alloc: std.mem.Allocator, pos: Vec2, dir: Vec2, boxes: *Vec2.Set) !void {
    const pos_left = pos.add(.left);
    if (boxes.contains(pos_left)) {
        try push_any_box(alloc, pos_left, dir, boxes);
    } else if (boxes.remove(pos)) {
        if (dir.y != 0) {
            const vert = pos.add(dir);
            const vert_right = vert.add(.right);
            try push_any_box(alloc, vert, dir, boxes);
            try push_any_box(alloc, vert_right, dir, boxes);
        } else if (dir.eq(.left)) {
            try push_any_box(alloc, pos.add(.left), .left, boxes);
        } else if (dir.eq(.right)) {
            try push_any_box(alloc, pos.add(.right).add(.right), .right, boxes);
        } else {
            unreachable;
        }
        try boxes.put(alloc, pos.add(dir), {});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var boxes = Vec2.Set.empty;
    defer boxes.deinit(alloc);

    for (0..input_h) |uy| {
        for (0..input_w) |ux| {
            const pos = Vec2.from_xy(ux, uy);
            if (try pos.char_at() == 'O') try boxes.put(alloc, pos.double_x(), {});
        }
    }

    var moves = Vec2.List.empty;
    defer moves.deinit(alloc);

    for (input[(input_w + 1) * input_h..]) |c| {
        if (Vec2.from_u8(c)) |dir| try moves.append(alloc, dir);
    }

    var robot: Vec2 = blk: {
        const idx = std.mem.indexOfScalar(u8, input, '@').?;
        break :blk .{
            .x = @intCast(idx % (input_w + 1) * 2),
            .y = @intCast(idx / (input_w + 1)),
        };
    };

    for (moves.items) |dir| {
        const new_robot = robot.add(dir);
        if (try can_move(new_robot, dir, boxes)) {
            try push_any_box(alloc, new_robot, dir, &boxes);
            robot = new_robot;
        }
    }

    //try render(robot, boxes);

    var sum_coords: isize = 0;
    var boxes_iter = boxes.keyIterator();
    while (boxes_iter.next()) |b| sum_coords += b.x + b.y * 100;
    print("{d}\n", .{sum_coords});
}

test "decls" { std.testing.refAllDecls(@This()); }
