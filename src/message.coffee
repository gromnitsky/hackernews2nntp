fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
os = require 'os'
{spawn} = require 'child_process'

Mustache = require 'mustache'
json_schema = require('jjv')()
Q = require 'q'
mimelib = require 'mimelib'

class Message

  @NEWSGROUP_DEFAULT = 'news.ycombinator'
  @SCHEMA = JSON.parse fs.readFileSync(path.join __dirname, 'schema.json').toString()

  @TemplateGet = (name) ->
    fs.readFileSync(path.resolve __dirname, '..', 'template', "#{name}.txt").toString()

  constructor: (@json_data, @parts = []) ->
    # sync validation
    for idx in @parts.concat(@json_data)
      err = json_schema.validate Message.SCHEMA, idx
      throw new Error('invalid json input: ' + JSON.stringify err) if err

  id: ->
    "<#{@json_data.id}@news.ycombinator.com>"

  parent_id: ->
    return '' unless @json_data.parent
    "<#{@json_data.parent}@news.ycombinator.com>"

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
      global: "<#{r}>"
      text: "<text_#{r}>"
      html: "<html_#{r}>"
    }

  headers: ->
    {
      newsgroup: Message.NEWSGROUP_DEFAULT
      message_id: @id()
      boundary: crypto.pseudoRandomBytes(16).toString('hex')
      parent_msgid: @parent_id()
      content_id: @content_id()
      permalink: "https://news.ycombinator.com/item?id=#{@json_data.id}"
      from: "#{@json_data.by} <#{@json_data.by}@example.com>"
      date: @date()
      path: os.hostname()
      profile: "https://news.ycombinator.com/user?id=#{@json_data.by}"
      subject: if !@json_data.title then '' else mimelib.encodeMimeWord @json_data.title
    }

  # return a promise
  @HTML_filter: (html) ->
    deferred = Q.defer()
    text = ''
    stderr = ''

    if !html? || html == ""
      deferred.resolve text
      return deferred.promise

    w3m = spawn 'w3m', ['-T', 'text/html', '-dump', '-I', 'UTF-8',
      '-O', 'UTF-8', '-cols', '72', '-no-graph']

    w3m.on 'error', (err) ->
      deferred.reject(new Error "w3m exec failed: #{err.message}")

    w3m.stdout.on 'data', (data) -> text += data
    w3m.stderr.on 'data', (data) -> stderr += data

    w3m.on 'close', (code) ->
      if code == 0
        deferred.resolve text
      else
        deferred.reject(new Error "w3m failed w/ exit code #{code}\nw3m stderr: #{stderr}")

    w3m.stdin.write html
    w3m.stdin.end()

    deferred.promise

  polparts_collect: ->
    deferred = Q.defer()
    if @parts.length == 0
      deferred.resolve []
      return deferred.promise

    parts = []
    idx = 0      # we cannot use idx value from 'for item,idx in @parts'
    for item in @parts
      Message.HTML_filter(item.text)
      .then (r) =>
        ++idx
        parts.push r.trim()
        deferred.resolve parts if idx == @parts.length

    deferred.promise

  # return a promise
  render: (_tdd_hash) ->
    json = JSON.parse JSON.stringify(@json_data) # omglol
    json.mail = @headers()

    if @json_data.type == 'poll'
      @polparts_collect()
      .then (r) ->
        json.mail.polparts = r
        _tdd_hash.polparts = r if _tdd_hash
        Mustache.render Message.TemplateGet(json.type), json
    else
      Message.HTML_filter @json_data.text
      .then (r) ->
        json.mail.body_text = r.trim()
        _tdd_hash.body_text = r.trim() if _tdd_hash
        Mustache.render Message.TemplateGet(json.type), json

  toString: ->
    @render()

module.exports = Message
