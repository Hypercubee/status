const std = @import("std");

const Options = struct {
    format: []const u8 = "mem: %usedMB / %totalMB (%percent$1%)",
};

pub fn module_memory(output: anytype, allocator: std.mem.Allocator, options: ?std.StringHashMap([]const u8)) !void {
    var userOptions: Options = .{};
    if (options) |customizedOptions| {
        if (customizedOptions.get("format")) |value| {
            userOptions.format = value;
        }
    }

    const ramFile = try std.fs.openFileAbsolute("/proc/meminfo", .{ .mode = .read_only });
    defer ramFile.close();

    const contents = try ramFile.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    var it = std.mem.tokenizeSequence(u8, contents, " ");
    _ = it.next();
    const memTotalStr = it.next().?;
    _ = it.next();
    const memFree = it.next();
    _ = memFree; // autofix
    _ = it.next();
    const memAvailableStr = it.next().?;
    _ = it.next();

    const memTotal = try std.fmt.parseInt(u32, memTotalStr, 10);
    const memAvailable = try std.fmt.parseInt(u32, memAvailableStr, 10);

    const memUsed = memTotal - memAvailable;

    const formatFullText = @import("../format.zig").formatFullText;
    const full_text = try formatFullText(userOptions.format, &.{
        .{ .name = "used", .value = @as(f32, @floatFromInt(memUsed)) / 1000 },
        .{ .name = "total", .value = @as(f32, @floatFromInt(memTotal)) / 1000 },
        .{ .name = "available", .value = @as(f32, @floatFromInt(memAvailable)) / 1000 },
        .{ .name = "percent", .value = 100 * @as(f32, @floatFromInt(memUsed)) / @as(f32, @floatFromInt(memTotal)) },
    }, allocator);
    defer allocator.free(full_text);
    try output.writeAll("{");
    try output.print("\"full_text\": \"{s}\", ", .{full_text});
    try output.writeAll("\"color\": \"#00ff00\"");
    try output.writeAll("}");
}
