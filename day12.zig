const std = @import("std");
const input = @embedFile("input12.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;

const Vec2 = struct {
    x: i16,
    y: i16,
    const Self = @This();
    const Set = std.AutoHashMapUnmanaged(Self, void);
    const List = std.ArrayListUnmanaged(Self);
    const dirs = [_]Self{
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
    };
    pub fn add(self: Self, other: Self) Self {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

fn char_at(pos: Vec2) u8 {
    return input[@as(usize, @intCast(pos.y)) * (w + 1) + @as(usize, @intCast(pos.x))];
}

fn extract_region(alloc: std.mem.Allocator, all_plots: *Vec2.Set, dest: *Vec2.Set) !void {
    var all_plots_iter = all_plots.keyIterator();
    const start_pos = (all_plots_iter.next() orelse return).*;
    const plant_type = char_at(start_pos);

    var next = Vec2.List.empty;
    defer next.deinit(alloc);
    try next.append(alloc, start_pos);

    while (next.popOrNull()) |curr_pos| {
        _ = all_plots.remove(curr_pos);
        try dest.put(alloc, curr_pos, {});
        for (Vec2.dirs) |dir| {
            const next_pos = curr_pos.add(dir);
            if (!all_plots.contains(next_pos)) continue;
            if (char_at(next_pos) != plant_type) continue;
            try next.append(alloc, next_pos);
        }
    }
}

fn perimeter(region: Vec2.Set) usize {
    var total: usize = 0;
    for (Vec2.dirs) |dir| {
        var region_iter = region.keyIterator();
        while (region_iter.next()) |r| total += @intFromBool(!region.contains(r.add(dir)));
    }
    return total;
}

fn price_one_region(alloc: std.mem.Allocator, all_plots: *Vec2.Set) !usize {
    var region = Vec2.Set.empty;
    defer region.deinit(alloc);
    try extract_region(alloc, all_plots, &region);
    return region.count() * perimeter(region);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var all_plots = Vec2.Set.empty;
    defer all_plots.deinit(alloc);

    for (input, 0..) |c, i| {
        if (c == '\n') continue;
        const x = @mod(i, w + 1);
        const y = @divFloor(i, w + 1);
        try all_plots.put(alloc, .{ .x = @intCast(x), .y = @intCast(y) }, {});
    }

    var total_cost: usize = 0;
    while (all_plots.count() > 0) {
        total_cost += try price_one_region(alloc, &all_plots);
    }
    std.debug.print("{d}\n", .{total_cost});
}
