fs = require 'fs'
path = require 'path'
util = require 'util'

meta = require '../package.json'
Crawler2 = require './crawler2'
livedata = require './livedata'
u = require './utils'

program = require 'commander'
Q = require 'q'
request = require 'request'

conf =
  url_pattern: 'https://hacker-news.firebaseio.com/v0/item/%d.json'
  verbose: 0
  conn_per_sec: Crawler2.CONN_PER_SEC

# return a promise
ids_get = (mode, spec) ->
  if mode == 'exact'
    return Q.fcall ->
      id = parseInt(spec[0]) || 0
      throw new Error "`#{spec}` must be > 0" if id < 1
      [id]

  if mode == 'last'
    return ids_last spec[0]
  if mode == 'top100'
    return livedata.top100()
  if mode == 'range'
    return ids_range spec
  if mode == 'several'          # debug
    return Q.fcall -> spec
  else
    return Q.fcall -> throw new Error "invalid mode `#{mode}`"

# return a promise
ids_range = (spec) ->
  generate = (low, high) ->
    max = 100000
    if low < 1
      throw new Error "#{low} < 1"
    else if high < low
      throw new Error "#{high} < #{low}"
    else if high-low > max
      throw new Error "#{high}-#{low} > #{max}"
    else
      (idx for idx in [low..high])

  from = parseInt(spec[0]) || 0
  to = parseInt(spec[1]) || 0

  if from >= 1 && to == 0
    # till the end
    livedata.maxitem()
    .then (maxitem) ->
      generate from, maxitem
  else
    Q.fcall -> generate from, to

# return a promise
ids_last = (spec) ->
  num = parseInt(spec) || 0
  if num < 1
    return Q.fcall -> throw new Error "`#{spec}` must be >= 1"

  livedata.maxitem()
  .then (maxitem) ->
    result = maxitem - num + 1
    if result < 1
      throw new Error "#{maxitem}-#{num} < 1"
    else
      (idx for idx in [result..maxitem])

maxitem_save = (file, id) ->
  return unless file
  try
    fs.writeFileSync file, id
  catch e
    u.warnx "maxitem saiving failed: #{e.message}"

maxitem_can_be_saved = (mode, stat) ->
  return false unless mode?.match /^(last|range)$/

  threshold = 80
  succ = (stat.downloaded.files / (stat.total()-stat.stale)) * 100
  if succ < threshold
    u.warnx "#{Math.floor succ}% successful downloaded items is
    < that #{threshold}% threshold, maxitem is not saved"

  succ >= threshold

exports.main = ->

  program
    .version meta.version
    .usage "[options] mode [spec]
    \n  Available modes: top100, last <number>, exact <id>, range <from> <to>"
    .option '-s, --show-stat', 'Print some statistics after all requests'
    .option '-v, --verbose', 'Print HTTP status on stderr (implies -s)', -> conf.verbose++
    .option '--maxitem-save <file>', 'Write the highest id number to (for last & range modes only)'
    .option '-u, --url-pattern <string>', "Debug. Default: #{conf.url_pattern}", conf.url_pattern
    .option '--nokids', "Debug"
    .option '--ids-only', "Debug"
    .option '--conn-per-sec <digit>', "HTTP request limit (0 == no limit). Default: #{conf.conn_per_sec}", conf.conn_per_sec
    .parse process.argv

  if program.args.length < 1
    program.outputHelp()
    process.exit 1

  mode = program.args[0]

  ids_get mode, program.args[1..-1]
  .then (ids) ->
    if program.idsOnly
      console.error ids
      process.exit 0

    crawler2 = new Crawler2 program.connPerSec
    crawler2.url_pattern = program.urlPattern
    unless conf.verbose
      crawler2.logger = ->
        # empty
    crawler2.look4kids = false if program.nokids

    process.on 'exit', ->
      console.error "\nSTAT: " + util.inspect crawler2.stat.succinct() if conf.verbose || program.showStat
      console.error util.inspect crawler2.stat._history, { showHidden: false, depth: null } if conf.verbose >= 2
      if program.maxitemSave && maxitem_can_be_saved mode, crawler2.stat
        maxitem_save program.maxitemSave, ids[ids.length-1]

    crawler2.event.on 'data', (iter_id, data) ->
      process.stdout.write "#{data}\n"

    crawler2.event.on 'herr', (err) ->
      console.error "ERROR: ii=#{err.iter_id}/id=#{err.id}: #{err.message}" if conf.verbose

    # start 1st iteration
    crawler2.event.emit 'items', crawler2.stat.iter_id_next(), ids

  .catch (err) ->
    u.errx err.message
  .done()
