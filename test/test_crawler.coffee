assert = require 'assert'
fs = require 'fs'
http = require 'http'
url = require 'url'
path = require 'path'

Q = require 'q'

Crawler = require '../src/crawler'

# create a static http server
server = http.createServer().listen 8123, 'localhost'
server.on 'request', (req, res) ->
  url_parts = url.parse req.url, true

  if url_parts.pathname.match /^\/[0-9]+\.json$/
    fs.readFile path.join('data/json', url_parts.pathname), (err, data) ->
      if err
        if err.code == 'ENOENT'
          res.statusCode = 404
        else
          throw err
      else
        res.setHeader 'Content-Type', 'application/json'
        res.setHeader 'Content-Length', data.length
        res.write data

      res.end()
  else
    res.statusCode = 404
    res.end()


suite 'Crawler', ->
  setup ->

  test 'smoke', (iamdone) ->
    start = 1
    planned = 44
    result = []
    errors = []

    crawler = new Crawler "http://localhost:8123/%d.json", planned
    crawler.log = ->

    crawler.event.on 'finish', (stat) ->
#      console.log "\n#{stat}"
      server.close()

      assert.equal 39, crawler.stat.downloaded.files
      assert.equal 1351, crawler.stat.downloaded.bytes
      assert.equal 40, crawler.stat.failed
      assert.equal 10, crawler.stat.invalid
      assert.equal 10, crawler.stat.stale
      assert.equal 99, crawler.stat.total()

#      console.log errors
      assert.equal 29, errors.length
      assert errors.indexOf('20: poll is missing pollopt: 320: HTTP 404') != -1

#      console.log result

      iamdone()

    crawler.event.on 'body', (body) ->
      result.push body
#      console.log body

    for n in [start..planned]
      crawler.get_item n
      .catch (err) ->
#        console.error err
        errors.push err.message
      .done()
