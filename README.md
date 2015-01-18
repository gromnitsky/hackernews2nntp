# Post Hacker News Stories & Comments to an NNTP Server

Or _how to read HN offline_.

## Features

* Uses the official HN API
* No configuration files
* CLI
* Compatible w/ cron jobs
* MIME `multipart/alternative` mails w/ html & txt portions
* Mostly stateless
* Read-only
* No up-voting support or score updates

![A screenshot of running mutt](https://raw.github.com/gromnitsky/hackernews2nntp/master/screenshot1.png)

## Requirements

* nodejs 0.10.3x
* `rnews` CL util from INN package
* w3m browser


## Installation & Setup

(in Fedora 21)

	# yum install w3m inn

Add this to sudoers (replacing `alex` w/ your user name):

	alex ALL = (news) NOPASSWD: /bin/rnews

Then in the cloned repo:

	$ make

or just

	# npm install -g hackernews2nntp


### Check your local inn

	# /usr/libexec/news/ctlinnd newgroup news.ycombinator

must not raise an error.

Then

	$ hackernews2nntp-get exact 8874 -v | hackernews2nntp-convert -v -f mbox > 1.mbox

will download a HN comment & convert it to mbox format. If you have mutt
installed, you can view it via `mutt -f 1.box`.

	$ hackernews2nntp-get exact 8874 -v | hackernews2nntp-convert -v | sudo rnews -N

will post the same comment to `news.ycombinator` group. If the message
didn't appear (because it's too old (Apr 2007) for a default INN
settings), run

	$ journalctl /bin/rnews
	$ journalctl -u innd


## Examples

0. Get top 100 stories & all comments for them, then exit:

		$ hackernews2nntp-get top100 -v | hackernews2nntp-convert -v | sudo rnews -N

	If you get an EPIPE error, don't pipe to rnews but try to invoke
	`hackernews2nntp-conver` w/ `--fork` option:

		$ hackernews2nntp-get top100 -v | hackernews2nntp-convert -v --fork

	(It will call `sudo rnews -N` internally for each article.)

1. Get last 200 stories/comments, then exit:

		$ hackernews2nntp-get last 200 -v --nokids | hackernews2nntp-convert -v | sudo rnews -N

2. Don't post anything to an NNTP server but create 1 big .mbox file:

		$ rm 1.mbox
		$ hackernews2nntp-get top100 -v | hackernews2nntp-convert -v -f mbox >> 1.mbox

3. Get stories/comments in range from 8,000,000 to 8,000,100:

		$ hackernews2nntp-get -v --nokids range 8000000 8000100 | hackernews2nntp-convert -v | sudo rnews -N

4. Get stories/comments from 8859730 up to the most current one & save the
   last (highest numerical value) item id in `/tmp/last-item.txt`:

		$ hackernews2nntp-get -v --maxitem-save /tmp/last-item.txt --nokids range 8859730 | hackernews2nntp-convert -v | sudo rnews -N


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

2. _What does `hackernews2nntp-convert warning: json validation failed`
   message mean?_

	Usually it means that a HN post was deleted & there was no usefull
    data in the json payload. For example,

		$ hackernews2nntp-get exact 126809 | json -g -c 'this.deleted'
		[
		  {
			"deleted": true,
			"id": 127217
		  }
		]

	vs.

		$ hackernews2nntp-get exact 126809 | json -g \
			-c '!this.kids && this.by == "pg" && this.type == "comment"' | json 0
		{
		  "by": "pg",
		  "id": 126816,
		  "parent": 126809,
		  "text": "As you can see, we do.  You can read more [...]",
		  "time": 1204404016,
		  "type": "comment"
		}


## Bugs

* Barely tested on Fedora 21 only.
* Supports only UTF-8 locale.
* Don't follow 'parent' property, e.g. if it gets a comment, it tries to
  download all its 'kids', but ignores the 'parent'.
* `hackernews2nntp-get` can pause node 0.10.x process if you're not using
  `--nokids` option.
* `src/crawler2.coffee` is too long.


## See Also

[rnews(1)](http://www.eyrie.org/~eagle/software/inn/docs/rnews.html),
[w3m(1)](http://manpages.ubuntu.com/manpages/utopic/en/man1/w3m.1.html),
[mbox(5)](http://manpages.ubuntu.com/manpages/utopic/man5/mbox.5.html),
[sudoers(5)](http://www.sudo.ws/sudo/man/1.8.10/sudoers.man.html)


## News

### 0.2.0

* hackernews2nntp-get
	- totally rewrite Crawler
	- throttle a max number of http requests by 20/s (see `--conn-per-sec`)

### 0.1.0

* hackernews2nntp-get
	- `range` mode
	- `--maxitem-save` CLO
	- `-s` CLO
	- always print statistics on exit w/ `-v` or `-s` CLOs

* hackernews2nntp-convert
	- `--template-dir` CLO
	- fix a bug in mbox header w/ missing leading zeros

## Credits

Many thanks to [John Magolske](http://B79.net/contact) for suggestions
for hackernews2nntp-get `range` mode & `--maxitem-save` CLO & also for
reporting bugs.

## License

MIT.
