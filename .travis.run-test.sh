#! /bin/sh

JRUBY_OPTS=-J-Xmx1024m bundle exec rake test:${TEST_SUITE}
