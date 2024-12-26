const std = @import("std");

const Globals = struct {
    alloc: std.mem.Allocator,
    input: []const u8,
    patterns: std.ArrayListUnmanaged([]const u8),
    designs: std.ArrayListUnmanaged([]const u8),
    cache: std.StringHashMapUnmanaged(usize),

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, input: []const u8) !Self {
        var lines = std.mem.splitScalar(u8, input, '\n');

        var patterns = std.ArrayListUnmanaged([]const u8).empty;
        errdefer patterns.deinit(alloc);

        const pat_line = lines.next() orelse return error.MissingPatternsLine;
        var pat_strs = std.mem.tokenizeSequence(u8, pat_line, ", ");
        while (pat_strs.next()) |pat_str| try patterns.append(alloc, pat_str);

        var designs = std.ArrayListUnmanaged([]const u8).empty;
        errdefer designs.deinit(alloc);

        while (lines.next()) |line| {
            if (line.len > 0) {
                try designs.append(alloc, line);
            }
        }

        var cache = std.StringHashMapUnmanaged(usize).empty;
        errdefer cache.deinit(alloc);

        try cache.put(alloc, "", 1);

        return .{
            .alloc = alloc,
            .input = input,
            .patterns = patterns,
            .designs = designs,
            .cache = cache,
        };
    }

    pub fn deinit(self: *Self) void {
        self.patterns.deinit(self.alloc);
        self.designs.deinit(self.alloc);
        self.cache.deinit(self.alloc);
    }
};

fn check(
    alloc: std.mem.Allocator,
    cache: *std.StringHashMapUnmanaged(usize),
    patterns: [][]const u8,
    design: []const u8,
) !usize {
    if (cache.get(design)) |c| return c;
    var count: usize = 0;
    for (patterns) |pattern| {
        if (std.mem.startsWith(u8, design, pattern)) {
            count += try check(alloc, cache, patterns, design[pattern.len..]);
        }
    }
    try cache.put(alloc, design, count);
    return count;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    const input = @embedFile("input19.txt");

    var g = try Globals.init(alloc, input);
    defer g.deinit();

    var possible: usize = 0;
    for (g.designs.items) |design| {
        possible += try check(alloc, &g.cache, g.patterns.items, design);
    }
    std.debug.print("{d}\n", .{possible});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "example" {
    const alloc = std.testing.allocator;
    const input =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
        \\
        ;
    var g = try Globals.init(alloc, input);
    defer g.deinit();

    try std.testing.expectEqual(8, g.patterns.items.len);
    try std.testing.expectEqual(8, g.designs.items.len);

    const expected = [_]usize{ 2, 1, 4, 6, 0, 1, 2, 0 };
    for (g.designs.items, expected) |d, e| {
        try std.testing.expectEqual(e, try check(alloc, &g.cache, g.patterns.items, d));
    }
}
