const std = @import("std");
const input = @embedFile("input07.txt");

inline fn concat(a: usize, b: usize) usize {
    return a * std.math.pow(usize, 10, std.math.log10_int(b) + 1) + b;
}

fn check(target: usize, acc: usize, nums: []usize) bool {
    if (nums.len == 0) return acc == target;
    return check(target, acc + nums[0], nums[1..])
        or check(target, acc * nums[0], nums[1..])
        or check(target, concat(acc, nums[0]), nums[1..]);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    var sum: usize = 0;

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var num_strs = std.mem.tokenizeAny(u8, line, " :");

        const target_num_str = num_strs.next() orelse return error.NoTargetNumber;
        const target_num = try std.fmt.parseInt(usize, target_num_str, 10);

        const first_num_str = num_strs.next() orelse return error.NoFirstNumber;
        const first_num = try std.fmt.parseInt(usize, first_num_str, 10);

        var num_list = std.ArrayListUnmanaged(usize).empty;
        defer num_list.deinit(alloc);

        while (num_strs.next()) |num_str| {
            const num = try std.fmt.parseInt(usize, num_str, 10);
            try num_list.append(alloc, num);
        }

        if (check(target_num, first_num, num_list.items)) sum += target_num;
    }

    std.debug.print("{d}\n", .{ sum });
}
