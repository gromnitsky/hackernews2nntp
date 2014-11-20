fs = require 'fs'
path = require 'path'

crawler = require './crawler'
meta = JSON.parse fs.readFileSync(path.join __dirname, 'meta.json').toString()

program = require 'commander'

exports.main = ->

  program
    .version meta.version
    .option '--verbose', 'Print HTTP status on stderr'
    .parse process.argv

  console.log program
