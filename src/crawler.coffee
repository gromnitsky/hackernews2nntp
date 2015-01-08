util = require 'util'
events = require 'events'
fs = require 'fs'
path = require 'path'

request = require 'request'
Q = require 'q'

meta = require '../package.json'

class Stat

  constructor: ->
    @reset()

  reset: ->
    @downloaded =
      files: 0                  # ok
      bytes: 0                  # may include @failed
    @failed = 0                 # connection/http error
    @invalid = 0                # invalid json
    @stale = 0                  # already in history

    @job = {
      cur: 0
      planned: 0                # total number
    }
    @history = {}
    @history_pending_request = {}

  total: ->
    @downloaded.files + @failed + @invalid + @stale

  finished: ->
    (@total() == @job.planned) && (@job.planned != 0)

  toString: ->
    "downloaded files/bytes: #{@downloaded.files}/#{@downloaded.bytes}, failed: #{@failed}, invalid: #{@invalid}, stale: #{@stale}, total: #{@total()}"

  history_add: (id, body = "") ->
    @downloaded.files += 1
    @downloaded.bytes += Buffer.byteLength body
    @history[id] = true

class Crawler

  constructor: (@url_pattern, job_planned) ->
    @stat = new Stat()
    @stat.job.planned = job_planned

    @log = console.error
    @headers = {
      'User-Agent': [meta.name, meta.version].join '/'
    }
    @event = new events.EventEmitter()
    @look4kids = true

  url: (id) ->
    util.format @url_pattern, id

  prefix: (id, level) ->
    "jc=#{@stat.job.cur}/l=#{level}/jp=#{@stat.job.planned} #{@url(id)}"

  finish_check: ->
    @event.emit 'finish', @stat if @stat.finished()

  # return a promise
  get_item: (id, level = 0, expected_type = null) ->
    @stat.job.cur += 1
    prefix = @prefix id, level
    deferred = Q.defer()
    unless id
      deferred.reject new Error "no id, cannot do HTTP GET"
      @finish_check()
      return deferred.promise

    cur_req = request.get {url: @url(id), headers: @headers}, (err, res, body) =>
      if err
        @stat.failed += 1
        @log "#{prefix}: Error: #{err.message}"
        deferred.reject new Error "#{id}: #{err.message}"
        @finish_check()
        return

      if res.statusCode == 200
        @log "#{prefix}: HTTP 200"

        json = @parse_body id, body, deferred
        if json
          @stat.history_add id, body

          if json.type == 'poll'
            @log "#{prefix}: collecting #{json.parts?.length} pollopts"
            @get_fullpoll id, json.parts, body, deferred
          else
            @event.emit 'body', body unless json.type?.match /^poll/
            deferred.resolve body

          # everyone except pollopt may have kids
          if @look4kids & json.kids?.length > 0
            @log "#{prefix}: #{json.kids.length} kid(s)!"
            @stat.job.planned += json.kids.length
            # *** RECURSION! All your memory are belong to me. ***
            for kid in json.kids
              @get_item(kid, level+1, expected_type)
              .catch (err) =>
                @event.emit 'kid:error', err
              .done()

      else # res.statusCode != 200
        @stat.failed += 1
        @log "#{prefix}: HTTP #{res.statusCode}"
        deferred.reject new Error "#{id}: HTTP #{res.statusCode}"

      @finish_check()

    .on 'request', (req) =>
      if (@stat.history[id] == true || @stat.history_pending_request[id] == true) &&
          expected_type != 'pollopt'
        @stat.stale += 1
        @log "#{prefix}: aborted HTTP GET"
        cur_req.abort()
        deferred.reject new Error "#{id}: saw it already"
      else
        @stat.history_pending_request[id] = true
        @log "#{prefix}: HTTP GET"

    deferred.promise

  parse_body: (id, body, promise) ->
    try
      return JSON.parse body
    catch e
      @stat.invalid += 1
      promise.reject new Error "#{id}: invalid json"

    null

  get_fullpoll: (poll_id, parts, poll_body, promise) ->
    @collect_pollopts(poll_id, parts)
    .then (poll) =>
      # poll body + all its parts
      body = ([poll_body].concat poll).join "\n"
      @event.emit 'body', body
      promise.resolve body
    .catch (err) =>
      # poll is broken, because one of its pollopts is broken/missing
      @stat.failed += 1
      @stat.downloaded.files -= 1
      promise.reject err
    .done()

  collect_pollopts: (poll_id, parts) ->
    deferred = Q.defer()
    if !util.isArray(parts) || parts.length == 0
      deferred.reject new Error "#{poll_id}: invalid poll w/o parts"
      return deferred.promise

    @stat.job.planned += parts.length

    # collect results
    pollparts = []
    promises = []
    for part,idx in parts
      pro = @get_item part, 1, 'pollopt'
      promises.push pro
      pro.then (body) ->
        pollparts.push body
      .catch (err) ->
        deferred.reject new Error "#{poll_id}: poll is missing pollopt: #{err.message}"
      .done()

    Q.all(promises)
    .then ->
      deferred.resolve pollparts

    deferred.promise

module.exports = Crawler
