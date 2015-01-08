assert = require 'assert'
http = require 'http'
url = require 'url'
util = require 'util'

Q = require 'q'

u = require '../src/utils'
livedata = require '../src/livedata'

sent_str = (res, str) ->
  res.setHeader 'Content-Type', 'application/json'
  res.setHeader 'Content-Length', str.length
  res.write str
  res.end()

server = http.createServer().listen 8124, 'localhost'
server.on 'request', (req, res) ->
  url_parts = url.parse req.url, true

  if url_parts.pathname.match /\/livedata\/maxitem.json$/
    sent_str res, u.randrange(1,100).toString()
  else if url_parts.pathname.match /\/zero\/maxitem.json$/
    sent_str res, '0'

  else if url_parts.pathname.match /\/livedata\/topstories.json$/
    sent_str res, JSON.stringify [1,2,3]
  else if url_parts.pathname.match /\/zero\/topstories.json$/
    sent_str res, JSON.stringify []
  else if url_parts.pathname.match /\/garbage\/topstories.json$/
    sent_str res, JSON.stringify 'garbage'
  else
    res.statusCode = 404
    res.end()

suite 'livedata', ->
  setup ->
    livedata.conf.url = 'http://localhost:8124/livedata/%s.json'

  test 'maxitem', (iamdone) ->
    livedata.maxitem()
    .then (r) ->
      assert u.isNum r
      assert r > 0
      iamdone()
    .done()

  test 'maxitem zero', (iamdone) ->
    livedata.conf.url = 'http://localhost:8124/zero/%s.json'
    livedata.maxitem()
    .catch (err) ->
      assert.equal 'maxitem <= 0', err.message
      iamdone()
    .done()

  test 'top100', (iamdone) ->
    livedata.top100()
    .then (r) ->
      assert util.isArray r
      assert r.length > 0
      iamdone()
    .done()

  test 'top100 zero', (iamdone) ->
    livedata.conf.url = 'http://localhost:8124/zero/%s.json'
    livedata.top100()
    .catch (err) ->
      assert.equal 'a non-empty array is required', err.message
      iamdone()
    .done()

  test 'top100 garbage', (iamdone) ->
    livedata.conf.url = 'http://localhost:8124/garbage/%s.json'
    livedata.top100()
    .catch (err) ->
      assert.equal 'a non-empty array is required', err.message
      iamdone()
    .done()

  test 'top100 404', (iamdone) ->
    livedata.conf.url = 'http://localhost:8124/BWAA'
    livedata.top100()
    .catch (err) ->
      assert.equal 'HTTP 404', err.message
      iamdone()
    .done()

  test 'top100 invalid url', (iamdone) ->
    livedata.conf.url = 'http://localhost:99999/'
    livedata.top100()
    .catch (err) ->
      assert.equal err.code, 'ECONNREFUSED'
      iamdone()
    .done()
