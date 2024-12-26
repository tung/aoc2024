const std = @import("std");
const stdout = std.io.getStdOut().writer();
const input = @embedFile("input14.txt");
const w = 101;
const h = 103;

const Vec2 = struct {
    x: i32,
    y: i32,
    const Self = @This();
    pub inline fn add(self: Self, other: Self) Self {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

const Robot = struct {
    pos: Vec2,
    vel: Vec2,
};

fn overlap(
    alloc: std.mem.Allocator,
    robots: []const Robot,
    tmp: *std.AutoHashMapUnmanaged(Vec2, void),
) !bool {
    tmp.clearRetainingCapacity();
    for (robots) |r| {
        if (tmp.contains(r.pos)) return true;
        try tmp.put(alloc, r.pos, {});
    }
    return false;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var robots = std.ArrayListUnmanaged(Robot).empty;
    defer robots.deinit(alloc);

    var tmp = std.AutoHashMapUnmanaged(Vec2, void).empty;
    defer tmp.deinit(alloc);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const space_pos = std.mem.indexOfScalar(u8, line, ' ').?;
        const pos_str = line[2..space_pos];
        const vel_str = line[space_pos + 3..];
        const pos_comma_pos = std.mem.indexOfScalar(u8, pos_str, ',').?;
        const vel_comma_pos = std.mem.indexOfScalar(u8, vel_str, ',').?;
        const pos_x = try std.fmt.parseInt(i32, pos_str[0..pos_comma_pos], 10);
        const pos_y = try std.fmt.parseInt(i32, pos_str[pos_comma_pos + 1..], 10);
        const vel_x = try std.fmt.parseInt(i32, vel_str[0..vel_comma_pos], 10);
        const vel_y = try std.fmt.parseInt(i32, vel_str[vel_comma_pos + 1..], 10);
        try robots.append(alloc, .{
            .pos = .{ .x = pos_x, .y = pos_y },
            .vel = .{ .x = vel_x, .y = vel_y },
        });
    }

    var args = std.process.args();
    _ = args.next().?;
    const start = if (args.next()) |a| try std.fmt.parseInt(usize, a, 10) else 0;
    const count = if (args.next()) |a| try std.fmt.parseInt(usize, a, 10) else 10000;

    for (0..start + count) |i| {
        for (robots.items) |*r| {
            r.pos = r.pos.add(r.vel);
            if (r.pos.x < 0) r.pos.x += w;
            if (r.pos.x >= w) r.pos.x -= w;
            if (r.pos.y < 0) r.pos.y += h;
            if (r.pos.y >= h) r.pos.y -= h;
        }
        if (i < start) continue;
        if (try overlap(alloc, robots.items, &tmp)) continue;
        try stdout.print("{d}\n", .{i + 1});
        for (0..h) |y| {
            for (0..w) |x| {
                var found: bool = false;
                for (robots.items) |r| {
                    if (r.pos.x == x and r.pos.y == y) {
                        found = true;
                        break;
                    }
                }
                if (found) {
                    try stdout.print("#", .{});
                } else {
                    try stdout.print(".", .{});
                }
            }
            try stdout.print("\n", .{});
        }
    }
}
