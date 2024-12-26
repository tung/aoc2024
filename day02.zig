const std = @import("std");
const input = @embedFile("input02.txt");

fn is_monotonic(nums: []i32) bool {
    if (nums.len < 2) return false;
    if (nums[0] == nums[1]) return false;

    var sign: i32 = 1;
    if (nums[0] > nums[1]) sign = -1;

    for (1..nums.len) |i| {
        const diff = (nums[i] - nums[i - 1]) * sign;
        if (diff < 1 or diff > 3) return false;
    }

    return true;
}

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}).init;
    const gpa = gpa_impl.allocator();
    defer std.debug.assert(gpa_impl.deinit() == .ok);

    var total_safe_reports: u32 = 0;

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var list = std.ArrayListUnmanaged(i32).empty;
        defer list.deinit(gpa);

        var num_strs = std.mem.tokenizeScalar(u8, line, ' ');
        while (num_strs.next()) |num_str| {
            const num = try std.fmt.parseInt(i32, num_str, 10);
            try list.append(gpa, num);
        }

        if (is_monotonic(list.items)) total_safe_reports += 1;
    }

    std.debug.print("{d}\n", .{ total_safe_reports });
}
