var gulp = require('gulp');
var Dgeni = require('dgeni');
var del = require('del');

gulp.task('clean-js-docs', function(done) {
    return del(['./doc/out/dgeni', './public/doc/out/dgeni'], done);
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

gulp.task('js-docs', gulp.series('clean-js-docs', 'dgeni-docs', function(cb) {
    cb();
}));

gulp.task('default', gulp.series('clean-js-docs', 'js-docs', function(cb) {
    cb();
}));
