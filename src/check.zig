//! The `check [provider]` command

const std = @import("std");
const web = @import("web.zig");

/// The function that is called when `check [provider]` is called
pub fn check() void {
    std.debug.print("Check called\n", .{});
}

/// The function that is called when `check exec` is called
/// This checks all feeds in all providers for new content
pub fn exec(allocator: std.mem.Allocator) !void {
    try web.checkAllFeeds(allocator);
}
