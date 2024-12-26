const std = @import("std");
const input = @embedFile("input03.txt");

fn literal(memory: []const u8, lit: []const u8) ?usize {
    return if (std.mem.startsWith(u8, memory, lit)) lit.len else null;
}

fn number(memory: []const u8) ?struct { value: i32, adv: usize } {
    const num_end = std.mem.indexOfNone(u8, memory, "0123456789") orelse return null;
    if (num_end > 3) return null;
    const num_value = std.fmt.parseInt(i32, memory[0..num_end], 10) catch return null;
    return .{ .value = num_value, .adv = num_end };
}

fn mul(memory: []const u8) ?struct { value: i32, adv: usize } {
    var match = memory;
    var match_len: usize = 0;

    const adv_mul = literal(match, "mul(") orelse return null;
    match = match[adv_mul..];
    match_len += adv_mul;

    const num_1_ret = number(match) orelse return null;
    const num_1 = num_1_ret.value;
    match = match[num_1_ret.adv..];
    match_len += num_1_ret.adv;

    const adv_comma = literal(match, ",") orelse return null;
    match = match[adv_comma..];
    match_len += adv_comma;

    const num_2_ret = number(match) orelse return null;
    const num_2 = num_2_ret.value;
    match = match[num_2_ret.adv..];
    match_len += num_2_ret.adv;

    const adv_close_paren = literal(match, ")") orelse return null;
    match = match[adv_close_paren..];
    match_len += adv_close_paren;

    return .{ .value = num_1 * num_2, .adv = match_len };
}

pub fn main() !void {
    var total: i64 = 0;
    var enabled = true;
    var memory: []const u8 = input;
    while (memory.len > 0) {
        if (mul(memory)) |mul_ret| {
            total += mul_ret.value * @intFromBool(enabled);
            memory = memory[mul_ret.adv..];
        } else if (literal(memory, "do()")) |adv| {
            enabled = true;
            memory = memory[adv..];
        } else if (literal(memory, "don't()")) |adv| {
            enabled = false;
            memory = memory[adv..];
        } else {
            memory = memory[1..];
        }
    }
    std.debug.print("{d}\n", .{ total });
}
