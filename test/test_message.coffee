assert = require 'assert'
fs = require 'fs'

Message = require '../src/message'

suite 'Message', ->
  setup ->
    @story1 = new Message(JSON.parse fs.readFileSync('data/stories/8863.json'))

  test 'headers', ->
    assert.equal 1, 1
    console.log @story1.render()
