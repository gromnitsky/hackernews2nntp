fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
os = require 'os'

Mustache = require 'mustache'

class Message

  @NEWSGROUP_DEFAULT = 'news.ycombinator'

  @TemplateGet = (name) ->
    fs.readFileSync(path.resolve __dirname, '..', 'template', "#{name}.txt").toString()

  constructor: (@json_data) ->
    # TODO: validate @json_data

  id: ->
    "#{@json_data.id}@news.ycombinator.com"

  parent_id: ->
    return '' unless @json_data.parent
    "#{@json_data.parent}@news.ycombinator.com"

  # return an obj
  #
  # {
  #   global: 123
  #   text: 456
  #   html: 789
  # }
  content_id: ->
    r = "#{@json_data.time}_#{crypto.pseudoRandomBytes(8).toString('hex')}@#{os.hostname()}"
    {
      global: r
      text: "text_#{r}"
      html: "html_#{r}"
    }

  headers: ->
    {
      newsgroup: Message.NEWSGROUP_DEFAULT
      message_id: @id()
      boundary: crypto.pseudoRandomBytes(16).toString('hex')
      parent_msgid: @parent_id()
      content_id: @content_id()
      permalink: "https://news.ycombinator.com/item?id=#{@json_data.id}"
      from: "#{@json_data.by} <noreply@example.com>"
    }

  render: ->
    json = JSON.parse JSON.stringify(@json_data) # omglol
    json.mail = @headers()
    Mustache.render Message.TemplateGet(json.type), json

  toString: ->
    @render()

module.exports = Message
