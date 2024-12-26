const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const List = std.ArrayListUnmanaged;
const Map = std.AutoHashMapUnmanaged;
const Links = Map([2]u8, List([2]u8));

fn asc_2_u8(context: void, a: [2]u8, b: [2]u8) bool {
    _ = context;
    if (a[0] == b[0]) return a[1] < b[1];
    return a[0] < b[0];
}

fn deinit_links(alloc: Allocator, links: *Links) void {
    var links_iter = links.valueIterator();
    while (links_iter.next()) |link| link.deinit(alloc);
    links.deinit(alloc);
}

fn read_links(alloc: Allocator, input: []const u8) !Links {
    var raw_links = Map([2]u8, Map([2]u8, void)).empty;
    defer {
        var raw_links_iter = raw_links.valueIterator();
        while (raw_links_iter.next()) |raw_link| raw_link.deinit(alloc);
        raw_links.deinit(alloc);
    }

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        std.debug.assert(line.len == 5);
        const idx: struct { usize, usize } = if (line[0] < line[3]) .{ 0, 3 } else .{ 3, 0 };
        const first = [2]u8{ line[idx[0]], line[idx[0] + 1] };
        const second = [2]u8{ line[idx[1]], line[idx[1] + 1] };
        const gop_1 = try raw_links.getOrPutValue(alloc, first, .empty);
        try gop_1.value_ptr.put(alloc, second, {});
        const gop_2 = try raw_links.getOrPutValue(alloc, second, .empty);
        try gop_2.value_ptr.put(alloc, first, {});
    }

    var links = Links.empty;
    errdefer deinit_links(alloc, &links);

    var raw_links_iter = raw_links.iterator();
    while (raw_links_iter.next()) |raw_link| {
        const gop_res = try links.getOrPutValue(alloc, raw_link.key_ptr.*, .empty);
        var it = raw_link.value_ptr.keyIterator();
        while (it.next()) |i| try gop_res.value_ptr.append(alloc, i.*);
        std.mem.sortUnstable([2]u8, gop_res.value_ptr.items, {}, asc_2_u8);
    }

    return links;
}

test "read_links" {
    const alloc = std.testing.allocator;
    const input =
        \\a1-b1
        \\a2-b2
        \\b2-c2
        \\a3-b3
        \\b3-c3
        \\c3-a3
        \\
        ;
    var links = try read_links(alloc, input);
    defer deinit_links(alloc, &links);

    try expectEqual(8, links.count());

    const a1 = links.get(.{ 'a', '1' }) orelse return error.Null;
    try expectEqual(1, a1.items.len);
    try expectEqual(.{ 'b', '1' }, a1.items[0]);
    const b1 = links.get(.{ 'b', '1' }) orelse return error.Null;
    try expectEqual(1, b1.items.len);
    try expectEqual(.{ 'a', '1' }, b1.items[0]);

    const a2 = links.get(.{ 'a', '2' }) orelse return error.Null;
    try expectEqual(1, a2.items.len);
    try expectEqual(.{ 'b', '2' }, a2.items[0]);
    const b2 = links.get(.{ 'b', '2' }) orelse return error.Null;
    try expectEqual(2, b2.items.len);
    try expectEqual(.{ 'a', '2' }, b2.items[0]);
    try expectEqual(.{ 'c', '2' }, b2.items[1]);
    const c2 = links.get(.{ 'c', '2' }) orelse return error.Null;
    try expectEqual(1, c2.items.len);
    try expectEqual(.{ 'b', '2' }, c2.items[0]);

    const a3 = links.get(.{ 'a', '3' }) orelse return error.Null;
    try expectEqual(2, a3.items.len);
    try expectEqual(.{ 'b', '3' }, a3.items[0]);
    try expectEqual(.{ 'c', '3' }, a3.items[1]);
    const b3 = links.get(.{ 'b', '3' }) orelse return error.Null;
    try expectEqual(2, b3.items.len);
    try expectEqual(.{ 'a', '3' }, b3.items[0]);
    try expectEqual(.{ 'c', '3' }, b3.items[1]);
    const c3 = links.get(.{ 'c', '3' }) orelse return error.Null;
    try expectEqual(2, c3.items.len);
    try expectEqual(.{ 'a', '3' }, c3.items[0]);
    try expectEqual(.{ 'b', '3' }, c3.items[1]);
}

fn count_3_loops_with_t(alloc: Allocator, input: []const u8) !usize {
    var links = try read_links(alloc, input);
    defer deinit_links(alloc, &links);

    var loops = List(Map([2]u8, void)).empty;
    defer {
        for (loops.items) |*loop| loop.deinit(alloc);
        loops.deinit(alloc);
    }

    var a_it = links.iterator();
    while (a_it.next()) |a| {
        const a_values = a.value_ptr;
        if (a_values.items.len == 0) continue;
        for (0..a_values.items.len - 1) |b| {
            for (b + 1..a_values.items.len) |c| {
                //std.debug.assert(asc_2_u8({}, a_values.items[b], a_values.items[c]));
                if (links.get(a_values.items[b])) |b_values| {
                    const found = for (b_values.items) |b_item| {
                        if (b_item[0] == a_values.items[c][0]
                            and b_item[1] == a_values.items[c][1])
                        {
                            break true;
                        }
                    } else blk: {
                        break :blk false;
                    };
                    if (found) {
                        var loop = Map([2]u8, void).empty;
                        errdefer loop.deinit(alloc);
                        try loop.put(alloc, a.key_ptr.*, {});
                        try loop.put(alloc, a_values.items[b], {});
                        try loop.put(alloc, a_values.items[c], {});
                        try loops.append(alloc, loop);
                    }
                }
            }
        }
    }

    var total: usize = 0;

    for (loops.items) |loop| {
        //std.debug.assert(loop.count() == 3);
        var it = loop.keyIterator();
        while (it.next()) |i| {
            if (i[0] == 't') {
                total += 1;
                break;
            }
        }
    }

    return @divFloor(total, 3);
}

test "example" {
    const alloc = std.testing.allocator;
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
        \\
        ;
    try expectEqual(7, try count_3_loops_with_t(alloc, input));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();
    print("{d}\n", .{try count_3_loops_with_t(alloc, @embedFile("input23.txt"))});
}

test "decls" {
    std.testing.refAllDecls(@This());
}
