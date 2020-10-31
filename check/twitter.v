module check

import time

// Twitter is the *account* for the _twitter_ extension
struct Twitter {
	handle       string
	password     string
	display_name string
	checked      time.Time
}

// Tweet is the *item* for the _twitter_ extension
struct Tweet {
	handle       string
	display_name string
	content      string
	time         time.Time
	read         bool
}
