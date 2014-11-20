util = require 'util'
events = require 'events'

request = require 'request'
Q = require 'q'

class Stat

  constructor: ->
    @reset()

  reset: ->
    @downloaded = 0             # ok
    @failed = 0                 # connection/http error
    @invalid = 0                # invalid json
    @stale = 0                  # already in history

    @job_cur = 0
    @planned = 0
    @history = {}

  total: ->
    @downloaded + @failed + @invalid

  finished: ->
    (@total() == @planned) && (@planned != 0)

  toString: ->
    "downloaded: #{@downloaded}, failed: #{@failed}, invalid: #{@invalid}, stale: #{@stale}, total: #{@total()}"

  history_add: (id) ->
    @downloaded += 1
    @history[id] = true

class Crawler

  constructor: (@url_pattern, planned) ->
    @stat = new Stat()
    @stat.planned = planned

    @log = console.error
    @headers = {
      'User-Agent': 'get.coffee/0.0.1'
    }
    @event = new events.EventEmitter()

  url: (id) ->
    util.format @url_pattern, id

  prefix: (id, level) ->
    "j=#{@stat.job_cur}/l=#{level}/p=#{@stat.planned} #{@url(id)}"

  # return a promise
  get_item: (id, level = 0, expected_type = null) ->
    @stat.job_cur += 1
    prefix = @prefix id, level
    deferred = Q.defer()
    unless id
      deferred.reject new Error "no id, cannot do HTTP GET"
      return deferred.promise

    request.get {url: @url(id), headers: @headers}, (err, res, body) =>
      if err
        @stat.failed += 1
        @log "#{prefix}: Error: #{err.message}"
        deferred.reject new Error "#{id}: #{err.message}"
        return

      if res.statusCode == 200
        @log "#{prefix}: HTTP 200"

        return unless (json = @parse_body body, deferred)
        @stat.history_add id

        if json.type == 'poll'
          @log "#{prefix}: collecting pollopts"
          @get_fullpoll id, json.parts, body, deferred
        else
          @event.emit 'body', body unless json.type?.match /^poll/
          deferred.resolve body

          if json.kids?.length > 0
            @log "#{prefix}: kids!"
            @stat.planned += json.kids.length
            # RECURSION!
            @get_item(kid, level+1, expected_type) for kid in json.kids

      else # res.statusCode != 200
        @stat.failed += 1
        @log "#{prefix}: HTTP #{res.statusCode}"
        deferred.reject new Error "#{id}: HTTP #{res.statusCode}"

      @event.emit 'finish', @stat if @stat.finished()

    .on 'request', (req) =>
      if @stat.history[id] == true && expected_type != 'pollopt'
        @stat.stale += 1
        deferred.reject new Error "#{id}: saw it already"
        return deferred.promise
      @log "#{prefix}: HTTP GET"

    deferred.promise

  parse_body: (body, promise) ->
    try
      return JSON.parse body
    catch e
      @stat.failed += 1
      promise.reject new Error 'invalid json'

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
      @stat.downloaded -= 1
      promise.reject err
    .done()

  collect_pollopts: (poll_id, parts) ->
    deferred = Q.defer()
    if parts.length == 0
      deferred.reject new Error "#{poll_id}: invalid poll w/o parts"
      return deferred.promise

    @stat.planned += parts.length

    # collect results
    pollparts = []
    for part,idx in parts
      do (idx) =>
        @get_item part, 1, 'pollopt'
        .then (body) ->
          pollparts.push body
          if idx == parts.length-1
            deferred.resolve(pollparts)
        .catch (err) ->
          deferred.reject new Error "#{poll_id}: poll is missing pollopt: #{err.message}"
        .done()

    deferred.promise

module.exports = Crawler
