assert = require 'assert'

Q = require 'q'

require './helper'
Crawler2 = require '../src/crawler2'

suite 'Crawler2', ->
  setup ->
    @crawler2 = new Crawler2()
    @crawler2.url_pattern = 'http://localhost:8800/items/memory/%s.json'
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
    crw.url_pattern = 'http://localhost:8800/items/memory/%s.json'
    crw.logger = ->
    iter_id = crw.stat.iter_id_next()

    error_count = 0
    crw.event.emit 'items', iter_id, [500,1,1]

    crw.event.on 'data', (iter_id, data) ->
      assert.equal 1, JSON.parse(data).id

    crw.event.on 'finish', ->
      stat = crw.stat.succinct()
      assert.equal 1, stat.items
      assert.equal 0, stat.neterr
      assert.equal 0, stat.invalid
      assert.equal 1, stat.dup
      assert.equal 2, stat.uniq
      iamdone()

  test 'emit "poll"', (iamdone) ->
    crw = new Crawler2()
    crw.url_pattern = 'http://localhost:8800/items/memory/%s.json'
    crw.logger = ->
    iter_id = crw.stat.iter_id_next()

    error_count = 0
    crw.event.emit 'items', iter_id, [7,2,3,9]

    crw.event.on 'finish', ->
      stat = crw.stat.succinct()
      assert.equal 9, stat.items
      assert.equal 2, stat.neterr
      assert.equal 1, stat.invalid
      assert.equal 0, stat.dup
      assert.equal 8, stat.uniq
      iamdone()
