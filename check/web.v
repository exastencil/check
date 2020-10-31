module check

import time

// Feed is the *account* for the web _extension_
struct Feed {
	url	    string
	title   string
	checked time.Time
}

// Post is the *item* for the web _extension_
struct Post {
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
