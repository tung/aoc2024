const std = @import("std");
const input = @embedFile("input04.txt");
const w = std.mem.indexOfScalar(u8, input, '\n').?;
const h = input.len / (w + 1);

fn charAt(x: isize, y: isize) ?u8 {
    if (x < 0 or x >= w or y < 0 or y >= h) return null;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    return input[uy * (w + 1) + ux];
}

fn find(word: []const u8, x: isize, y: isize, dx: isize, dy: isize) bool {
    var fx = x;
    var fy = y;
    for (word) |word_char| {
        const c = charAt(fx, fy) orelse return false;
        if (c != word_char) return false;
        fx += dx;
        fy += dy;
    }
    return true;
}

pub fn main() !void {
    std.debug.assert(input.len % (w + 1) == 0);

    var total: usize = 0;
    for (0..h) |y| {
        const iy: isize = @intCast(y);
        for (0..w) |x| {
            const ix: isize = @intCast(x);
            if (find("XMAS", ix, iy, -1, -1)) total += 1;
            if (find("XMAS", ix, iy, -1,  0)) total += 1;
            if (find("XMAS", ix, iy, -1,  1)) total += 1;
            if (find("XMAS", ix, iy,  0, -1)) total += 1;
            if (find("XMAS", ix, iy,  0,  1)) total += 1;
            if (find("XMAS", ix, iy,  1, -1)) total += 1;
            if (find("XMAS", ix, iy,  1,  0)) total += 1;
            if (find("XMAS", ix, iy,  1,  1)) total += 1;
        }
    }
    std.debug.print("{d}\n", .{ total });
}
