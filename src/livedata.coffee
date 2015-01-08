util = require 'util'

Q = require 'q'
request = require 'request'

exports.conf =
  url: 'https://hacker-news.firebaseio.com/v0/%s.json'

# return a promise
http_get = (url) ->
  deferred = Q.defer()

  opt = { url: url }
  request.get opt, (err, res, body) ->
    if err
      err.message = "#{url}: #{err.message}"
      deferred.reject err
      return

    if res.statusCode == 200
      deferred.resolve body
    else
      deferred.reject new Error "HTTP #{res.statusCode}"

  deferred.promise

# return a promise
exports.maxitem = ->
  http_get util.format(exports.conf.url, 'maxitem')
  .then (body) ->
    maxitem = parseInt(body) || 0
    if maxitem < 1
      throw new Error "maxitem <= 0"
    else
      maxitem

# return a promise
exports.top100 = ->
  http_get util.format(exports.conf.url, 'topstories')
  .then (body) ->
    try
      arr = JSON.parse body
    catch err
      throw new Error "invalid json: #{err.message}"

    if util.isArray(arr) && arr.length > 0
      arr
    else
      throw new Error 'a non-empty array is required'
