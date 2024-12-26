const std = @import("std");
const input = @embedFile("input16.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = input.len / (w + 1);

const Vec2 = struct {
    x: i32,
    y: i32,
    const Self = @This();
    pub fn from_xy(ux: usize, uy: usize) Self { return .{ .x = @intCast(ux), .y = @intCast(uy) }; }
    pub fn add(s: Self, o: Self) Self { return .{ .x = s.x + o.x, .y = s.y + o.y }; }
    pub fn rotate_left(s: Self) Self { return .{ .x = s.y, .y = -s.x }; }
    pub fn rotate_right(s: Self) Self { return .{ .x = -s.y, .y = s.x }; }
    pub fn find(c: u8) ?Self {
        const i = std.mem.indexOfScalar(u8, input, c) orelse return null;
        return .{ .x = @intCast(@mod(i, w + 1)), .y = @intCast(@divFloor(i, w + 1)) };
    }
    pub fn blocked(s: Self) bool {
        if (s.x < 0 or s.x >= w or s.y < 0 or s.y >= h) return true;
        const x: usize = @intCast(s.x);
        const y: usize = @intCast(s.y);
        return input[y * (w + 1) + x] == '#';
    }
};

const PosAndDir = struct { pos: Vec2, dir: Vec2 };

const Node = struct {
    pnd: PosAndDir,
    priority: i32,
    const Self = @This();
    pub fn compare(context: void, a: Self, b: Self) std.math.Order {
        _ = context;
        return std.math.order(a.priority, b.priority);
    }
};

fn heuristic(pos: Vec2, end: Vec2) i32 {
    return @as(i32, @intCast(@abs(end.x - pos.x))) + @as(i32, @intCast(@abs(end.y - pos.y)));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    const start = Vec2.find('S') orelse return error.StartNotFound;
    const end = Vec2.find('E') orelse return error.EndNotFound;
    const start_dir: Vec2 = .{ .x = 1, .y = 0 };

    var cost_so_far = std.AutoHashMapUnmanaged(PosAndDir, i32).empty;
    defer cost_so_far.deinit(alloc);
    try cost_so_far.put(alloc, .{ .pos = start, .dir = start_dir }, 0);

    var frontier = std.PriorityQueue(Node, void, Node.compare).init(alloc, {});
    defer frontier.deinit();
    try frontier.add(.{
        .pnd = .{ .pos = start, .dir = start_dir },
        .priority = heuristic(start, end),
    },);

    while (frontier.count() > 0) {
        const curr = frontier.remove();
        const curr_cost = cost_so_far.get(curr.pnd).?;

        if (curr.pnd.pos.x == end.x and curr.pnd.pos.y == end.y) {
            std.debug.print("{d}\n", .{curr_cost});
            break;
        }

        // Step forward.
        const fwd_dir = curr.pnd.dir;
        const fwd: PosAndDir = .{ .pos = curr.pnd.pos.add(curr.pnd.dir), .dir = fwd_dir };
        if (!fwd.pos.blocked()) {
            const fwd_cost_so_far = cost_so_far.get(fwd) orelse std.math.maxInt(i32);
            const new_fwd_cost = curr_cost + 1;
            if (new_fwd_cost < fwd_cost_so_far) {
                try cost_so_far.put(alloc, fwd, new_fwd_cost);
                try frontier.add(.{
                    .pnd = fwd,
                    .priority = new_fwd_cost + heuristic(fwd.pos, end),
                });
            }
        }

        // Rotate left and step forward.
        const left_dir = curr.pnd.dir.rotate_left();
        const left: PosAndDir = .{ .pos = curr.pnd.pos.add(left_dir), .dir = left_dir };
        if (!left.pos.blocked()) {
            const left_cost_so_far = cost_so_far.get(left) orelse std.math.maxInt(i32);
            const new_left_cost = curr_cost + 1001;
            if (new_left_cost < left_cost_so_far) {
                try cost_so_far.put(alloc, left, new_left_cost);
                try frontier.add(.{
                    .pnd = left,
                    .priority = new_left_cost + heuristic(left.pos, end),
                });
            }
        }

        // Rotate right and step forward.
        const right_dir = curr.pnd.dir.rotate_right();
        const right: PosAndDir = .{ .pos = curr.pnd.pos.add(right_dir), .dir = right_dir };
        if (!right.pos.blocked()) {
            const right_cost_so_far = cost_so_far.get(right) orelse std.math.maxInt(i32);
            const new_right_cost = curr_cost + 1001;
            if (new_right_cost < right_cost_so_far) {
                try cost_so_far.put(alloc, right, new_right_cost);
                try frontier.add(.{
                    .pnd = right,
                    .priority = new_right_cost + heuristic(right.pos, end),
                });
            }
        }
    }
}

test "decls" { std.testing.refAllDecls(@This()); }
