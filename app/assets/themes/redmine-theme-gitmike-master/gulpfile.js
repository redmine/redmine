'use strict';

var gulp = require('gulp');
var gulpSass = require('gulp-sass');
var gulpAutoPrefixer = require('gulp-autoprefixer');
var browserSync = require('browser-sync').create();

gulpSass.compiler = require('node-sass');

function sass(env) {
  var nodeSassOption = {
    outputStyle: 'expanded',
    sourceComments: env === 'development'
  };
  // sourceComments
  return gulp.src('./sass/*.scss')
    .pipe(gulpSass(nodeSassOption).on('error', gulpSass.logError))
    .pipe(gulpAutoPrefixer({
      cascade: true
    }))
    .pipe(gulp.dest('stylesheets'))
    .pipe(browserSync.stream())
    ;
}

gulp.task('sass:prod', function () {
  return sass('production');
});

gulp.task('sass:dev', function () {
  return sass('development');
});

gulp.task('browser-sync', function (done) {
  browserSync.init({
    port: 3001,
    proxy: '127.0.0.1:3000'
  });
  done();
});

gulp.task('debug', gulp.series('sass:dev', 'browser-sync', function () {
  gulp.watch('sass/**/*.scss', gulp.task('sass:dev'));
}));

gulp.task('default', gulp.series('sass:prod'));
