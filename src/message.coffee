fs = require 'fs'
path = require 'path'
Mustache = require 'mustache'

class Message

  @NEWSGROUP_DEFAULT = 'news.ycombinator'

  @TemplateGet = (name) ->
    fs.readFileSync(path.resolve __dirname, '..', 'template', "#{name}.txt").toString()

  constructor: (@json_data) ->
    # TODO: validate @json_data

  id: ->
    "#{@json_data.id}_#{@json_data.type}@news.ycombinator.com"

  # return an obj
  #
  # {
  #   global: 123
  #   text: 456
  #   html: 789
  # }
  content_id: ->
    {
      global: 123
      text: 456
      html: 789
    }

  headers: ->
    {
      newsgroup: Message.NEWSGROUP_DEFAULT
      message_id: @id()
      boundary: 'TODO'
      parent_msgid: ''          # TODO
      content_id: @content_id()
      permalink: 'TODO'
      from: "#{@json_data.by} <noreply@example.com>"
    }

  render: ->
    json = JSON.parse JSON.stringify(@json_data) # omglol
    json.mail = @headers()
    Mustache.render Message.TemplateGet(json.type), json

  toString: ->
    @render()

module.exports = Message
