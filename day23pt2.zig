const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const List = std.ArrayListUnmanaged;
const Map = std.AutoHashMapUnmanaged;
const Links = Map([2]u8, Map([2]u8, void));

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
    var links = Map([2]u8, Map([2]u8, void)).empty;
    errdefer deinit_links(alloc, &links);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        std.debug.assert(line.len == 5);
        const idx: struct { usize, usize } = if (line[0] < line[3]) .{ 0, 3 } else .{ 3, 0 };
        const first = [2]u8{ line[idx[0]], line[idx[0] + 1] };
        const second = [2]u8{ line[idx[1]], line[idx[1] + 1] };
        const gop_1 = try links.getOrPutValue(alloc, first, .empty);
        try gop_1.value_ptr.put(alloc, second, {});
        const gop_2 = try links.getOrPutValue(alloc, second, .empty);
        try gop_2.value_ptr.put(alloc, first, {});
    }

    return links;
}

fn biggest_clump(alloc: Allocator, input: []const u8) !List([2]u8) {
    var graph = try read_links(alloc, input);
    defer deinit_links(alloc, &graph);

    var biggest_count: usize = 0;
    var biggest = Map([2]u8, void).empty;
    defer biggest.deinit(alloc);

    var tmp = Map([2]u8, void).empty;
    defer tmp.deinit(alloc);

    var graph_iter = graph.iterator();
    while (graph_iter.next()) |g| {
        if (g.value_ptr.count() <= biggest_count) continue;

        // Start by putting all fwd links into the tmp set.
        var fwd_iter = g.value_ptr.keyIterator();
        while (fwd_iter.next()) |f| try tmp.put(alloc, f.*, {});

        while (tmp.count() > biggest_count) {
            // Find tmp set member with the least intralinks, unless it links to everything in tmp.
            var least: ?[2]u8 = null;
            var least_intralinks = tmp.count() - 1;

            var tmp_iter = tmp.keyIterator();
            while (tmp_iter.next()) |t| {
                const back = graph.get(t.*).?;
                var intralinks: u32 = 0;
                var back_iter = back.keyIterator();
                while (back_iter.next()) |b| intralinks += @intFromBool(tmp.contains(b.*));
                if (intralinks < least_intralinks) {
                    least = t.*;
                    least_intralinks = intralinks;
                    if (intralinks == 0) break;
                }
            }

            // Remove the tmp set member with the least intralinks.
            if (least) |l| {
                _ = tmp.remove(l);
            } else {
                break;
            }
        }

        // Replace biggest with tmp if tmp is bigger.
        const tmp_count = tmp.count();
        if (tmp_count > biggest_count) {
            biggest_count = tmp_count;
            std.mem.swap(Map([2]u8, void), &biggest, &tmp);
            // Don't forget the key that we found this set in!
            try biggest.put(alloc, g.key_ptr.*, {});
        }
        tmp.clearRetainingCapacity();
    }

    var clump = List([2]u8).empty;
    errdefer clump.deinit(alloc);

    var biggest_iter = biggest.keyIterator();
    while (biggest_iter.next()) |b| try clump.append(alloc, b.*);
    std.mem.sortUnstable([2]u8, clump.items, {}, asc_2_u8);

    return clump;
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
    var clump = try biggest_clump(alloc, input);
    defer clump.deinit(alloc);
    try expectEqual(4, clump.items.len);
    try expectEqual(.{ 'c', 'o' }, clump.items[0]);
    try expectEqual(.{ 'd', 'e' }, clump.items[1]);
    try expectEqual(.{ 'k', 'a' }, clump.items[2]);
    try expectEqual(.{ 't', 'a' }, clump.items[3]);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var clump = try biggest_clump(alloc, @embedFile("input23.txt"));
    defer clump.deinit(alloc);

    std.debug.assert(clump.items.len > 0);
    print("{c}{c}", .{ clump.items[0][0], clump.items[0][1] });
    for (clump.items[1..]) |c| print(",{c}{c}", .{ c[0], c[1] });
    print("\n", .{});
}

test "decls" {
    std.testing.refAllDecls(@This());
}
