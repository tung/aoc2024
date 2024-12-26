const std = @import("std");
const input = @embedFile("input01.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) @panic("GPA LEAK");

    var list1 = std.ArrayList(i32).init(allocator);
    defer list1.deinit();
    var list2 = std.ArrayList(i32).init(allocator);
    defer list2.deinit();

    var num_strings = std.mem.tokenizeAny(u8, input, " \n");
    while (num_strings.next()) |num_string| {
        try list1.append(try std.fmt.parseInt(i32, num_string, 10));
        const num_string2 = num_strings.next().?;
        try list2.append(try std.fmt.parseInt(i32, num_string2, 10));
    }

    std.mem.sortUnstable(i32, list1.items, {}, comptime std.sort.asc(i32));
    std.mem.sortUnstable(i32, list2.items, {}, comptime std.sort.asc(i32));

    var total_distance: i64 = 0;
    for (list1.items, list2.items) |item1, item2| {
        total_distance += @abs(item2 - item1);
    }

    std.debug.print("{d}\n", .{ total_distance });
}
