# All this rigmarole only to concurrently make some http get requests
# :(

events = require 'events'
util = require 'util'

Q = require 'q'
RateLimiter = require('limiter').RateLimiter
request = require 'request'

u = require './utils'
meta = require '../package.json'

# Example:
#
# class MyError extends Error
#   constructor: (msg) -> superError MyError, this, msg
#
superError = (klass, errObj, msg) ->
  errObj.name = klass.name
  errObj.message = msg
  Error.captureStackTrace errObj, klass

class CrawlerError extends Error
  constructor: (msg) -> superError CrawlerError, this, msg

class Dup extends CrawlerError
  constructor: (msg) -> superError Dup, this, msg

class InvalidJSON extends CrawlerError
  constructor: (msg) -> superError InvalidJSON, this, msg

class InvalidItem extends CrawlerError
  constructor: (msg) -> superError InvalidItem, this, msg

class NoItem extends CrawlerError
  constructor: (msg) -> superError NoItem, this, msg

class PolloptInIteration extends CrawlerError
  constructor: (msg) -> superError PolloptInIteration, this, msg

class NoConnect extends CrawlerError
  constructor: (msg) -> superError NoConnect, this, msg

makeError = (klass, iter_id, id, msg) ->
  err = new klass msg
  err.iter_id = iter_id
  err.id = id
  err

class Stat

  constructor: (@event)->
    @iter_id = 0
    @_history = {}
    @bytes = 0

  # id -- item id
  history: (iter_id, id, err, iter_id_next = null) ->
    o = @_history[iter_id] ||= {}
    info = {}
    info.err = err if err
    info.iter_id_next = iter_id_next.toString() if iter_id_next
    o[id] = info
    @event.emit 'herr', err if info.err

  iter_id_next: ->
    ++@iter_id

  has_been: (id) ->
    id = id.toString()
    for key,val of @_history
      return true if id of val
    false

  succinct: ->
    ids = {}
    for ikey,ival of @_history
      for id,val of ival
        ids[id] ||= []
        ids[id].push val

    r =
      bytes: @bytes
      items: 0
      neterr: 0
      invalid: 0
      dup: 0
      uniq: (Object.keys ids).length

    errclass2desc =
      'Dup': 'dup'
      'InvalidJSON': 'invalid'
      'InvalidItem': 'invalid'
      'NoItem': 'neterr'
      'PolloptInIteration': 'invalid'
      'NoConnect': 'neterr'

    for id,val of ids
      for item in val
        if !item.err
          r.items++
        else
          r[errclass2desc[item.err.constructor.name]]++

    r

item_validate = (json) ->
  return false if !json.id
  return false if !json.type?.match /^(story|comment|poll|pollopt)$/
  return false if json.kids && !util.isArray json.kids

  return false if json.type == 'poll' && !json.parts
  return false if json.type == 'poll' && !util.isArray json.parts
  return false if json.type == 'poll' && json.parts.length == 0

  true

class Crawler2

  @idValidate = (id, deferred) ->
    unless u.isNum id
      deferred.reject new Error "invalid id `#{id}`"
      return false
    true

  @iterIdValidate = (iter_id, deferred) ->
    u.isStr = (s) -> toString.apply(s) == '[object String]'
    unless u.isStr(iter_id) || u.isNum(iter_id)
      deferred.reject new Error "invalid iter_id `#{iter_id}`"
      return false
    true

  constructor: (@conn_per_sec = 50) ->
    @url_pattern = 'https://hacker-news.firebaseio.com/v0/item/%s.json'
    @look4kids = true
    @logger = console.error
    @event = new events.EventEmitter()
    @stat = new Stat @event
    @limiter = new RateLimiter(@conn_per_sec, 'sec')

    @event.on 'items', (iter_id, idarr) =>
      @iteration iter_id, idarr

    @event.on 'poll', (iter_id, item) =>
      @poll iter_id, item

    @http_headers = {
      'User-Agent': [meta.name, meta.version].join '/'
    }

  # Emit 'data' event if an item was fetched. Emit 'poll' event if the
  # fetched item was a poll. Emit 'item' event if the fetched item had
  # kids.
  iteration: (iter_id, idarr) ->
    throw new Error "array of IDs is expected" unless util.isArray idarr

    for id in idarr
      @fetch_item(iter_id, id)
      .then (r) =>
        if r.type == 'pollopt'
          throw makeError PolloptInIteration, iter_id, r.id, "must be processed by Crawler2#poll()"

        else if r.type == 'poll'
          iter_id_next = @stat.iter_id_next() + '.poll'
          @stat.history iter_id, r.id, null, iter_id_next
          @event.emit 'poll', iter_id_next, r

        else
          @event.emit 'data', iter_id, JSON.stringify r

          if r.kids && @look4kids
            iter_id_next = @stat.iter_id_next()
            @stat.history iter_id, r.id, null, iter_id_next

            @event.emit 'items', iter_id_next, r.kids
          else
            @stat.history iter_id, r.id, null, null

      .catch (err) =>
        if err instanceof CrawlerError
          @stat.history iter_id, err.id, err, null
        else
          throw err
      .done()

  # Emit a 'data' msg if a poll was collected w/o errors.
  #
  # If there are errors in collecting of any poll parts, record the fact
  # in the @stat for current iteration.
  #
  # Side effects: modifies @stat
  # Return: nothing
  poll: (iter_id, item) ->
    # include poll item itself before its additional parts
    parts = [JSON.stringify item]

    promises = []
    for id in item.parts
      p = @fetch_item(iter_id, id)
      promises.push p

      p.then (r) =>
        @stat.history iter_id, r.id, null, null
        parts.push JSON.stringify r
      .catch (err) =>
        # current pollopt is invalid
        if err instanceof CrawlerError
          @stat.history iter_id, err.id, err, null
        else
          throw err
      .done()

    # wait for all promises to finish
    Q.all(promises).then =>
      @event.emit 'data', iter_id, parts.join "\n"

  # Side effects: modifies @stat, @stat.bytes
  # Return: a promise w/ a response body
  http_get: (iter_id, id) ->
    log = (msg) => @logger "ii=#{iter_id}/id=#{id} #{msg}"
    deferred = Q.defer()

    opt =
      url: util.format @url_pattern, id
      headers: @http_headers
    cur_req = request.get opt, (err, res, body) =>
      if err
        deferred.reject makeError NoConnect, iter_id, id, err.message
        return deferred.promise

      if res.statusCode == 200
        @stat.bytes += Buffer.byteLength body
        log "HTTP 200"
        deferred.resolve body
      else
        deferred.reject makeError NoItem, iter_id, id, "HTTP #{res.statusCode}"

    cur_req.on 'request', =>
      # check in history, mark as dup; ignore polls iterations
      if @stat.has_been id
        unless iter_id.toString().match /\.poll$/
          deferred.reject makeError Dup, iter_id, id, "dup!"
          cur_req.abort()
      else
        log "HTTP GET"
        @stat.history iter_id, id, null, null

    deferred.promise

  # Fetch id via http, parse it & set the result in `deferred`.
  #
  # Side effects: modifies @stat
  # Return: nothing
  fetch_item_bare: (iter_id, id, deferred) ->
    return unless Crawler2.idValidate id, deferred
    return unless Crawler2.iterIdValidate iter_id, deferred

    @http_get iter_id, id
    .then (item) ->
      try
        item = JSON.parse item
      catch e
        deferred.reject makeError InvalidJSON, iter_id, id, "invalid JSON"
        return

      if item_validate item
        deferred.resolve item
      else
        deferred.reject makeError InvalidItem, iter_id, id, "invalid data in the item"
    .catch (err) ->
      deferred.reject err
    .done()

  # A wrapper for #fetch_item_bare(). Limits executions of
  # #fetch_item_bare() by @conn_per_sec.
  #
  # Side effects: modifies @stat
  # Return: a promise w/ the result from #fetch_item_bare()
  fetch_item: (iter_id, id) ->
    deferred = Q.defer()
    @limiter.removeTokens 1, (lim_err, remainingRequests) =>
      @fetch_item_bare iter_id, id, deferred
    deferred.promise


module.exports = Crawler2
