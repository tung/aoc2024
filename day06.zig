const std = @import("std");
const input = @embedFile("input06.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = input.len / (w + 1);

fn in_bounds(x: isize, y: isize) bool {
    return x >= 0 and x < w and y >= 0 and y < h;
}

fn blocked(x: isize, y: isize) bool {
    if (!in_bounds(x, y)) return false;
    return input[@as(usize, @intCast(y)) * (w + 1) + @as(usize, @intCast(x))] == '#';
}

pub fn main() !void {
    std.debug.assert(input.len % (w + 1) == 0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    var unique_steps: usize = 0;
    var stepped = try std.DynamicBitSetUnmanaged.initEmpty(alloc, w * h);
    defer stepped.deinit(alloc);

    const gpos = std.mem.indexOfScalar(u8, input, '^') orelse return error.GuardNotFound;
    var gx: isize = @intCast(gpos % (w + 1));
    var gy: isize = @intCast(@divFloor(gpos, w + 1));
    var gdx: i2 = 0;
    var gdy: i2 = -1;

    while (in_bounds(gx, gy)) {
        const stepped_idx = @as(usize, @intCast(gy)) * w + @as(usize, @intCast(gx));
        if (!stepped.isSet(stepped_idx)) {
            stepped.set(stepped_idx);
            unique_steps += 1;
        }
        while (blocked(gx + gdx, gy + gdy)) {
            // Turn right.
            const old_gdx = gdx;
            gdx = -gdy;
            gdy = old_gdx;
        }
        gx += gdx;
        gy += gdy;
    }

    std.debug.print("{d}\n", .{ unique_steps });
}
