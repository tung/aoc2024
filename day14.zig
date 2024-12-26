const std = @import("std");
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var robots = std.ArrayListUnmanaged(Robot).empty;
    defer robots.deinit(alloc);

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

    for (0..100) |_| {
        for (robots.items) |*r| {
            r.pos = r.pos.add(r.vel);
            if (r.pos.x < 0) r.pos.x += w;
            if (r.pos.x >= w) r.pos.x -= w;
            if (r.pos.y < 0) r.pos.y += h;
            if (r.pos.y >= h) r.pos.y -= h;
        }
    }

    var tl: usize = 0;
    var tr: usize = 0;
    var bl: usize = 0;
    var br: usize = 0;
    for (robots.items) |r| {
        if (r.pos.y < h / 2) {
            if (r.pos.x < w / 2) {
                tl += 1;
            } else if (r.pos.x > w / 2) {
                tr += 1;
            }
        } else if (r.pos.y > h / 2) {
            if (r.pos.x < w / 2) {
                bl += 1;
            } else if (r.pos.x > w / 2) {
                br += 1;
            }
        }
    }
    std.debug.print("{d}\n", .{tl * tr * bl * br});
}
