var gulp = require('gulp');
var Dgeni = require('dgeni');
var del = require('del');
var runSequence = require('run-sequence');

gulp.task('js-docs', function(cb) {
	      runSequence('clean-js-docs', [ 'dgeni-docs' ], cb);
	  });

gulp.task('dgeni-docs', function() {
  try {
    var dgeni = new Dgeni([require('./doc/dgeni/conf')]);
    return dgeni.generate();
  } catch(x) {
    console.log(x.stack);
    throw x;
  }
});

gulp.task('clean-js-docs', function(done) {
	      return del(['./doc/out/dgeni', './public/doc/out/dgeni'], done);
	  });

gulp.task('default', function(cb) {
	      runSequence('clean-js-docs', [ 'js-docs' ], cb);
});
