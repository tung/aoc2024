const std = @import("std");

const Vec2 = struct {
    x: i16,
    y: i16,

    const Self = @This();
    const dirs = [_]Self{
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
    };

    pub fn Set(comptime V: type) type {
        return std.AutoHashMapUnmanaged(Self, V);
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
    input: []const u8,
    w: i16,
    h: i16,
    walls: Vec2.Set(u16),

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, w: i16, h: i16, input: []const u8) !Self {
        var walls = Vec2.Set(u16).empty;
        errdefer walls.deinit(alloc);

        var num_strs = std.mem.tokenizeAny(u8, input, ",\n");
        var i: u16 = 1;
        while (num_strs.next()) |x_str| : (i += 1) {
            const y_str = num_strs.next() orelse return error.MissingY;
            const x = try std.fmt.parseInt(i16, x_str, 10);
            const y = try std.fmt.parseInt(i16, y_str, 10);
            try walls.put(alloc, .{ .x = x, .y = y }, i);
        }

        return .{
            .alloc = alloc,
            .input = input,
            .w = w,
            .h = h,
            .walls = walls,
        };
    }

    pub fn deinit(self: *Self) void {
        self.walls.deinit(self.alloc);
    }

    pub inline fn in_bounds(self: Self, pos: Vec2) bool {
        return pos.x >= 0 and pos.x < self.w and pos.y >= 0 and pos.y < self.h;
    }
};

const Node = struct {
    pos: Vec2,
    priority: usize,

    const Self = @This();

    pub fn compare(context: void, a: Self, b: Self) std.math.Order {
        _ = context;
        return std.math.order(a.priority, b.priority);
    }
};

fn heuristic(pos: Vec2, end: Vec2) usize {
    return @as(usize, @intCast(@abs(end.x - pos.x))) + @as(usize, @intCast(@abs(end.y - pos.y)));
}

fn a_star(g: Globals, max_wall: u16) !?usize {
    const start: Vec2 = .{ .x = 0, .y = 0 };
    const end: Vec2 = .{
        .x = g.w - 1,
        .y = g.h - 1,
    };

    var cost_so_far = Vec2.Set(usize).empty;
    defer cost_so_far.deinit(g.alloc);
    try cost_so_far.put(g.alloc, start, 0);

    var frontier = std.PriorityQueue(Node, void, Node.compare).init(g.alloc, {});
    defer frontier.deinit();
    try frontier.add(.{
        .pos = start,
        .priority = heuristic(start, end),
    });

    while (frontier.removeOrNull()) |curr| {
        const curr_cost = cost_so_far.get(curr.pos) orelse return error.CurrCostMissing;

        if (curr.pos.eq(end)) return curr_cost;

        for (Vec2.dirs) |dir| {
            const next_pos = curr.pos.add(dir);
            if (!g.in_bounds(next_pos)) continue;
            const next_wall = g.walls.get(next_pos) orelse std.math.maxInt(u16);
            if (next_wall <= max_wall) continue;
            const next_cost = curr_cost + 1;
            const next_cost_so_far = cost_so_far.get(next_pos) orelse std.math.maxInt(usize);
            if (next_cost < next_cost_so_far) {
                try cost_so_far.put(g.alloc, next_pos, next_cost);
                try frontier.add(.{
                    .pos = next_pos,
                    .priority = next_cost + heuristic(next_pos, end),
                });
            }
        }
    }

    return null;
}

pub fn main() !void {
    const input = @embedFile("input18.txt");
    const w = 71;
    const h = 71;

    const max_wall = blk: {
        var args = std.process.args();
        _ = args.next() orelse break :blk 1024;
        const arg_1 = args.next() orelse break :blk 1024;
        break :blk try std.fmt.parseInt(u16, arg_1, 10);
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var g = try Globals.init(alloc, w, h, input);
    defer g.deinit();

    if (try a_star(g, max_wall)) |min_steps| {
        std.debug.print("{d}\n", .{min_steps});
    } else {
        std.debug.print("no path found\n", .{});
    }
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "example" {
    const alloc = std.testing.allocator;
    const input =
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0
        \\
        ;
    const w = 7;
    const h = 7;
    const max_wall = 12;

    var g = try Globals.init(alloc, w, h, input);
    defer g.deinit();

    try std.testing.expectEqual(22, try a_star(g, max_wall));
}
