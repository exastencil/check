//! Web provider functionality for check

const std = @import("std");
const curl = @import("curl");
const zqlite = @import("zqlite");

/// Feed is the *subscription* for the _web_ provider
pub const Feed = struct {
    id: usize, // [primary; sql: serial]
    url: []const u8, // [nonull; unique]
    title: []const u8, // [nonull]
    mime: []const u8,
    checked: u8,
};

/// Post is the *item* for the _web_ provider
pub const Post = struct {
    id: usize, // primary key
    url: []const u8, // [nonull]
    title: []const u8, // [nonull]
    ident: []const u8, // [nonull; unique]
    published: u8,
    summary: []const u8,
    read: bool = false,
};

/// The function that is called when `check add web` is called
pub fn add() void {
    std.debug.print("Add called\n", .{});
}
