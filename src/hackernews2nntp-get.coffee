fs = require 'fs'
path = require 'path'

Crawler = require './crawler'
meta = require './meta.json'

program = require 'commander'
Q = require 'q'
request = require 'request'

conf =
  url_pattern: 'https://hacker-news.firebaseio.com/v0/item/%d.json'

errx = (msg) ->
  console.error "#{path.basename process.argv[1]} error: #{msg}"
  process.exit 1

# return a promise
ids_get = (mode, spec) ->
  if mode == 'exact'
    return Q.fcall ->
      id = parseInt(spec) || 0
      throw new Error "mode exact: invalid id #{spec}" if id < 1
      [id]

  if mode == 'last'
    return ids_last spec
  else
    return Q.fcall -> throw new Error "invalid mode #{conf.mode}"

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
      deferred.reject new Error "mode last: maxitem <= 0" if maxitem < 1

      result = maxitem-num
      if result < 1
        deferred.reject new Error "mode last: #{maxitem}-#{num}=#{result}"
      else
        deferred.resolve (idx for idx in [result..maxitem])
    else
      deferred.reject new Error "mode last: HTTP #{res.statusCode}"

  deferred.promise

exports.main = ->

  program
    .version meta.version
    .usage "[options] mode [spec]
    \n  Available modes: top100, last [number], exact [id]"
    .option '-v, --verbose', 'Print HTTP status on stderr'
    .option '-u, --url-pattern [string]', "Debug. Only for 'exact' mode. Default: #{conf.url_pattern}", conf.url_pattern
    .option '--nokids', "Debug"
    .parse process.argv

  if program.args.length < 1
    program.outputHelp()
    process.exit 1

  ids_get program.args[0], program.args[1]
  .then (ids) ->
    crawler = new Crawler program.urlPattern, ids.length
    unless program.verbose
      crawler.log = ->
        # empty
    crawler.look4kids = false if program.nokids

    crawler.event.on 'finish', (stat) ->
      crawler.log "\n#{stat}"
    crawler.event.on 'body', (body) ->
      console.log body

    for n in ids
      crawler.get_item n
      .catch (err) ->
        console.error err if program.verbose
      .done()

  .catch (err) ->
    errx err.message
  .done()
