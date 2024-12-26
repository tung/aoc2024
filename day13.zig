const std = @import("std");
const print = std.debug.print;

fn solve(ax: i64, ay: i64, bx: i64, by: i64, tx: i64, ty: i64) ?i64 {
    if (ax == 0) return null;

    const divisor = ax * by - ay * bx;
    if (divisor == 0) return null;

    const b = @divFloor(ax * ty - ay * tx, divisor);
    const a = @divFloor(tx - bx * b, ax);
    if (a * ax + b * bx != tx or a * ay + b * by != ty) return null;

    return 3 * a + b;
}

fn count_tokens(input: []const u8) !i64 {
    var total: i64 = 0;

    var num_strs = std.mem.tokenizeAny(u8, input, "\n :,+=ButonABPrizeXY");
    while (num_strs.next()) |ax_str| {
        const ay_str = num_strs.next() orelse return error.NoAY;
        const bx_str = num_strs.next() orelse return error.NoBX;
        const by_str = num_strs.next() orelse return error.NoBY;
        const tx_str = num_strs.next() orelse return error.NoTX;
        const ty_str = num_strs.next() orelse return error.NoTY;

        const ax = try std.fmt.parseInt(i64, ax_str, 10);
        const ay = try std.fmt.parseInt(i64, ay_str, 10);
        const bx = try std.fmt.parseInt(i64, bx_str, 10);
        const by = try std.fmt.parseInt(i64, by_str, 10);
        const tx = try std.fmt.parseInt(i64, tx_str, 10);
        const ty = try std.fmt.parseInt(i64, ty_str, 10);

        if (solve(ax, ay, bx, by, tx, ty)) |solution| total += solution;
    }

    return total;
}

pub fn main() !void {
    print("{d}\n", .{try count_tokens(@embedFile("input13.txt"))});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "example" {
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
        \\
        ;
    try std.testing.expectEqual(480, count_tokens(input));
}
