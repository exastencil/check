module check

fn test_parse_atom_feed() {
	feed := Feed{
		mime: 'application/atom+xml'
	}
	text := '<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en"><title>xkcd.com</title><link href="https://xkcd.com/" rel="alternate"></link><id>https://xkcd.com/</id><updated>2020-10-30T00:00:00Z</updated><entry><title>Probability Comparisons</title><link href="https://xkcd.com/2379/" rel="alternate"></link><updated>2020-10-30T00:00:00Z</updated><id>https://xkcd.com/2379/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/probability_comparisons.png" title="Call me, MAYBE." alt="Call me, MAYBE." /&gt;</summary></entry><entry><title>Fall Back</title><link href="https://xkcd.com/2378/" rel="alternate"></link><updated>2020-10-28T00:00:00Z</updated><id>https://xkcd.com/2378/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/fall_back.png" title="Doing great here in the sixth and hopefully final year of the 2016 election." alt="Doing great here in the sixth and hopefully final year of the 2016 election." /&gt;</summary></entry><entry><title>xkcd Phone 12</title><link href="https://xkcd.com/2377/" rel="alternate"></link><updated>2020-10-26T00:00:00Z</updated><id>https://xkcd.com/2377/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/xkcd_phone_12.png" title="New phone OS features: Infinite customization (home screen icons no longer snap to grid), dark mode (disables screen), screaming mode (self-explanatory), and coherent ultracapacitor-pumped emission (please let us know what this setting does; we\'ve been afraid to try it)." alt="New phone OS features: Infinite customization (home screen icons no longer snap to grid), dark mode (disables screen), screaming mode (self-explanatory), and coherent ultracapacitor-pumped emission (please let us know what this setting does; we\'ve been afraid to try it)." /&gt;</summary></entry><entry><title>Curbside</title><link href="https://xkcd.com/2376/" rel="alternate"></link><updated>2020-10-23T00:00:00Z</updated><id>https://xkcd.com/2376/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/curbside.png" title="The state has had so many contact tracers disappear into that shop that they\'ve had to start a contact tracer tracing program." alt="The state has had so many contact tracers disappear into that shop that they\'ve had to start a contact tracer tracing program." /&gt;</summary></entry></feed>'
	posts := feed.parse(text)
	assert posts.len == 4
	assert posts.map(it.title) == [
		'Probability Comparisons',
		'Fall Back',
		'xkcd Phone 12',
		'Curbside',
	]
	assert posts.map(it.url) == [
		'https://xkcd.com/2379/',
		'https://xkcd.com/2378/',
		'https://xkcd.com/2377/',
		'https://xkcd.com/2376/',
	]

	assert posts.map(it.published.str()) == [
		'2020-10-30 00:00:00',
		'2020-10-28 00:00:00',
		'2020-10-26 00:00:00',
		'2020-10-23 00:00:00',
	]
}
