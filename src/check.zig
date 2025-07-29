//! The `check [provider]` command

const std = @import("std");

/// The function that is called when `check [provider]` is called
pub fn check() void {
    std.debug.print("Check called\n", .{});
}
