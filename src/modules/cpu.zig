const std = @import("std");

const CpuStats = struct {
    time_in_user: u32 = 0,
    time_in_nice: u32 = 0,
    time_in_system: u32 = 0,
    time_in_idle: u32 = 0,
    time_in_iowait: u32 = 0,
    time_in_irq: u32 = 0,
    time_in_softirq: u32 = 0,
    time_in_steal: u32 = 0,
    time_total: u32 = 0,

    temp: f32 = 0, // in ˚C
    freq: usize = 0, // in kHz
    usage: f32 = 0, // in %
};

var last_idle: u32 = 0;
var last_total: u32 = 0;
// TODO: this function really doesn't need to allocate memory it can read the file by chunks into a buffer on the stack
//       not allocating memory dynamically also allows it to not accept an allocator (less stuff that needs to be passed around)
fn readStatFile(stats: *CpuStats, allocator: std.mem.Allocator) !void {
    const statFile = try std.fs.openFileAbsolute("/proc/stat", .{ .mode = .read_only });
    defer statFile.close();
    const contents = try statFile.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    var it = std.mem.tokenizeSequence(u8, contents, " ");

    _ = it.next();
    if (it.next()) |str| stats.time_in_user = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_nice = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_system = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_idle = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_iowait = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_irq = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_softirq = try std.fmt.parseInt(u32, str, 10);
    if (it.next()) |str| stats.time_in_steal = try std.fmt.parseInt(u32, str, 10);
    stats.time_total = stats.time_in_user + stats.time_in_nice + stats.time_in_system + stats.time_in_idle + stats.time_in_iowait + stats.time_in_irq + stats.time_in_softirq + stats.time_in_steal;

    const didl = stats.time_in_idle - last_idle;
    const dtot = stats.time_total - last_total;
    stats.usage = 100 * (1 - (@as(f32, @floatFromInt(didl)) / @as(f32, @floatFromInt(dtot))));
    last_idle = stats.time_in_idle;
    last_total = stats.time_total;
}

fn readFreqFile(stats: *CpuStats) !void {
    const freqFile = try std.fs.openFileAbsolute("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", .{ .mode = .read_only });
    defer freqFile.close();
    var buff: [32]u8 = undefined;
    const len = try freqFile.readAll(&buff);
    stats.freq = try std.fmt.parseInt(u32, buff[0 .. len - 1], 10);
}

fn readTempFile(stats: *CpuStats) !void {
    var buff: [32]u8 = undefined;
    const tempFile = try std.fs.openFileAbsolute("/sys/class/thermal/thermal_zone1/temp", .{ .mode = .read_only });
    defer tempFile.close();
    const len = try tempFile.readAll(&buff);
    const tempint = try std.fmt.parseInt(u32, buff[0 .. len - 1], 10);
    stats.temp = @as(f32, @floatFromInt(tempint)) / 1000;
}

fn readCpuStats(allocator: std.mem.Allocator) !CpuStats {
    var stats: CpuStats = .{};
    try readStatFile(&stats, allocator);
    try readFreqFile(&stats);
    try readTempFile(&stats);
    return stats;
}

const default_format: []const u8 = "%usage$2% @ %frequency$2GHz (%temperature$1˚C)";

const fmt = @import("../format.zig");
pub fn module_cpu(output: anytype, allocator: std.mem.Allocator, options: ?std.StringHashMap([]const u8)) !void {
    const format: []const u8 = if (options) |o| o.get("format") orelse default_format else default_format;
    const stats = try readCpuStats(allocator);

    const full_text = try fmt.formatFullText(format, &.{
        .{ .name = "usage", .value = .{ .Number = stats.usage } },
        .{ .name = "frequency", .value = .{ .Number = @as(f32, @floatFromInt(stats.freq)) / 1000000 } },
        .{ .name = "temperature", .value = .{ .Number = stats.temp } },
    }, allocator);

    defer allocator.free(full_text);

    try output.writeAll("{");
    try output.print("\"full_text\": \"{s}\", ", .{full_text});
    try output.writeAll("\"color\": \"#00ff00\"");
    try output.writeAll("}");
}
