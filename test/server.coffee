#!/usr/bin/env coffee

http = require 'http'
url = require 'url'

u = require '../src/utils'

_items = [
  {},
  {
    id: 1
    type: 'story'
    title: 'story #1'
  },
  {
    id: 2
    type: 'story'
    title: 'story #2'
    kids: [5,6,500]
  },
  {
    id: 3
    type: 'poll'
    title: 'poll #1'
    parts: [7,8]
  },
  {
    id: 4
    type: 'story'
    title: 'story #4'
  },
  {
    id: 5
    type: 'comment'
    title: 'comment #1'
  },
  {
    id: 6
    type: 'comment'
    title: 'comment #2'
  },
  {
    id: 7
    type: 'pollopt'
    title: 'pollopt #1'
  },
  {
    id: 8
    type: 'pollopt'
    title: 'pollopt #2'
  },

  {
    id: 9
    type: 'poll'
    title: 'poll #2, invalid'
    parts: [7,8,500]
  },

  {
    id: 10
    type: 'poll'
    title: 'poll #3, invalid'
  }
  {
    id: 11
    type: 'poll'
    title: 'poll #4, invalid'
    parts: []
  }
]

for item,idx in _items
  _items[idx] = JSON.stringify item
_items[12] = "garbage"


sent_str = (res, str) ->
  res.setHeader 'Content-Type', 'application/json'
  res.setHeader 'Content-Length', str.length
  res.write str

exports.start = (port) ->
  server = http.createServer().listen port, 'localhost'
  server.on 'request', (req, res) ->
    url_parts = url.parse req.url, true

    if url_parts.pathname.match /^\/items\/memory/
      m = url_parts.pathname.match /\/([0-9]+)\.json$/
      if !m?[1]
        res.statusCode = 400
      else
        if (item = _items[parseInt m[1]])
          res.setHeader 'Content-Type', 'application/json'
          res.setHeader 'Content-Length', item.length
          res.write item
        else
          res.statusCode = 404

    else if url_parts.pathname.match /^\/livedata\//
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

    else
      res.statusCode = 500

    res.end()

  server

if process.argv[1] == __filename
  port = process.argv[2] || 8888
  console.error "listen at localhost:#{port}"
  exports.start port
