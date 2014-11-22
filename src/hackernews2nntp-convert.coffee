readline = require 'readline'
path = require 'path'
{spawn} = require 'child_process'

program = require 'commander'
shellquote = require 'shell-quote'

meta = require './meta.json'
Message = require './message'
mbox = require './mbox'

conf =
  verbose: false
  format: 'rnews'
  cmd: ['sudo', 'rnews', '-N']
  destination: 'printer'



warnx = (msg) ->
  console.error "#{path.basename process.argv[1]} warning: #{msg}"

log = (msg) ->
  console.error "#{path.basename process.argv[1]}: #{msg}" if conf.verbose

dispatcher = {

  printer: (id, mail) ->
    log "#{id}: writing"
    console.log mail

  fork: (id, mail) ->
    text = ''
    stderr = ''

    log "#{id}: writing to `#{conf.cmd.join ' '}`"
    cmd = spawn conf.cmd[0], conf.cmd[1..-1]

    cmd.on 'error', (err) ->
      warnx "#{id}: cmd failed: #{err.message}"

    cmd.stdout.on 'data', (data) -> text += data
    cmd.stderr.on 'data', (data) -> stderr += data

    cmd.on 'close', (code) ->
      log "#{id}: cmd exit code: #{code}"

    cmd.stdin.write "#{mail}\n"
    cmd.stdin.end()
}

wrap_mail = (message) ->
  return unless message

  sendoff = dispatcher[conf.destination]

  message.render()
  .then (mail) ->
    if conf.format == 'rnews'
      sendoff message.json_data.id, "#! rnews #{Buffer.byteLength(mail) + 1}\n#{mail}"
    else if conf.format == 'mbox'
      sendoff message.json_data.id, "#{mbox.prefix message.json_data}\n#{mbox.escape mail}"
    else
      sendoff message.json_data.id, mail
  .done()


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
    .option '--fork', "Don't print the result to stdout, but feed an external program w/ input"
    .option '--cmd <string>', "Custom external command instead of `#{conf.cmd.join ' '}`"
    .option '-f, --format <format>', 'Convert to rnews (default), mbox or plain'
    .parse process.argv

  conf.verbose = program.verbose if program.verbose
  conf.destination = 'fork' if program.fork
  conf.format = program.format  if program.format
  conf.cmd = shellquote.parse program.cmd if program.cmd

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

  process.stdout.on 'error', (err) ->
    warnx "program you pipe in stopped reading input" if err.code == "EPIPE"
    warnx err
    process.exit 1
