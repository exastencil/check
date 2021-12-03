module check

import net.http
import sqlite
import term
import time

// Feed is the *subscription* for the _web_ provider
[table: 'feeds']
pub struct Feed {
pub:
	id int [primary; sql: serial]
pub mut:
	url     string    [nonull; unique]
	title   string    [nonull]
	mime    string
	checked time.Time
}

// Post is the *item* for the _web_ provider
[table: 'posts']
pub struct Post {
pub:
	id int [primary; sql: serial]
pub mut:
	url       string    [nonull]
	title     string    [nonull]
	ident     string    [nonull; unique]
	published time.Time
	summary   string
	read      bool
}

// web is the function executed when running `check web`
pub fn web(settings Settings) {
	path := settings.store_path
	println('Checking items in $path')
}

// add_web is the function executed when running `check add web _ident_`
pub fn add_web(settings Settings, ident string) {
	mut feed := Feed{
		url: ident
	}
	response := http.get(ident) or { panic('Invalid feed ($ident)') }
	content_type := response.header.get(.content_type) or {
		println('Unable to identify feed type from header ($err)')
		panic(err)
	}
	feed.mime = content_type.split(';')[0]
	// Determine format if vague
	if feed.mime == 'text/xml' {
		// Atom: xmlns="http://www.w3.org/2005/Atom"
		if response.text.contains(r'http://www.w3.org/2005/Atom') {
			feed.mime = 'application/atom+xml'
		}
		// RSS 2.0: <rss version="2.0">
		if response.text.contains(r'<rss') {
			feed.mime = 'application/rss+xml'
		}
	}
	feed.parse_title(response.text)

	db := sqlite.connect('$settings.store_path/web.db') or {
		println('Unable to connect to database ($err)')
		panic(err)
	}
	sql db {
		create table Feed
	}
	sql db {
		create table Post
	}

	// Add the feed to Feed table
	existing_feed := sql db {
		select from Feed where url == ident limit 1
	}
	if existing_feed.url == feed.url {
		println(term.yellow('Feed already added!'))
		feed = existing_feed
	} else {
		sql db {
			insert feed into Feed
		}
	}
	// Add the initial posts to the Post table
	posts := feed.parse(response.text)
	for post in posts {
		existing_post := sql db {
			select from Post where ident == post.ident limit 1
		}
		if existing_post.ident == post.ident {
			// Already exists
		} else {
			sql db {
				insert post into Post
			}
		}
	}
}

// parse_title sets the title on the Feed based on its MIME type
fn (mut f Feed) parse_title(text string) {
	match f.mime {
		'application/atom+xml' {
			t0 := text.index('<title>') or { -1 }
			t1 := text.index('</title>') or { -1 }
			if t0 > -1 && t1 > t0 {
				start := t0 + '<title>'.len
				end := t1
				f.title = text[start..end]
			}
		}
		else {
			print(term.red('Unsupported MIME type: '))
			print(term.bold(f.mime))
		}
	}
}

// parse parses Posts out of the Feed's body
fn (f Feed) parse(text string) []Post {
	mut posts := []Post{}
	// Parse the posts
	match f.mime {
		'application/atom+xml' {
			entry_start := text.index('<entry>') or { -1 }
			entry_end := text.len - '</feed>'.len
			entry_content := text[entry_start - 2..entry_end].trim_left('<entry>')
			entries := entry_content.split('<entry>').map(it.trim_right('</entry>'))

			for entry in entries {
				mut post := Post{}
				// Title
				t0 := entry.index('<title>') or { -1 }
				if t0 > -1 {
					t1 := entry.index('</title>') or { -1 }
					if t0 > -1 && t1 > t0 {
						start := t0 + '<title>'.len
						end := t1
						post.title = entry[start..end]
					}
				}
				// Ident
				id0 := entry.index('<id>') or { -1 }
				id1 := entry.index('</id>') or { -1 }
				if id0 > -1 && id1 > id0 {
					start := id0 + '<id>'.len
					end := id1
					post.ident = entry[start..end]
					post.url = entry[start..end]
				}
				// Published
				p0 := entry.index('<updated>') or { -1 }
				p1 := entry.index('</updated>') or { -1 }
				if id0 > -1 && id1 > id0 {
					start := p0 + '<updated>'.len
					end := p1
					post.published = time.parse_rfc3339(entry[start..end]) or { time.now() }
				}

				// Append post
				if post.url != '' && post.title != '' && post.ident != '' {
					posts << post
				}
			}
		}
		else {
			println(term.red('Did not parse feed due to type: $f.mime'))
		}
	}
	return posts
}
