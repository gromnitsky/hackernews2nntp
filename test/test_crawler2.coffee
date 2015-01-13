assert = require 'assert'

Q = require 'q'

Crawler2 = require '../src/crawler2'
server = require './server'

my_server = server.start 8800

suite 'Crawler2', ->
  setup ->
    @crawler2 = new Crawler2()
    @crawler2.url_pattern = 'http://localhost:8800/%s.json'
    @crawler2.logger = ->

  test 'fetch_item_bare invalid invocation1', (iamdone) ->
    deferred = Q.defer()
    @crawler2.fetch_item_bare null, null, deferred

    deferred.promise
    .catch (err) ->
      assert err.message.match /^invalid id/
      iamdone()
    .done()

  test 'fetch_item_bare invalid invocation2', (iamdone) ->
    deferred = Q.defer()
    @crawler2.fetch_item_bare null, 1, deferred

    deferred.promise
    .catch (err) ->
      assert err.message.match /^invalid iter_id/
      iamdone()
    .done()

  test 'fetch_item_bare ok', (iamdone) ->
    deferred = Q.defer()
    @crawler2.fetch_item_bare 0, 1, deferred

    deferred.promise
    .then (r) ->
      assert.equal 1, r.id
      iamdone()
    .done()

  test 'fetch_item_bare invalid json', (iamdone) ->
    deferred = Q.defer()
    @crawler2.fetch_item_bare 0, 12, deferred

    deferred.promise
    .catch (err) ->
      assert.equal 'InvalidJSON', err.constructor.name
      iamdone()
    .done()

  test 'fetch_item_bare invalid item', (iamdone) ->
    deferred = Q.defer()
    @crawler2.fetch_item_bare 0, 11, deferred

    deferred.promise
    .catch (err) ->
      assert.equal 'InvalidItem', err.constructor.name
      iamdone()
    .done()

  test 'fetch_item_bare not found', (iamdone) ->
    deferred = Q.defer()
    @crawler2.fetch_item_bare 0, 500, deferred

    deferred.promise
    .catch (err) ->
      assert.equal 'NoItem', err.constructor.name
      iamdone()
    .done()

  test 'fetch_item_bare no connection', (iamdone) ->
    @crawler2.url_pattern = 'http://localhost:99999/%s.json'
    deferred = Q.defer()
    @crawler2.fetch_item_bare 0, 1, deferred

    deferred.promise
    .catch (err) ->
      assert.equal 'NoConnect', err.constructor.name
      iamdone()
    .done()

  test 'emit "items"', (iamdone) ->
    crw = new Crawler2()
    crw.url_pattern = 'http://localhost:8800/%s.json'
    crw.logger = ->
    iter_id = crw.stat.iter_id_next()

    error_count = 0
    crw.event.emit 'items', iter_id, [500,1,1]

    crw.event.on 'data', (iter_id, data) ->
      assert.equal 1, JSON.parse(data).id

    crw.event.on 'herr', (err) ->
      error_count++
      # 500 must be NoItem, 1 -- Dup
      iamdone() if 2 == error_count

  test 'emit "poll"', (iamdone) ->
    crw = new Crawler2()
    crw.url_pattern = 'http://localhost:8800/%s.json'
    crw.logger = ->
    iter_id = crw.stat.iter_id_next()

    error_count = 0
    crw.event.emit 'items', iter_id, [7,2,3,9]

    crw.event.on 'herr', (err) ->
      error_count++
      iamdone() if 3 == error_count
