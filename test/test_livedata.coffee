assert = require 'assert'
http = require 'http'
url = require 'url'
util = require 'util'

Q = require 'q'

require './helper'
u = require '../src/utils'
livedata = require '../src/livedata'

suite 'livedata', ->
  setup ->
    livedata.conf.url = 'http://localhost:8800/livedata/%s.json'

  test 'maxitem', (iamdone) ->
    livedata.maxitem()
    .then (r) ->
      assert u.isNum r
      assert r > 0
      iamdone()
    .done()

  test 'maxitem zero', (iamdone) ->
    livedata.conf.url = 'http://localhost:8800/livedata/zero/%s.json'
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
    livedata.conf.url = 'http://localhost:8800/livedata/zero/%s.json'
    livedata.top100()
    .catch (err) ->
      assert.equal 'a non-empty array is required', err.message
      iamdone()
    .done()

  test 'top100 garbage', (iamdone) ->
    livedata.conf.url = 'http://localhost:8800/livedata/garbage/%s.json'
    livedata.top100()
    .catch (err) ->
      assert.equal 'a non-empty array is required', err.message
      iamdone()
    .done()

  test 'top100 404', (iamdone) ->
    livedata.conf.url = 'http://localhost:8800/livedata/BWAA'
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
