fs = require 'fs'
path = require 'path'

Crawler = require './crawler'
meta = JSON.parse fs.readFileSync(path.join __dirname, 'meta.json').toString()

program = require 'commander'

conf =
  url_pattern: 'https://hacker-news.firebaseio.com/v0/item/%d.json'
  mode: 'top100'                 # also: last, exact

errx = (msg) ->
  console.error "#{path.basename process.argv[1]} error: #{msg}"
  process.exit 1

ids_get = (pattern) ->
  if conf.mode == 'exact'
    [pattern]
  else
    throw new Error "invalid conf.mode value"

exports.main = ->

  program
    .version meta.version
    .option '-v, --verbose', 'Print HTTP status on stderr'
    .option '-u, --url-pattern [string]', "Default: #{conf.url_pattern}", conf.url_pattern
    .parse process.argv

  if program.args.length < 1
    program.outputHelp()
    process.exit 1

  if program.args.length == 1
    # default mode is top100
    ids_pattern = program.args[0]
  else
    conf.mode = program.args[0]
    ids_pattern = program.args[1]

  errx "unsupported mode: #{conf.mode}" unless conf.mode.match /^exact$/
  ids = ids_get ids_pattern

  crawler = new Crawler program.urlPattern, ids.length
  unless program.verbose
    crawler.log = ->
      # empty

  crawler.event.on 'finish', (stat) ->
    crawler.log "\n#{stat}"
  crawler.event.on 'body', (body) ->
    console.log body

  for n in ids
    crawler.get_item n
    .catch (err) ->
      console.error err if program.verbose
    .done()
