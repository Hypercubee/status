const std = @import("std");

fn readFileContents(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.openFileAbsolute(filename, .{ .mode = .read_only });
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

const Options = struct {
    format: []const u8 = "BAT0: %percent$2%",
};

pub fn module_battery(output: anytype, allocator: std.mem.Allocator, options: Options) !void {
    const eFullContents = try readFileContents("/sys/class/power_supply/BAT0/energy_full", allocator);
    defer allocator.free(eFullContents);
    const eFull = try std.fmt.parseInt(u32, eFullContents[0 .. eFullContents.len - 1], 10);

    const eNowContents = try readFileContents("/sys/class/power_supply/BAT0/energy_now", allocator);
    defer allocator.free(eNowContents);
    const eNow = try std.fmt.parseInt(u32, eNowContents[0 .. eNowContents.len - 1], 10);

    const eStateContents = try readFileContents("/sys/class/power_supply/BAT0/status", allocator);
    defer allocator.free(eStateContents);

    const percent = 100 * @as(f32, @floatFromInt(eNow)) / @as(f32, @floatFromInt(eFull));

    const formatFullText = @import("../format.zig").formatFullText;
    const full_text = try formatFullText(options.format, &.{
        .{ .name = "percent", .value = percent },
    }, allocator);

    defer allocator.free(full_text);

    try output.writeAll("{");
    try output.print("\"full_text\": \"{s}\", ", .{full_text});
    try output.writeAll("\"color\": \"#00ff00\"");
    try output.writeAll("}");
}
