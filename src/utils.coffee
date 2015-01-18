path = require 'path'

exports.isNum = (n) -> !isNaN(parseFloat n) && isFinite n

exports.isStr = (s) -> toString.apply(s) == '[object String]'

exports.randrange = (min, max) -> Math.floor Math.random()*(max-min+1)+min

exports.warnx = (msg) ->
  console.error "#{path.basename process.argv[1]} warning: #{msg}"

exports.errx = (msg) ->
  console.error "#{path.basename process.argv[1]} error: #{msg}"
  process.exit 1

exports.hash_size = (hash) ->
  (Object.keys hash).length
