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
    const start_pnd: PosAndDir = .{ .pos = start, .dir = .{ .x = 1, .y = 0 } };

    var came_from = std.AutoHashMapUnmanaged(PosAndDir, std.ArrayListUnmanaged(PosAndDir)).empty;
    defer {
        var came_from_iter = came_from.valueIterator();
        while (came_from_iter.next()) |cf| cf.deinit(alloc);
        came_from.deinit(alloc);
    }
    try came_from.put(alloc, start_pnd, .empty);

    var cost_so_far = std.AutoHashMapUnmanaged(PosAndDir, i32).empty;
    defer cost_so_far.deinit(alloc);
    try cost_so_far.put(alloc, start_pnd, 0);

    var frontier = std.PriorityQueue(Node, void, Node.compare).init(alloc, {});
    defer frontier.deinit();
    try frontier.add(.{ .pnd = start_pnd, .priority = heuristic(start, end) },);

    while (frontier.count() > 0) {
        const curr = frontier.remove();
        const curr_cost = cost_so_far.get(curr.pnd).?;

        if (curr.pnd.pos.x == end.x and curr.pnd.pos.y == end.y) {
            var visited = std.AutoHashMapUnmanaged(PosAndDir, void).empty;
            defer visited.deinit(alloc);

            var next = std.ArrayListUnmanaged(PosAndDir).empty;
            defer next.deinit(alloc);
            try next.append(alloc, curr.pnd);

            while (next.popOrNull()) |n| {
                if (visited.contains(n)) continue;
                try visited.put(alloc, n, {});
                const n_list = came_from.get(n) orelse continue;
                for (n_list.items) |cf| try next.append(alloc, cf);
            }

            var on_best_path = std.AutoHashMapUnmanaged(Vec2, void).empty;
            defer on_best_path.deinit(alloc);

            var visited_iter = visited.keyIterator();
            while (visited_iter.next()) |v| try on_best_path.put(alloc, v.pos, {});

            std.debug.print("{d}\n", .{on_best_path.count()});
            break;
        }

        const next_pos_and_dirs = [_]struct { pnd: PosAndDir, cost: i32 }{
            .{
                .pnd = .{
                    .pos = curr.pnd.pos.add(curr.pnd.dir),
                    .dir = curr.pnd.dir,
                },
                .cost = curr_cost + 1,
            },
            .{
                .pnd = .{
                    .pos = curr.pnd.pos.add(curr.pnd.dir.rotate_left()),
                    .dir = curr.pnd.dir.rotate_left(),
                },
                .cost = curr_cost + 1001,
            },
            .{
                .pnd = .{
                    .pos = curr.pnd.pos.add(curr.pnd.dir.rotate_right()),
                    .dir = curr.pnd.dir.rotate_right(),
                },
                .cost = curr_cost + 1001,
            },
        };

        for (next_pos_and_dirs) |npnd| {
            if (!npnd.pnd.pos.blocked()) {
                const npnd_cost_so_far = cost_so_far.get(npnd.pnd) orelse std.math.maxInt(i32);
                if (npnd.cost < npnd_cost_so_far) {
                    try cost_so_far.put(alloc, npnd.pnd, npnd.cost);
                    try frontier.add(.{
                        .pnd = npnd.pnd,
                        .priority = npnd.cost + heuristic(npnd.pnd.pos, end),
                    });
                }
                if (npnd.cost <= npnd_cost_so_far) {
                    var npnd_list = try came_from.getOrPutValue(alloc, npnd.pnd, .empty);
                    if (npnd.cost < npnd_cost_so_far) npnd_list.value_ptr.items.len = 0;
                    try npnd_list.value_ptr.append(alloc, curr.pnd);
                }
            }
        }
    }
}

test "decls" { std.testing.refAllDecls(@This()); }
