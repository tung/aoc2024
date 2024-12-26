const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;

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

fn do_line(line: []const u8) !u64 {
    var prng = Prng.init(try std.fmt.parseInt(u64, line, 10));
    for (0..1999) |_| _ = prng.next();
    return prng.next();
}

fn do_lines(input: []const u8) !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| total += try do_line(line);
    return total;
}

pub fn main() !void {
    print("{d}\n", .{try do_lines(@embedFile("input22.txt"))});
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

test "example" {
    const input =
        \\1
        \\10
        \\100
        \\2024
        \\
        ;
    try expectEqual(37327623, try do_lines(input));
}
