module check

import time

// Mailbox is the *account* for the _mail_ extension
struct Mailbox {
	address  string
	password string
	imap     string
	checked  time.Time
}

// Mail is the *item* for the _mail_ extension
struct Mail {
	subject   string
	to        []string
	from      string
	text_body string
	html_body string
	sent      time.Time
	read      bool
}
