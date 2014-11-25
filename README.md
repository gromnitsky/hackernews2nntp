# Post Hacker News Stories & Comments to NNTP Server

Or _how to read HN offline_.

## Features

* Uses the official HN API
* No configuration files
* CLI
* Compatible w/ cron jobs
* MIME `multipart/alternative` mails w/ html & txt portions
* Stateless
* Read-only
* No up-voting support or score updates

![A screenshot of running mutt](https://raw.github.com/gromnitsky/hackernews2nntp/master/screenshot1.png)

## Requirements

* nodejs 0.10.x
* `rnews` CL util from INN package
* w3m browser


## Installation & Setup

(in Fedora 21)

	# yum install w3m inn

Add this to sudoers (replacing `alex` w/ your user name):

	alex ALL = (news) NOPASSWD: /bin/rnews

Then in the cloned repo:

	$ make


### Check your local inn

	# /usr/libexec/news/ctlinnd newgroup news.ycombinator

must not raise an error.

Then

	$ hackernews2nntp-get exact 8874 -v | hackernews2nntp-convert -v -f mbox > 1.mbox

will download a HN comment & convert it to mbox format. If you have mutt
installed, you can view if via `mutt -f 1.box`.

	$ hackernews2nntp-get exact 8874 -v | hackernews2nntp-convert -v | sudo rnews -N

will post the same comment to `news.ycombinator` group. If the message
didn't appear (because it's too old (Apr 2007) for a default INN
settings), run

	$ journalctl /bin/rnews
	$ journalctl -u innd


## Examples

Get top 100 stories & all comments for them, then exit:

	$ hackernews2nnpt-get top100 -v | hackernews2nntp-convert -v | sudo rnews -N

Get last 200 stories/comments, then exit:

	$ hackernews2nnpt-get last 200 -v | hackernews2nntp-convert -v | sudo rnews -N


## FAQ

0. _I have a problem w/ rnews._

	Please, don't ask me any questions about INN. I have a very vague
	idea how it works. I've chosen rnews because it (a) can read
	articles form stdin in a batch mode, (b) doesn't modify the incoming
	article, (c) fast, (d) comes w/ INN.

	Unfortunately it's not possible to know 'was the article posted or
	not' w/o reading INN logs.

1. _Can hackernews2nntp run as a daemon?_

	No.


## Bugs

* Barely tested on Fedora 21 only.
* Supports only UTF-8 locale.
* Don't follow 'parent' property, e.g. if it gets a comment, it tries to
  download all its 'kids', but ignores the 'parent'.
* `src/crawler.coffee` is especially ugly.


## See Also

[rnews(1)](http://www.eyrie.org/~eagle/software/inn/docs/rnews.html),
[w3m(1)](http://manpages.ubuntu.com/manpages/utopic/en/man1/w3m.1.html),
[sudoers(5)](http://www.sudo.ws/sudo/man/1.8.10/sudoers.man.html)

## TODO

* Post w/o rnews.


## License

MIT.
