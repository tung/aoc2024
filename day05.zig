const std = @import("std");
const input = @embedFile("input05.txt");
const Rules = std.hash_map.AutoHashMapUnmanaged(u8, std.ArrayListUnmanaged(u8));

fn bad_pages(rules: *const Rules, pages: []u8) bool {
    for (0..pages.len - 1) |b| {
        const before = pages[b];
        for (b + 1..pages.len) |a| {
            const after = pages[a];
            if (rules.get(after)) |a_after_nums| {
                if (std.mem.indexOfScalar(u8, a_after_nums.items, before)) |_| {
                    return true;
                }
            }
        }
    }
    return false;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const alloc = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var rules = Rules.empty;
    defer {
        var rules_iter = rules.valueIterator();
        while (rules_iter.next()) |after_nums| after_nums.deinit(alloc);
        rules.deinit(alloc);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');

    // Read rule lines into a hash map.
    while (lines.next()) |line| {
        if (line.len == 0) break;

        var rule_nums = std.mem.splitScalar(u8, line, '|');
        const before_num_str = rule_nums.next() orelse return error.MissingRuleBeforeNumber;
        const after_num_str = rule_nums.next() orelse return error.MissingRuleAfterNumber;
        const before_num = try std.fmt.parseInt(u8, before_num_str, 10);
        const after_num = try std.fmt.parseInt(u8, after_num_str, 10);

        const gop_res = try rules.getOrPut(alloc, before_num);
        if (!gop_res.found_existing) gop_res.value_ptr.* = std.ArrayListUnmanaged(u8).empty;
        const after_list = gop_res.value_ptr;
        try after_list.append(alloc, after_num);
    }

    // Process page update list lines.
    var total: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) break;

        var pages = std.ArrayListUnmanaged(u8).empty;
        defer pages.deinit(alloc);

        var page_nums = std.mem.splitScalar(u8, line, ',');
        while (page_nums.next()) |page_num_str| {
            const page_num = try std.fmt.parseInt(u8, page_num_str, 10);
            try pages.append(alloc, page_num);
        }

        if (!bad_pages(&rules, pages.items)) total += pages.items[pages.items.len / 2];
    }

    std.debug.print("{d}\n", .{ total });
}
