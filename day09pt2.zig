const std = @import("std");
const input = @embedFile("input09.txt");

const File = struct { pos: u32, len: u32, id: u32 };
const Gap = struct { pos: u32, len: u32 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var files = std.ArrayListUnmanaged(File).empty;
    defer files.deinit(alloc);

    var gaps = std.ArrayListUnmanaged(Gap).empty;
    defer gaps.deinit(alloc);

    var next_pos: u32 = 0;
    var next_id: u32 = 0;
    var c: usize = 0;
    while (c < input.len and input[c] >= '0' and input[c] <= '9') {
        try files.append(alloc, .{
            .pos = next_pos,
            .len = input[c] - '0',
            .id = next_id,
        });
        next_pos += input[c] - '0';
        next_id += 1;

        c += 1;
        if (c >= input.len or input[c] < '0' or input[c] > '9') break;

        try gaps.append(alloc, .{
            .pos = next_pos,
            .len = input[c] - '0',
        });
        next_pos += input[c] - '0';

        c += 1;
    }

    for (0..files.items.len) |f_tmp| {
        const f = files.items.len - f_tmp - 1;
        var file = &files.items[f];
        var found_gap_index: ?usize = null;
        for (gaps.items, 0..) |*gap, i| {
            if (gap.pos > file.pos) break;
            if (gap.len >= file.len) {
                file.pos = gap.pos;
                gap.pos += file.len;
                gap.len -= file.len;
                found_gap_index = i;
                break;
            }
        }
        const g = found_gap_index orelse continue;
        if (gaps.items[g].len == 0) _ = gaps.orderedRemove(g);
    }

    var checksum: usize = 0;
    for (files.items) |file| {
        for (0..file.len) |offset| {
            checksum += (file.pos + offset) * file.id;
        }
    }
    std.debug.print("{d}\n", .{checksum});
}
