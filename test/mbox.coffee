# Return a string like
#
# From dhouston@example.com Wed Apr 04 19:16:40 2007
exports.prefix = (json_data) ->
  d = new Date(json_data.time * 1000)
  days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
    'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

  [
    "From #{json_data.by}@example.com"
    days[d.getUTCDay()]
    months[d.getUTCMonth()]
    ('0'+d.getUTCDate()).slice(-2)
    [
      d.getUTCHours()
      d.getUTCMinutes()
      d.getUTCSeconds()
    ].join ':'
    d.getUTCFullYear()
  ].join ' '
