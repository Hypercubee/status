const std = @import("std");

const Options = struct {
    format: []const u8 = "example %symbol format %variable",
};

pub fn module_template(output: anytype, allocator: std.mem.Allocator, options: ?std.StringHashMap([]const u8)) !void {
    var userOptions: Options = .{};
    if (options) |customizedOptions| {
        if (customizedOptions.get("format")) |value| {
            userOptions.format = value;
        }
    }

    const example_value = 69;

    const format = @import("../format.zig");
    const full_text = try format.formatFullText(userOptions.format, &.{
        .{ .name = "variable", .value = .{ .Number = example_value } },
        .{ .name = "symbol", .value = .{ .Slice = "🔥" } },
    }, allocator);
    defer allocator.free(full_text);

    try output.writeAll("{");
    try output.print("\"full_text\": \"{s}\", ", .{full_text});
    try output.writeAll("\"color\": \"#00ff00\"");
    try output.writeAll("}");
}
