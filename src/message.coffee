fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
os = require 'os'
{spawn} = require 'child_process'

Mustache = require 'mustache'
json_schema = require('jjv')()
Q = require 'q'

class Message

  @NEWSGROUP_DEFAULT = 'news.ycombinator'

  @TemplateGet = (name) ->
    fs.readFileSync(path.resolve __dirname, '..', 'template', "#{name}.txt").toString()

  @SCHEMA = JSON.parse fs.readFileSync(path.join __dirname, 'schema.json').toString()

  constructor: (@json_data) ->
    # sync validation
    err = json_schema.validate Message.SCHEMA, @json_data
    throw new Error('invalid json input: ' + JSON.stringify err) if err

  id: ->
    "#{@json_data.id}@news.ycombinator.com"

  parent_id: ->
    return '' unless @json_data.parent
    "#{@json_data.parent}@news.ycombinator.com"

  # return date in rfc2822 format
  date: ->
    # I assume @json_data.time comes in UTC
    d = new Date(@json_data.time * 1000)
    d.toUTCString()

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
      date: @date()
    }

  # return a promise
  html_filter: ->
    deferred = Q.defer()
    html = ''
    stderr = ''

    if (@json_data.type != 'comment') && (@json_data.type != 'pollopt')
      deferred.resolve html
      return deferred.promise

    w3m = spawn 'w3m', ['-T', 'text/html', '-dump', '-I', 'UTF-8',
      '-O', 'UTF-8', '-cols', '72', '-no-graph']

    w3m.on 'error', (err) ->
      deferred.reject(new Error "w3m exec failed: #{err.message}")

    w3m.stdout.on 'data', (data) -> html += data
    w3m.stderr.on 'data', (data) -> stderr += data

    w3m.on 'close', (code) ->
      if code == 0
        deferred.resolve html
      else
        deferred.reject(new Error "w3m failed w/ exit code #{code}\nw3m stderr: #{stderr}")

    w3m.stdin.write @json_data.text
    w3m.stdin.end()

    deferred.promise

  # return a promise
  render: ->
    json = JSON.parse JSON.stringify(@json_data) # omglol
    json.mail = @headers()

    @html_filter()
    .then (r) ->
      json.mail.body_text = r.trim()
      Mustache.render Message.TemplateGet(json.type), json

  toString: ->
    @render()

module.exports = Message
