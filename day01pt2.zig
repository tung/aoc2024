const std = @import("std");
const input = @embedFile("input01.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) @panic("GPA LEAK");

    var list = std.ArrayList(u32).init(allocator);
    defer list.deinit();
    var map = std.AutoHashMap(u32, u64).init(allocator);
    defer map.deinit();

    var num_strings = std.mem.tokenizeAny(u8, input, " \n");
    while (num_strings.next()) |num_string| {
        try list.append(try std.fmt.parseInt(u32, num_string, 10));
        const num_string2 = num_strings.next().?;
        const key = try std.fmt.parseInt(u32, num_string2, 10);
        const prev_value = map.get(key) orelse 0;
        try map.put(key, prev_value + 1);
    }

    var similarity: u64 = 0;
    for (list.items) |item| {
        similarity += item * (map.get(item) orelse 0);
    }
    std.debug.print("{d}\n", .{ similarity });
}
