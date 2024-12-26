const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;
const SellNums = std.AutoHashMapUnmanaged([4]i8, i64);

const Prng = struct {
    secret: u64,

    const Self = @This();

    pub fn init(secret: u64) Self {
        return .{ .secret = secret };
    }

    pub fn next(self: *Self) u64 {
        self.secret = (self.secret ^ (self.secret <<| 6)) & ((1 << 24) - 1);
        self.secret = (self.secret ^ (self.secret >> 5)) & ((1 << 24) - 1);
        self.secret = (self.secret ^ (self.secret <<| 11)) & ((1 << 24) - 1);
        return self.secret;
    }
};

const RingBuf = struct {
    prng: Prng,
    nums: [5]i8,
    index: usize,

    const Self = @This();

    pub fn init(start: u64) Self {
        var prng = Prng.init(start);
        const nums = [5]i8{
            @intCast(start % 10),
            @intCast(prng.next() % 10),
            @intCast(prng.next() % 10),
            @intCast(prng.next() % 10),
            @intCast(prng.next() % 10),
        };
        return .{
            .prng = prng,
            .nums = nums,
            .index = 0,
        };
    }

    pub fn price(self: Self) i8 {
        var idx: usize = self.index;
        if (idx == 0) idx += self.nums.len;
        idx -= 1;
        return self.nums[idx];
    }

    pub fn changes(self: Self) [4]i8 {
        var ch: [4]i8 = undefined;
        var idx: usize = self.index;
        for (&ch) |*c| {
            const a = self.nums[idx];
            idx += 1;
            if (idx >= self.nums.len) idx -= self.nums.len;
            const b = self.nums[idx];
            c.* = b - a;
        }
        return ch;
    }

    pub fn advance(self: *Self) void {
        self.nums[self.index] = @intCast(self.prng.next() % 10);
        self.index += 1;
        if (self.index >= self.nums.len) self.index -= self.nums.len;
    }
};

test "RingBuf" {
    var a = RingBuf.init(123);
    try expectEqual(4, a.price());
    try expectEqual(.{ -3, 6, -1, -1 }, a.changes());
    for (0..4) |_| a.advance();
    try expectEqual(4, a.price());
    try expectEqual(.{ 0, 2, -2, 0 }, a.changes());
}

fn p2_do_line(alloc: std.mem.Allocator, line: []const u8, out: *SellNums) !void {
    out.clearRetainingCapacity();
    var rb = RingBuf.init(try std.fmt.parseInt(u64, line, 10));
    for (0..1996) |_| {
        _ = try out.getOrPutValue(alloc, rb.changes(), rb.price());
        rb.advance();
    }
}

fn p2_do_lines(alloc: std.mem.Allocator, input: []const u8) !isize {
    var tally = SellNums.empty;
    defer tally.deinit(alloc);

    var out = SellNums.empty;
    defer out.deinit(alloc);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try p2_do_line(alloc, line, &out);
        var out_iter = out.iterator();
        while (out_iter.next()) |o| {
            const t = try tally.getOrPutValue(alloc, o.key_ptr.*, 0);
            t.value_ptr.* += o.value_ptr.*;
        }
    }

    var max: isize = 0;
    var tally_iter = tally.valueIterator();
    while (tally_iter.next()) |t| max = @max(max, t.*);
    return max;
}

fn p1_do_line(line: []const u8) !u64 {
    var prng = Prng.init(try std.fmt.parseInt(u64, line, 10));
    for (0..1999) |_| _ = prng.next();
    return prng.next();
}

fn p1_do_lines(input: []const u8) !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| total += try p1_do_line(line);
    return total;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();
    print("{d}\n", .{try p2_do_lines(alloc, @embedFile("input22.txt"))});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "Prng" {
    const expected = [_]u64{
        15887950,
        16495136,
        527345,
        704524,
        1553684,
        12683156,
        11100544,
        12249484,
        7753432,
        5908254,
    };
    var p = Prng.init(123);
    for (expected) |ex| {
        try expectEqual(ex, p.next());
    }
}

test "p1_example" {
    const input =
        \\1
        \\10
        \\100
        \\2024
        \\
        ;
    try expectEqual(37327623, try p1_do_lines(input));
}

test "p2_example" {
    const alloc = std.testing.allocator;
    const input =
        \\1
        \\2
        \\3
        \\2024
        \\
        ;
    try expectEqual(23, try p2_do_lines(alloc, input));
}
