const std = @import("std");
const input = @embedFile("input06.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = input.len / (w + 1);

const Vec2 = struct {
    x: isize,
    y: isize,

    const Self = @This();

    pub inline fn eql(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub inline fn add(self: Self, other: Self) Self {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub inline fn rotate_right(self: Self) Self {
        return .{ .x = -self.y, .y = self.x };
    }

    pub inline fn is_in_bounds(self: Self) bool {
        return self.x >= 0 and self.x < w and self.y >= 0 and self.y < h;
    }

    pub inline fn is_blocked(self: Self) bool {
        if (!self.is_in_bounds()) return false;
        const idx = @as(usize, @intCast(self.y)) * (w + 1) + @as(usize, @intCast(self.x));
        return input[idx] == '#';
    }
};

const StepsTaken = struct {
    up: std.DynamicBitSetUnmanaged,
    down: std.DynamicBitSetUnmanaged,
    left: std.DynamicBitSetUnmanaged,
    right: std.DynamicBitSetUnmanaged,

    const Self = @This();

    pub fn init(alloc: *const std.mem.Allocator) !Self {
        var up = try std.DynamicBitSetUnmanaged.initEmpty(alloc.*, w * h);
        errdefer up.deinit(alloc.*);
        var down = try std.DynamicBitSetUnmanaged.initEmpty(alloc.*, w * h);
        errdefer down.deinit(alloc.*);
        var left = try std.DynamicBitSetUnmanaged.initEmpty(alloc.*, w * h);
        errdefer left.deinit(alloc.*);
        const right = try std.DynamicBitSetUnmanaged.initEmpty(alloc.*, w * h);
        errdefer up.deinit(alloc.*);
        return .{ .up = up, .down = down, .left = left, .right = right };
    }

    pub fn deinit(self: *Self, alloc: *const std.mem.Allocator) void {
        self.up.deinit(alloc.*);
        self.down.deinit(alloc.*);
        self.left.deinit(alloc.*);
        self.right.deinit(alloc.*);
    }

    pub fn clear(self: *Self) void {
        self.up.unsetAll();
        self.down.unsetAll();
        self.left.unsetAll();
        self.right.unsetAll();
    }

    inline fn index(pos: Vec2) !usize {
        if (!pos.is_in_bounds()) return error.OutOfBounds;
        return @as(usize, @intCast(pos.y)) * w + @as(usize, @intCast(pos.x));
    }

    pub fn is_in_loop(self: Self, pos: Vec2, delta: Vec2) !bool {
        const dir_steps = if (delta.y == -1) self.up
            else if (delta.y == 1) self.down
            else if (delta.x == -1) self.left
            else if (delta.x == 1) self.right
            else return error.BadDelta;
        return dir_steps.isSet(try Self.index(pos));
    }

    pub fn mark_step(self: *Self, pos: Vec2, delta: Vec2) !void {
        var dir_steps = if (delta.y == -1) self.up
            else if (delta.y == 1) self.down
            else if (delta.x == -1) self.left
            else if (delta.x == 1) self.right
            else return error.BadDelta;
        dir_steps.set(try Self.index(pos));
    }
};

fn guard_walk_loops(steps_taken: *StepsTaken, pos: Vec2, dir: Vec2, obs: Vec2) !bool {
    var gpos = pos;
    var gdelta = dir;
    steps_taken.clear();

    while (gpos.is_in_bounds()) {
        if (try steps_taken.is_in_loop(gpos, gdelta)) return true;
        try steps_taken.mark_step(gpos, gdelta);
        var forward = gpos.add(gdelta);
        while (forward.is_blocked() or forward.eql(obs)) {
            gdelta = gdelta.rotate_right();
            forward = gpos.add(gdelta);
        }
        gpos = gpos.add(gdelta);
    }

    return false;
}

pub fn main() !void {
    std.debug.assert(input.len % (w + 1) == 0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    var obs_places = std.AutoHashMapUnmanaged(Vec2, struct { pos: Vec2, dir: Vec2 }).empty;
    defer obs_places.deinit(alloc);

    const gpos_raw = std.mem.indexOfScalar(u8, input, '^') orelse return error.GuardNotFound;
    const gpos_init: Vec2 = .{
        .x = @intCast(gpos_raw % (w + 1)),
        .y = @intCast(@divFloor(gpos_raw, w + 1)),
    };
    var gpos = gpos_init;
    var gdelta: Vec2 = .{ .x = 0, .y = -1 };

    // Find potential places to put an obstruction.
    while (gpos.is_in_bounds()) {
        const front = gpos.add(gdelta);
        const right = gpos.add(gdelta.rotate_right());
        if (!front.is_blocked()) {
            _ = try obs_places.getOrPutValue(alloc, front, .{ .pos = gpos, .dir = gdelta });
        } else if (!right.is_blocked()) {
            _ = try obs_places.getOrPutValue(alloc, right, .{ .pos = gpos, .dir = gdelta });
        }
        while (gpos.add(gdelta).is_blocked()) {
            gdelta = gdelta.rotate_right();
        }
        gpos = gpos.add(gdelta);
    }

    var steps_taken = try StepsTaken.init(&alloc);
    defer steps_taken.deinit(&alloc);

    var good_obs_places: usize = 0;
    var obs_places_iter = obs_places.iterator();
    while (obs_places_iter.next()) |entry| {
        const obs = entry.key_ptr.*;
        const pos = entry.value_ptr.pos;
        const dir = entry.value_ptr.dir;
        good_obs_places += @intFromBool(try guard_walk_loops(&steps_taken, pos, dir, obs));
    }
    std.debug.print("{d}\n", .{ good_obs_places });
}
