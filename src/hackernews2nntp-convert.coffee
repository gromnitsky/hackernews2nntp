readline = require 'readline'
path = require 'path'

program = require 'commander'

meta = require './meta.json'
Message = require './message'
mbox = require './mbox'

conf =
  verbose: 0
  format: 'rnews'               # also: mbox

warnx = (msg) ->
  console.error "#{path.basename process.argv[1]} warning: #{msg}"

wrap_mail = (message) ->
  return unless message

  message.render()
  .then (mail) ->
    if conf.format == 'rnews'
      console.log "#! rnews #{mail.length + 1}"
      console.log mail
    else
      console.log mbox.prefix message.json_data
      console.log mbox.escape mail

message_create = (json, parts = []) ->
  try
    message = new Message json, parts
  catch err
    if err.message.match /invalid json input/
      warnx "json validation failed"
      return null
    else
      throw err

  message

exports.main = ->
  program
    .version meta.version
    .option '-v, --verbose', 'Print debug info to stderr'
    .option '-f, --format [format]', 'Convert to rnews batch (default) or mbox', conf.format
    .parse process.argv

  conf.format = process.format

  rl = readline.createInterface {
    input: process.stdin
    output: process.stdout
    terminal: false
  }

  poll = null
  poll_read = 0
  pollopts = []

  rl.on 'line', (line) ->
    try
      json = JSON.parse line
    catch err
      warnx "line not parsed: #{err.message}"
      return

    if !poll && json.type == 'poll'
      # read next several lines to construct a poll
      poll = json
      if json.parts?.length < 1
        warnx "invalid poll w/ id=#{json.id}"
        poll = null
        return

      poll_read = json.parts.length
    else if poll
      --poll_read
      pollopts.push json

      if poll_read == 0         # we're done collecting
        message = message_create poll, pollopts
        wrap_mail message
        poll = null
        pollopts = []
    else
      message = message_create json
      wrap_mail message
