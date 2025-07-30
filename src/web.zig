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
    checked: i64, // Unix timestamp of when feed was last checked
};

/// Post is the *item* for the _web_ provider
pub const Post = struct {
    id: usize, // primary key
    feed_id: usize, // foreign key to feeds table
    url: []const u8, // [nonull]
    title: []const u8, // [nonull]
    ident: []const u8, // [nonull; unique]
    published: i64, // Unix timestamp of when feed was last checked
    summary: []const u8,
    read: bool = false,
};

/// The function that is called when `check add web` is called
pub fn add(allocator: std.mem.Allocator, url: []const u8) !void {
    // Initialize curl globally
    try curl.globalInit();
    defer curl.globalDeinit();

    // Initialize curl
    var easy = try curl.Easy.init(.{});
    defer easy.deinit();

    // Convert URL to null-terminated string
    const url_z = try allocator.dupeZ(u8, url);
    defer allocator.free(url_z);

    try easy.setFollowLocation(true); // Follow redirects

    // Perform the request
    const resp = try easy.fetchAlloc(url_z, allocator, .{});
    defer resp.deinit();

    // Parse the feed to extract the title
    // For now we will just use a simple string search for the title tag
    const response_body = resp.body.?.dynamic.items;

    const title_start_tag = "<title>";
    const title_end_tag = "</title>";

    const title_start_index = std.mem.indexOf(u8, response_body, title_start_tag) orelse return error.TitleNotFound;
    const title_end_index_rel = std.mem.indexOf(u8, response_body[title_start_index + title_start_tag.len ..], title_end_tag) orelse return error.TitleNotFound;
    const title_end_index = title_start_index + title_start_tag.len + title_end_index_rel;
    const raw_title = response_body[title_start_index + title_start_tag.len .. title_end_index];
    const title = stripCDATA(raw_title);

    // Get the mime type from the response headers
    const mime_type = if (resp.getHeader("content-type") catch null) |header| header.get() else "unknown";

    // Get current timestamp
    const current_time = std.time.timestamp();

    // Create Feed struct
    const feed = Feed{
        .id = 0, // Will be set by database
        .url = url,
        .title = title,
        .mime = mime_type,
        .checked = current_time,
    };

    // Store in database
    try saveFeedToDatabase(allocator, feed);

    std.debug.print("Added feed: {s} ({s})\n", .{ title, url });
}

/// Lists all feeds in the database
pub fn list(allocator: std.mem.Allocator) !void {
    // Get the home directory and construct the database path
    const home_dir = std.posix.getenv("HOME") orelse return error.HomeNotFound;
    const db_path = try std.fmt.allocPrintZ(allocator, "{s}/.check.db", .{home_dir});
    defer allocator.free(db_path);

    const flags = zqlite.OpenFlags.ReadOnly;
    var conn = try zqlite.open(db_path, flags);
    defer conn.close();

    const sql = "SELECT title, datetime(checked, 'unixepoch') FROM feeds ORDER BY id";
    var stmt = try conn.prepare(sql);
    defer stmt.deinit();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n📋 Web Subscriptions:\n\n", .{});

    var count: i32 = 0;
    while (try stmt.step()) {
        const title = stmt.text(0);
        const checked = stmt.text(1);

        try stdout.print("{s} ({s})\n", .{ title, checked });
        count += 1;
    }

    if (count == 0) {
        try stdout.print("No web feeds found. Add one with: check add web <url>\n", .{});
    } else {
        try stdout.print("\nTotal: {d} feed(s)\n", .{count});
    }
}

/// Checks a feed for new posts and saves them to the database
pub fn checkFeed(allocator: std.mem.Allocator, feed: Feed) !void {
    // Initialize curl
    try curl.globalInit();
    defer curl.globalDeinit();

    var easy = try curl.Easy.init(.{});
    defer easy.deinit();

    // Convert URL to null-terminated string
    const url_z = try allocator.dupeZ(u8, feed.url);
    defer allocator.free(url_z);

    try easy.setFollowLocation(true);

    // Fetch feed content
    const resp = try easy.fetchAlloc(url_z, allocator, .{});
    defer resp.deinit();

    const response_body = resp.body.?.dynamic.items;

    // Parse posts from the feed
    var posts_found: u32 = 0;

    // Look for RSS items or Atom entries
    var pos: usize = 0;
    while (pos < response_body.len) {
        // Try to find RSS <item> or Atom <entry>
        const item_start = std.mem.indexOf(u8, response_body[pos..], "<item>") orelse
            std.mem.indexOf(u8, response_body[pos..], "<entry>");
        if (item_start == null) break;

        pos += item_start.?;
        const item_content_start = pos;

        // Find the corresponding closing tag
        const item_end = std.mem.indexOf(u8, response_body[pos..], "</item>") orelse
            std.mem.indexOf(u8, response_body[pos..], "</entry>");
        if (item_end == null) break;

        const item_content_end = pos + item_end.?;
        const item_content = response_body[item_content_start..item_content_end];

        // Parse individual post from item content
        if (parsePost(item_content)) |parsed_post| {
            var post = parsed_post;
            post.feed_id = feed.id;
            // Try to save the post to database
            savePostToDatabase(allocator, post) catch |err| {
                if (err != error.PostExists) {
                    std.debug.print("Error saving post: {any}\n", .{err});
                }
            };
            posts_found += 1;
        } else |_| {
            // Skip posts that can't be parsed
        }

        pos = item_content_end + 1;
    }
}

/// Save feed to SQLite database
fn saveFeedToDatabase(allocator: std.mem.Allocator, feed: Feed) !void {
    // Get the home directory and construct the database path
    const home_dir = std.posix.getenv("HOME") orelse return error.HomeNotFound;
    const db_path = try std.fmt.allocPrintZ(allocator, "{s}/.check.db", .{home_dir});
    defer allocator.free(db_path);

    const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.ReadWrite;
    var conn = try zqlite.open(db_path, flags);
    defer conn.close();

    // Create feeds table if it doesn't exist
    const create_feeds_table_sql =
        \\CREATE TABLE IF NOT EXISTS feeds (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    url TEXT NOT NULL UNIQUE,
        \\    title TEXT NOT NULL,
        \\    mime TEXT,
        \\    checked INTEGER DEFAULT 0
        \\);
    ;

    try conn.exec(create_feeds_table_sql, .{});

    // Create posts table with foreign key constraint
    const create_posts_table_sql =
        \\CREATE TABLE IF NOT EXISTS posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    feed_id INTEGER NOT NULL,
        \\    url TEXT NOT NULL,
        \\    title TEXT NOT NULL,
        \\    ident TEXT NOT NULL UNIQUE,
        \\    published INTEGER DEFAULT 0,
        \\    summary TEXT DEFAULT '',
        \\    read BOOLEAN DEFAULT FALSE,
        \\    FOREIGN KEY (feed_id) REFERENCES feeds(id) ON DELETE CASCADE
        \\);
    ;

    try conn.exec(create_posts_table_sql, .{});

    // Check if feed already exists
    const check_sql = "SELECT id FROM feeds WHERE url = ?";
    var stmt = try conn.prepare(check_sql);
    defer stmt.deinit();

    try stmt.bind(.{feed.url});

    if (try stmt.step()) {
        std.debug.print("Feed already exists in database\n", .{});
        return;
    }

    try stmt.reset();

    // Insert new feed
    const insert_sql = "INSERT INTO feeds (url, title, mime, checked) VALUES (?, ?, ?, ?)";
    var insert_stmt = try conn.prepare(insert_sql);
    defer insert_stmt.deinit();

    try insert_stmt.bind(.{ feed.url, feed.title, feed.mime, feed.checked });

    _ = try insert_stmt.step();

    const feed_id = conn.lastInsertedRowId();
    var new_feed = feed;
    new_feed.id = @intCast(feed_id);

    // Automatically check the feed for new posts after saving
    try checkFeed(allocator, new_feed);

    // Update the checked time for the feed
    try updateFeedCheckedTime(allocator, new_feed.id);
}

/// Checks all feeds in the database for new posts
pub fn checkAllFeeds(allocator: std.mem.Allocator) !void {
    // Get all feeds from the database
    const feeds = try getAllFeeds(allocator);
    defer allocator.free(feeds);

    // Iterate through feeds and check each one
    for (feeds) |feed| {
        std.debug.print("Checking feed: {s}\n", .{feed.title});
        try checkFeed(allocator, feed);
    }
}

/// Get all feeds from the database
fn getAllFeeds(allocator: std.mem.Allocator) ![]Feed {
    const home_dir = std.posix.getenv("HOME") orelse return error.HomeNotFound;
    const db_path = try std.fmt.allocPrintZ(allocator, "{s}/.check.db", .{home_dir});
    defer allocator.free(db_path);

    const flags = zqlite.OpenFlags.ReadOnly;
    var conn = try zqlite.open(db_path, flags);
    defer conn.close();

    const sql = "SELECT id, url, title, mime, checked FROM feeds ORDER BY id";
    var stmt = try conn.prepare(sql);
    defer stmt.deinit();

    var feed_list = std.ArrayList(Feed).init(allocator);

    while (try stmt.step()) {
        const feed = Feed{
            .id = @intCast(stmt.int(0)),
            .url = try allocator.dupe(u8, stmt.text(1)),
            .title = try allocator.dupe(u8, stmt.text(2)),
            .mime = try allocator.dupe(u8, stmt.text(3)),
            .checked = stmt.int(4),
        };
        try feed_list.append(feed);
    }

    return feed_list.toOwnedSlice();
}

/// Update the last checked time for a feed
fn updateFeedCheckedTime(allocator: std.mem.Allocator, feed_id: usize) !void {
    const home_dir = std.posix.getenv("HOME") orelse return error.HomeNotFound;
    const db_path = try std.fmt.allocPrintZ(allocator, "{s}/.check.db", .{home_dir});
    defer allocator.free(db_path);

    const flags = zqlite.OpenFlags.ReadWrite;
    var conn = try zqlite.open(db_path, flags);
    defer conn.close();

    const sql = "UPDATE feeds SET checked = ? WHERE id = ?";
    var stmt = try conn.prepare(sql);
    defer stmt.deinit();

    const current_time = std.time.timestamp();
    try stmt.bind(.{ current_time, feed_id });

    _ = try stmt.step();
}

/// Parse a post from RSS item or Atom entry content
fn parsePost(item_content: []const u8) !Post {
    // Extract title
    const title_start_tag = "<title>";
    const title_end_tag = "</title>";
    const title_start_idx_opt = std.mem.indexOf(u8, item_content, title_start_tag);
    const title_end_idx_opt = std.mem.indexOf(u8, item_content, title_end_tag);
    if (title_start_idx_opt == null or title_end_idx_opt == null) {
        return error.TitleNotFound;
    }
    const title_start_idx = title_start_idx_opt.? + title_start_tag.len;
    const title_end_idx = title_end_idx_opt.?;
    const raw_title = item_content[title_start_idx..title_end_idx];
    const title = stripCDATA(raw_title);

    // Extract URL from <link> tag or <guid> tag
    var url: []const u8 = "";
    const link_start_tag = "<link>";
    const link_end_tag = "</link>";
    const link_start_idx_opt = std.mem.indexOf(u8, item_content, link_start_tag);
    const link_end_idx_opt = std.mem.indexOf(u8, item_content, link_end_tag);
    if (link_start_idx_opt != null and link_end_idx_opt != null) {
        const link_start_idx = link_start_idx_opt.? + link_start_tag.len;
        const link_end_idx = link_end_idx_opt.?;
        url = item_content[link_start_idx..link_end_idx];
    } else {
        // Try to extract from <guid> tag as fallback
        const guid_start_tag = "<guid>";
        const guid_end_tag = "</guid>";
        const guid_start_idx_opt = std.mem.indexOf(u8, item_content, guid_start_tag);
        const guid_end_idx_opt = std.mem.indexOf(u8, item_content, guid_end_tag);
        if (guid_start_idx_opt != null and guid_end_idx_opt != null) {
            const guid_start_idx = guid_start_idx_opt.? + guid_start_tag.len;
            const guid_end_idx = guid_end_idx_opt.?;
            url = item_content[guid_start_idx..guid_end_idx];
        } else {
            return error.URLNotFound;
        }
    }

    // Extract summary/description
    var summary: []const u8 = "";
    const desc_start_tag = "<description>";
    const desc_end_tag = "</description>";
    const desc_start_idx_opt = std.mem.indexOf(u8, item_content, desc_start_tag);
    const desc_end_idx_opt = std.mem.indexOf(u8, item_content, desc_end_tag);
    if (desc_start_idx_opt != null and desc_end_idx_opt != null) {
        const desc_start_idx = desc_start_idx_opt.? + desc_start_tag.len;
        const desc_end_idx = desc_end_idx_opt.?;
        const raw_summary = item_content[desc_start_idx..desc_end_idx];
        summary = stripCDATA(raw_summary);
    }

    // Extract published date from various possible tags
    var published: i64 = std.time.timestamp(); // Default to current time

    // Try <pubDate> (RSS)
    const pubdate_start_tag = "<pubDate>";
    const pubdate_end_tag = "</pubDate>";
    if (std.mem.indexOf(u8, item_content, pubdate_start_tag) != null and
        std.mem.indexOf(u8, item_content, pubdate_end_tag) != null)
    {
        const pubdate_start_idx = std.mem.indexOf(u8, item_content, pubdate_start_tag).? + pubdate_start_tag.len;
        const pubdate_end_idx = std.mem.indexOf(u8, item_content, pubdate_end_tag).?;
        const pubdate_str = std.mem.trim(u8, item_content[pubdate_start_idx..pubdate_end_idx], " \t\r\n");
        published = parseRFC2822Date(pubdate_str) catch published;
    } else {
        // Try <published> (Atom)
        const pub_start_tag = "<published>";
        const pub_end_tag = "</published>";
        if (std.mem.indexOf(u8, item_content, pub_start_tag) != null and
            std.mem.indexOf(u8, item_content, pub_end_tag) != null)
        {
            const pub_start_idx = std.mem.indexOf(u8, item_content, pub_start_tag).? + pub_start_tag.len;
            const pub_end_idx = std.mem.indexOf(u8, item_content, pub_end_tag).?;
            const pub_str = std.mem.trim(u8, item_content[pub_start_idx..pub_end_idx], " \t\r\n");
            published = parseISO8601Date(pub_str) catch published;
        }
    }

    // Use URL as unique identifier
    const ident = url;

    return Post{
        .id = 0, // Will be set by database
        .feed_id = 0, // Will be set by savePostToDatabase
        .url = url,
        .title = title,
        .ident = ident,
        .published = published,
        .summary = summary,
        .read = false,
    };
}

/// Save post to SQLite database with proper feed_id foreign key
fn savePostToDatabase(allocator: std.mem.Allocator, post: Post) !void {
    // Get the home directory and construct the database path
    const home_dir = std.posix.getenv("HOME") orelse return error.HomeNotFound;
    const db_path = try std.fmt.allocPrintZ(allocator, "{s}/.check.db", .{home_dir});
    defer allocator.free(db_path);

    const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.ReadWrite;
    var conn = try zqlite.open(db_path, flags);
    defer conn.close();

    _ = post.feed_id; // We'll use post.feed_id directly in the bind call

    // Check if post already exists
    const check_sql = "SELECT id FROM posts WHERE ident = ?";
    var check_stmt = try conn.prepare(check_sql);
    defer check_stmt.deinit();

    try check_stmt.bind(.{post.ident});

    if (try check_stmt.step()) {
        // Post already exists
        return error.PostExists;
    }

    // Insert new post
    const insert_sql = "INSERT INTO posts (feed_id, url, title, ident, published, summary, read) VALUES (?, ?, ?, ?, ?, ?, ?)";
    var insert_stmt = try conn.prepare(insert_sql);
    defer insert_stmt.deinit();

    try insert_stmt.bind(.{ post.feed_id, post.url, post.title, post.ident, post.published, post.summary, post.read });

    _ = try insert_stmt.step();
}

/// Parse RFC2822 date format (used in RSS pubDate)
fn parseRFC2822Date(date_str: []const u8) !i64 {
    // This is a placeholder implementation
    // A full implementation would parse dates like "Wed, 02 Oct 2002 13:00:00 GMT"
    // For now, return current timestamp
    _ = date_str;
    return std.time.timestamp();
}

/// Parse ISO8601 date format (used in Atom published/updated)
fn parseISO8601Date(date_str: []const u8) !i64 {
    // Handle common ISO 8601 formats:
    // 2003-12-13T18:30:02Z
    // 2003-12-13T18:30:02+00:00
    // 2003-12-13T18:30:02.123Z
    // 2003-12-13T18:30:02

    if (date_str.len < 19) { // Minimum length for YYYY-MM-DDTHH:MM:SS
        return error.InvalidDateFormat;
    }

    // Extract date components: YYYY-MM-DD
    const year_str = date_str[0..4];
    const month_str = date_str[5..7];
    const day_str = date_str[8..10];

    // Extract time components: HH:MM:SS
    const hour_str = date_str[11..13];
    const minute_str = date_str[14..16];
    const second_str = date_str[17..19];

    // Parse components
    const year = std.fmt.parseInt(u16, year_str, 10) catch return error.InvalidYear;
    const month = std.fmt.parseInt(u8, month_str, 10) catch return error.InvalidMonth;
    const day = std.fmt.parseInt(u8, day_str, 10) catch return error.InvalidDay;
    const hour = std.fmt.parseInt(u8, hour_str, 10) catch return error.InvalidHour;
    const minute = std.fmt.parseInt(u8, minute_str, 10) catch return error.InvalidMinute;
    const second = std.fmt.parseInt(u8, second_str, 10) catch return error.InvalidSecond;

    // Basic validation
    if (month < 1 or month > 12) return error.InvalidMonth;
    if (day < 1 or day > 31) return error.InvalidDay;
    if (hour > 23) return error.InvalidHour;
    if (minute > 59) return error.InvalidMinute;
    if (second > 59) return error.InvalidSecond;

    // Calculate Unix timestamp
    // This is a simplified calculation that doesn't account for leap years perfectly
    // but should be good enough for feed parsing

    var timestamp: i64 = 0;

    // Add years since 1970
    var y: u16 = 1970;
    while (y < year) : (y += 1) {
        if (isLeapYear(y)) {
            timestamp += 366 * 24 * 60 * 60; // leap year
        } else {
            timestamp += 365 * 24 * 60 * 60; // normal year
        }
    }

    // Add months
    const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        var days = days_in_month[m - 1];
        // February in leap year
        if (m == 2 and isLeapYear(year)) {
            days = 29;
        }
        timestamp += @as(i64, days) * 24 * 60 * 60;
    }

    // Add days (subtract 1 because day 1 = 0 additional days)
    timestamp += @as(i64, day - 1) * 24 * 60 * 60;

    // Add hours, minutes, seconds
    timestamp += @as(i64, hour) * 60 * 60;
    timestamp += @as(i64, minute) * 60;
    timestamp += @as(i64, second);

    // Handle timezone offset
    // If it ends with 'Z', it's UTC (no adjustment needed)
    // If it has +HH:MM or -HH:MM, we need to adjust
    if (date_str.len > 19) {
        if (date_str[date_str.len - 1] == 'Z') {
            // UTC time, no adjustment needed
        } else if (date_str.len >= 25) { // Has timezone offset like +05:00
            const tz_start = date_str.len - 6; // Position of + or -
            if (date_str[tz_start] == '+' or date_str[tz_start] == '-') {
                const tz_sign: i8 = if (date_str[tz_start] == '+') -1 else 1; // Note: inverted because we subtract offset
                const tz_hour_str = date_str[tz_start + 1 .. tz_start + 3];
                const tz_minute_str = date_str[tz_start + 4 .. tz_start + 6];

                const tz_hour = std.fmt.parseInt(u8, tz_hour_str, 10) catch 0;
                const tz_minute = std.fmt.parseInt(u8, tz_minute_str, 10) catch 0;

                const offset = @as(i64, tz_sign) * (@as(i64, tz_hour) * 3600 + @as(i64, tz_minute) * 60);
                timestamp += offset;
            }
        }
    }

    return timestamp;
}

/// Check if a year is a leap year
fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

/// Strips CDATA tags from a string if present
fn stripCDATA(input: []const u8) []const u8 {
    const cdata_start = "<![CDATA[";
    const cdata_end = "]]>";

    // Check if the string starts with CDATA and ends with the closing tag
    if (std.mem.startsWith(u8, input, cdata_start) and std.mem.endsWith(u8, input, cdata_end)) {
        // Extract the content between the CDATA tags
        const start_pos = cdata_start.len;
        const end_pos = input.len - cdata_end.len;
        if (start_pos < end_pos) {
            return input[start_pos..end_pos];
        }
    }

    // Return the original string if no CDATA tags found
    return input;
}
