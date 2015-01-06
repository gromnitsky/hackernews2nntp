fs = require 'fs'
path = require 'path'

Crawler = require './crawler'
meta = require '../package.json'

program = require 'commander'
Q = require 'q'
request = require 'request'

conf =
  url_pattern: 'https://hacker-news.firebaseio.com/v0/item/%d.json'

warnx = (msg) ->
  console.error "#{path.basename process.argv[1]} warning: #{msg}"

errx = (msg) ->
  console.error "#{path.basename process.argv[1]} error: #{msg}"
  process.exit 1

# return a promise
ids_get = (mode, spec) ->
  if mode == 'exact'
    return Q.fcall ->
      id = parseInt(spec[0]) || 0
      throw new Error "mode exact: invalid id `#{spec}`" if id < 1
      [id]

  if mode == 'last'
    return ids_last spec[0]
  if mode == 'top100'
    return ids_top100()
  if mode == 'range'
    return ids_range spec
  if mode == 'several'          # debug
    return Q.fcall -> spec
  else
    return Q.fcall -> throw new Error "invalid mode `#{mode}`"

# return a promise
ids_range = (spec) ->
  generate = (low, high, promise) ->
    max = 100000
    if low < 1
      promise.reject new Error "mode range: #{low} < 1"
    else if high < low
      promise.reject new Error "mode range: #{high} < #{low}"
    else if high-low > max
      promise.reject new Error "mode range: #{high}-#{low} > #{max}"
    else
      promise.resolve (idx for idx in [low..high])

  deferred = Q.defer()
  from = parseInt(spec[0]) || 0
  to = parseInt(spec[1]) || 0

  # till the end
  if from >= 1 && to == 0
    opt = { url: 'https://hacker-news.firebaseio.com/v0/maxitem.json?print=pretty' }
    request.get opt, (err, res, body) ->
      if err
        deferred.reject new Error "mode range: #{err.message}"
        return
      if res.statusCode == 200
        maxitem = parseInt(body) || 0
        if maxitem < 1
          deferred.reject new Error "mode range: maxitem <= 0"
          return

        generate from, maxitem, deferred
      else
        deferred.reject new Error "mode range: HTTP #{res.statusCode}"

  else
    generate from, to, deferred

  deferred.promise

# return a promise
ids_last = (spec) ->
  deferred = Q.defer()
  num = parseInt(spec) || 0
  if num < 1
    deferred.reject new Error "mode last: invalid number: #{spec}"
    return deferred.promise

  opt = { url: 'https://hacker-news.firebaseio.com/v0/maxitem.json?print=pretty' }
  request.get opt, (err, res, body) ->
    if err
      deferred.reject new Error "mode last: #{err.message}"
      return
    if res.statusCode == 200
      maxitem = parseInt(body) || 0
      if maxitem < 1
        deferred.reject new Error "mode last: maxitem <= 0"
        return

      result = maxitem-num
      if result < 1
        deferred.reject new Error "mode last: #{maxitem}-#{num}=#{result}"
      else
        deferred.resolve (idx for idx in [result..maxitem])
    else
      deferred.reject new Error "mode last: HTTP #{res.statusCode}"

  deferred.promise

# return a promise
ids_top100 = ->
  deferred = Q.defer()
  opt = { url: 'https://hacker-news.firebaseio.com/v0/topstories.json' }
  request.get opt, (err, res, body) ->
    if err
      deferred.reject new Error "mode top100: #{err.message}"
      return
    if res.statusCode == 200
      try
        arr = JSON.parse body
        throw new Error 'array is required' unless (arr instanceof Array)
      catch err
        deferred.reject new Error "mode top100: invalid json: #{err.message}"
        return

      deferred.resolve arr
    else
      deferred.reject new Error "mode top100: HTTP #{res.statusCode}"

  deferred.promise

maxitem_save = (file, id) ->
  return unless file
  try
    fs.writeFileSync file, id
  catch e
    warnx "maxitem saiving failed: #{e.message}"

maxitem_can_be_saved = (mode, stat) ->
  return false unless mode?.match /^(last|range)$/

  threshold = 80
  succ = (stat.downloaded.files / (stat.total()-stat.stale)) * 100
  if succ < threshold
    warnx "#{Math.floor succ}% successful downloaded items is
    < that #{threshold}% threshold, maxitem is not saved"

  succ >= threshold

exports.main = ->

  program
    .version meta.version
    .usage "[options] mode [spec]
    \n  Available modes: top100, last <number>, exact <id>, range <from> <to>"
    .option '-s, --show-stat', 'Print some statistics after all requests'
    .option '-v, --verbose', 'Print HTTP status on stderr (implies -s)'
    .option '-u, --url-pattern <string>', "Debug. Default: #{conf.url_pattern}", conf.url_pattern
    .option '--maxitem-save <file>', 'Write the highest id number to (for last & range modes only)'
    .option '--nokids', "Debug"
    .parse process.argv

  if program.args.length < 1
    program.outputHelp()
    process.exit 1

  mode = program.args[0]

  ids_get mode, program.args[1..-1]
  .then (ids) ->
    crawler = new Crawler program.urlPattern, ids.length
    unless program.verbose
      crawler.log = ->
        # empty
    crawler.look4kids = false if program.nokids

    crawler.event.on 'finish', (stat) ->
      console.error "\n#{stat.toString().toUpperCase()}" if program.verbose || program.showStat
      maxitem_save program.maxitemSave, ids[ids.length-1] if maxitem_can_be_saved mode, stat
    crawler.event.on 'body', (body) ->
      process.stdout.write "#{body}\n"
    crawler.event.on 'kid:error', (err) ->
      console.error err if program.verbose

    for n in ids
      crawler.get_item n
      .catch (err) ->
        console.error err if program.verbose
      .done()

  .catch (err) ->
    errx err.message
  .done()
