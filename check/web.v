module check

import net.http
import sqlite
import term
import time

// Feed is the *subscription* for the _web_ provider
struct Feed {
	id      int
mut:
	url	    string
	title   string
	mime    string
	checked time.Time
}

// Post is the *item* for the _web_ provider
struct Post {
mut:
	title     string
	url       string
	ident     string
	published time.Time
	summary   string
	read      bool
}

// `check web`
pub fn web(settings Settings) {
	path := settings.store_path
	println('Checking items in $path')
}

// `check add web _ident_`
pub fn add_web(settings Settings, ident string) {
	mut feed := Feed{url: ident}
	response := http.get(ident) or {
		panic('Invalid feed ($ident)')
	}
	content_type := response.lheaders["content-type"]
	feed.mime = content_type.split(';')[0]
	// Determine format if vague
	if feed.mime == 'text/xml' {
		// Atom: xmlns="http://www.w3.org/2005/Atom"
		if response.text.contains(r"http://www.w3.org/2005/Atom") {
			feed.mime = 'application/atom+xml'
		}
		// RSS 2.0: <rss version="2.0">
		if response.text.contains(r"<rss") {
			feed.mime = 'application/rss+xml'
		}
	}
	feed.parse_title(response.text)

	db := sqlite.connect('$settings.store_path/web.db') or {
		println('Unable to connect to database ($err)')
		panic(err)
	}

	// TODO Add the feed to Feed table
	sql db {
		insert feed into Feed
	}
	println(feed)
	// TODO Add the initial posts to the Post table
}

// Sets the title on the Feed based on its MIME type
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
