assert = require 'assert'
fs = require 'fs'

Message = require '../src/message'

suite 'Message', ->
  setup ->

  test 'headers', ->
    story = new Message(JSON.parse fs.readFileSync('data/stories/8863.json'))
    headers = story.headers()

    assert headers.boundary.match /^[0-9a-z]+$/
    assert headers.permalink.match /^https:\/\/news.ycombinator.com\/item\?id=\d+/
    assert headers.from.match /^.+ <.+@example.com>$/
    assert headers.profile.match /^https:\/\/news.ycombinator.com\/user\?id=.+/

    assert headers.message_id.match /^<\d+@news.ycombinator.com>$/
    assert.equal '', headers.parent_msgid

    assert headers.date.match /^[A-Za-z]+, [0-9]+ [A-Za-z]+ \d+ \d+:\d+:\d+ GMT$/

    assert headers.content_id.global.match /^<\d+_[0-9a-z]+@.+>$/
    assert headers.content_id.text.match /^<text_\d+_[0-9a-z]+@.+>$/
    assert headers.content_id.html.match /^<html_\d+_[0-9a-z]+@.+>$/

    assert headers.subject.match /^=\?UTF-8\?Q\?.+\?=$/

  test 'comment text filtered by w3m', (iamdone) ->
    comment = new Message(JSON.parse fs.readFileSync('data/comments/2921983.json'))
    results = {}

    comment.render results
    .then ->
      assert.equal "Aw shucks, guys ... you make me blush with your compliments.\n\nTell you what, Ill make a deal: I'll keep writing if you keep reading.\nK?", results.body_text
      iamdone()
    .done()

  test 'poll parts filtered by w3m', (iamdone) ->
    json_data = (JSON.parse fs.readFileSync('data/polls/126809/126809.json'))
    parts = []
    for idx in json_data.parts
      file = "data/polls/126809/#{idx}.json"
      parts.push JSON.parse fs.readFileSync(file).toString()

    poll = new Message json_data, parts

    results = {}
    poll.render results
    .then ->
      assert.deepEqual [
        "Users would create too many, and new arrivals would think News.YC was a\npoll site.",
        "Users would create fewer polls, because the main reason they do it now\nis to get karma from people voting up the poll choices.",
        "We'd have the same number of polls, but they wouldn't look as ugly."
        ], results.polparts
      iamdone()
    .done()
