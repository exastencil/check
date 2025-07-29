//! Provider configuration values

pub const Provider = enum {
    none,
    web, // RSS or Atom feed
    mail, // Email inbox
    calendar, // iCal compatible calendar endpoint
    twitter, // Twitter / X account
    bluesky, // Bluesky account
    reddit, // A subreddit to follow
    slack, // Slack channel
    discord, // Discord channel
};
