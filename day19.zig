const std = @import("std");

const Globals = struct {
    alloc: std.mem.Allocator,
    input: []const u8,
    patterns: std.ArrayListUnmanaged([]const u8),
    designs: std.ArrayListUnmanaged([]const u8),

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

        return .{
            .alloc = alloc,
            .input = input,
            .patterns = patterns,
            .designs = designs,
        };
    }

    pub fn deinit(self: *Self) void {
        self.patterns.deinit(self.alloc);
        self.designs.deinit(self.alloc);
    }
};

fn check(patterns: [][]const u8, design: []const u8) bool {
    if (design.len == 0) return true;
    for (patterns) |pattern| {
        if (std.mem.startsWith(u8, design, pattern)) {
            if (check(patterns, design[pattern.len..])) {
                return true;
            }
        }
    }
    return false;
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
        possible += @intFromBool(check(g.patterns.items, design));
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

    const expected = [_]bool{ true, true, true, true, false, true, true, false };
    for (g.designs.items, expected) |d, e| {
        try std.testing.expectEqual(e, check(g.patterns.items, d));
    }
}
