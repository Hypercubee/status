const std = @import("std");

const FormatValue = struct {
    value: f32,
    name: []const u8,
};

fn compareMatch(match: []const u8, matched_str: []const u8) bool {
    var i: usize = 0;
    if (matched_str.len < match.len) return false;
    while (i < match.len) : (i += 1) {
        // matched_str.len >= match.len
        if (matched_str[i] != match[i]) return false;
    }
    return true;
}

fn appendNumber(writer: anytype, number: f32, decimals: u3) !void {
    switch (decimals) {
        0 => {
            try writer.print("{d:.0}", .{number});
        },
        1 => {
            try writer.print("{d:.1}", .{number});
        },
        2 => {
            try writer.print("{d:.2}", .{number});
        },
        3 => {
            try writer.print("{d:.3}", .{number});
        },
        4 => {
            try writer.print("{d:.4}", .{number});
        },
        5 => {
            try writer.print("{d:.5}", .{number});
        },
        6 => {
            try writer.print("{d:.6}", .{number});
        },
        7 => {
            try writer.print("{d:.7}", .{number});
        },
    }
}

pub fn formatFullText(format_string: []const u8, fmtValues: []const FormatValue, allocator: std.mem.Allocator) ![]const u8 {
    var outputString = std.ArrayList(u8).init(allocator);
    defer outputString.deinit();
    var i: usize = 0;
    char_loop: while (i < format_string.len) : (i += 1) {
        if (format_string[i] == '%') {
            if (i + 1 < format_string.len and format_string[i + 1] == '%') {
                i += 1;
                continue :char_loop;
            }
            var fmtValueIndex: usize = 0;
            while (fmtValueIndex < fmtValues.len) : (fmtValueIndex += 1) {
                if (compareMatch(fmtValues[fmtValueIndex].name, format_string[i + 1 ..])) {
                    i += fmtValues[fmtValueIndex].name.len;
                    var decimals: u3 = 0;
                    if (i + 2 < format_string.len and format_string[i + 1] == '$') {
                        if (format_string[i + 2] >= '0' and format_string[i + 2] <= '7') {
                            decimals = @intCast(format_string[i + 2] - '0');
                            i += 1;
                        }
                        i += 1;
                    }
                    try appendNumber(outputString.writer(), fmtValues[fmtValueIndex].value, decimals);
                    //try outputString.writer().print("{d:.2}", .{fmtValues[fmtValueIndex].value});
                    continue :char_loop;
                }
            } else {
                try outputString.writer().writeByte(format_string[i]);
            }
        } else {
            try outputString.writer().writeByte(format_string[i]);
        }
    }
    return outputString.toOwnedSlice();
}
