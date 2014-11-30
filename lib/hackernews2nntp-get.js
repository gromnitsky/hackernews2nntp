// Generated by CoffeeScript 1.8.0
(function() {
  var Crawler, Q, conf, errx, fs, ids_get, ids_last, ids_top100, meta, path, program, request;

  fs = require('fs');

  path = require('path');

  Crawler = require('./crawler');

  meta = require('../package.json');

  program = require('commander');

  Q = require('q');

  request = require('request');

  conf = {
    url_pattern: 'https://hacker-news.firebaseio.com/v0/item/%d.json'
  };

  errx = function(msg) {
    console.error("" + (path.basename(process.argv[1])) + " error: " + msg);
    return process.exit(1);
  };

  ids_get = function(mode, spec) {
    if (mode === 'exact') {
      return Q.fcall(function() {
        var id;
        id = parseInt(spec) || 0;
        if (id < 1) {
          throw new Error("mode exact: invalid id " + spec);
        }
        return [id];
      });
    }
    if (mode === 'last') {
      return ids_last(spec);
    }
    if (mode === 'top100') {
      return ids_top100();
    } else {
      return Q.fcall(function() {
        throw new Error("invalid mode " + conf.mode);
      });
    }
  };

  ids_last = function(spec) {
    var deferred, num, opt;
    deferred = Q.defer();
    num = parseInt(spec) || 0;
    if (num < 1) {
      deferred.reject(new Error("mode last: invalid number: " + spec));
      return deferred.promise;
    }
    opt = {
      url: 'https://hacker-news.firebaseio.com/v0/maxitem.json?print=pretty'
    };
    request.get(opt, function(err, res, body) {
      var idx, maxitem, result;
      if (err) {
        deferred.reject(new Error("mode last: " + err.message));
        return;
      }
      if (res.statusCode === 200) {
        maxitem = parseInt(body) || 0;
        if (maxitem < 1) {
          deferred.reject(new Error("mode last: maxitem <= 0"));
          return;
        }
        result = maxitem - num;
        if (result < 1) {
          return deferred.reject(new Error("mode last: " + maxitem + "-" + num + "=" + result));
        } else {
          return deferred.resolve((function() {
            var _i, _results;
            _results = [];
            for (idx = _i = result; result <= maxitem ? _i <= maxitem : _i >= maxitem; idx = result <= maxitem ? ++_i : --_i) {
              _results.push(idx);
            }
            return _results;
          })());
        }
      } else {
        return deferred.reject(new Error("mode last: HTTP " + res.statusCode));
      }
    });
    return deferred.promise;
  };

  ids_top100 = function() {
    var deferred, opt;
    deferred = Q.defer();
    opt = {
      url: 'https://hacker-news.firebaseio.com/v0/topstories.json'
    };
    request.get(opt, function(err, res, body) {
      var arr;
      if (err) {
        deferred.reject(new Error("mode top100: " + err.message));
        return;
      }
      if (res.statusCode === 200) {
        try {
          arr = JSON.parse(body);
          if (!(arr instanceof Array)) {
            throw new Error('array is required');
          }
        } catch (_error) {
          err = _error;
          deferred.reject(new Error("mode top100: invalid json: " + err.message));
          return;
        }
        return deferred.resolve(arr);
      } else {
        return deferred.reject(new Error("mode top100: HTTP " + res.statusCode));
      }
    });
    return deferred.promise;
  };

  exports.main = function() {
    program.version(meta.version).usage("[options] mode [spec] \n  Available modes: top100, last <number>, exact <id>").option('-v, --verbose', 'Print HTTP status on stderr').option('-u, --url-pattern <string>', "Debug. Only for 'exact' mode. Default: " + conf.url_pattern, conf.url_pattern).option('--nokids', "Debug").parse(process.argv);
    if (program.args.length < 1) {
      program.outputHelp();
      process.exit(1);
    }
    return ids_get(program.args[0], program.args[1]).then(function(ids) {
      var crawler, n, _i, _len, _results;
      crawler = new Crawler(program.urlPattern, ids.length);
      if (!program.verbose) {
        crawler.log = function() {};
      }
      if (program.nokids) {
        crawler.look4kids = false;
      }
      crawler.event.on('finish', function(stat) {
        return crawler.log("\n" + stat);
      });
      crawler.event.on('body', function(body) {
        return console.log(body);
      });
      _results = [];
      for (_i = 0, _len = ids.length; _i < _len; _i++) {
        n = ids[_i];
        _results.push(crawler.get_item(n)["catch"](function(err) {
          if (program.verbose) {
            return console.error(err);
          }
        }).done());
      }
      return _results;
    })["catch"](function(err) {
      return errx(err.message);
    }).done();
  };

}).call(this);