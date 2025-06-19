const std = @import("std");

fn cpu_get_usage(allocator: std.mem.Allocator) !struct { total: u32, idle: u32 } {
    const statFile = try std.fs.openFileAbsolute("/proc/stat", .{ .mode = .read_only });
    defer statFile.close();
    const contents = try statFile.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    var it = std.mem.tokenizeSequence(u8, contents, " ");

    _ = it.next();
    var user: u32 = undefined;
    var nice: u32 = undefined;
    var system: u32 = undefined;
    var idle: u32 = undefined;
    var iowait: u32 = undefined;
    var irq: u32 = undefined;
    var softirq: u32 = undefined;
    var steal: u32 = undefined;
    if (it.next()) |str| user = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| nice = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| system = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| idle = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| iowait = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| irq = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| softirq = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| steal = try std.fmt.parseInt(u32, str, 10);

    const total = user + nice + system + idle + iowait + irq + softirq + steal;
    return .{ .total = total, .idle = idle };
}

var last_idle: u32 = 0;
var last_total: u32 = 0;

const Options = struct {
    format: []const u8 = "%usage$2% @ %frequency$2GHz (%temperature$1˚C)",
};

pub fn module_cpu(output: anytype, allocator: std.mem.Allocator, options: anytype) anyerror!void {
    var userOptions: Options = .{};
    if (@hasField(@TypeOf(options), "format")) {
        userOptions.format = options.format;
    }
    const info = try cpu_get_usage(allocator);
    const didl = info.idle - last_idle;
    const dtot = info.total - last_total;
    const cpu_usage = 100 * (1 - (@as(f32, @floatFromInt(didl)) / @as(f32, @floatFromInt(dtot))));
    last_idle = info.idle;
    last_total = info.total;

    const freqFile = try std.fs.openFileAbsolute("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", .{ .mode = .read_only });
    defer freqFile.close();
    var buff: [32]u8 = undefined;
    const len = try freqFile.readAll(&buff);
    const freq = try std.fmt.parseInt(u32, buff[0 .. len - 1], 10);

    const tempFile = try std.fs.openFileAbsolute("/sys/class/thermal/thermal_zone1/temp", .{ .mode = .read_only });
    defer tempFile.close();
    const len2 = try tempFile.readAll(&buff);
    const tempint = try std.fmt.parseInt(u32, buff[0 .. len2 - 1], 10);

    const temp = @as(f32, @floatFromInt(tempint)) / 1000;

    const formatFullText = @import("../format.zig").formatFullText;
    const full_text = try formatFullText(userOptions.format, &.{
        .{ .name = "usage", .value = cpu_usage },
        .{ .name = "frequency", .value = @as(f32, @floatFromInt(freq)) / 1000000 },
        .{ .name = "temperature", .value = temp },
    }, allocator);

    defer allocator.free(full_text);

    try output.writeAll("{");
    //     try output.print("\"full_text\": \"cpu {d:.2}% @ {}MHz ({d:.1}˚C)\", ", .{ cpu_usage, freq / 1000, temp });
    try output.print("\"full_text\": \"{s}\", ", .{full_text});
    try output.writeAll("\"color\": \"#00ff00\"");
    try output.writeAll("}");
}
