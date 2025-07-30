//! The `check [provider]` command

const std = @import("std");
const web = @import("web.zig");
const Provider = @import("provider.zig").Provider;

/// The function that is called when `check [provider]` is called
pub fn check(allocator: std.mem.Allocator, provider: Provider) !void {
    switch (provider) {
        .web => try web.check(allocator),
        .none => {
            // Show summary of all providers
            std.debug.print("Check called with no provider\n", .{});
        },
        else => {
            std.debug.print("Provider {s} not yet implemented\n", .{@tagName(provider)});
        },
    }
}

/// The function that is called when `check exec` is called
/// This checks all feeds in all providers for new content
pub fn exec(allocator: std.mem.Allocator) !void {
    try web.checkAllFeeds(allocator);
}
