const std = @import("std");

fn readFileContents(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.openFileAbsolute(filename, .{ .mode = .read_only });
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

const Options = struct {
    format: []const u8 = "BAT0: %percent$2%",
};

pub fn module_battery(output: anytype, allocator: std.mem.Allocator, options: ?std.StringHashMap([]const u8)) !void {
    var userOptions: Options = .{};
    if (options) |customizedOptions| {
        if (customizedOptions.get("format")) |value| {
            userOptions.format = value;
        }
    }

    const eFullContents = try readFileContents("/sys/class/power_supply/BAT0/energy_full", allocator);
    defer allocator.free(eFullContents);
    const eFull = try std.fmt.parseInt(u32, eFullContents[0 .. eFullContents.len - 1], 10);

    const eFullDesignContents = try readFileContents("/sys/class/power_supply/BAT0/energy_full_design", allocator);
    defer allocator.free(eFullDesignContents);
    const eFullDesign = try std.fmt.parseInt(u32, eFullDesignContents[0 .. eFullDesignContents.len - 1], 10);

    const eNowContents = try readFileContents("/sys/class/power_supply/BAT0/energy_now", allocator);
    defer allocator.free(eNowContents);
    const eNow = try std.fmt.parseInt(u32, eNowContents[0 .. eNowContents.len - 1], 10);

    const eStateContents = try readFileContents("/sys/class/power_supply/BAT0/status", allocator);
    defer allocator.free(eStateContents);

    const percent = 100 * @as(f32, @floatFromInt(eNow)) / @as(f32, @floatFromInt(eFull));
    const realPercent = 100 * @as(f32, @floatFromInt(eNow)) / @as(f32, @floatFromInt(eFullDesign));

    const formatFullText = @import("../format.zig").formatFullText;

    const full_text = try formatFullText(userOptions.format, &.{
        .{ .name = "percent", .value = .{ .Number = percent } },
        .{ .name = "real_percent", .value = .{ .Number = realPercent } },
        .{ .name = "capacity", .value = .{ .Number = @as(f32, @floatFromInt(eFull)) / 1000000 } },
        .{ .name = "state", .value = .{ .Slice = eStateContents[0 .. eStateContents.len - 1] } },
    }, allocator);

    defer allocator.free(full_text);

    try output.writeAll("{");
    try output.print("\"full_text\": \"{s}\", ", .{full_text});
    try output.writeAll("\"color\": \"#00ff00\"");
    try output.writeAll("}");
}
