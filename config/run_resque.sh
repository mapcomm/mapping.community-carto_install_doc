#!/bin/sh
# This file should be placed in /opt/cartodb/script to be called by /etc/systemd/system/cartodb-resque.service
export PATH=$PATH:/opt/rubies/ruby-2.2.3/bin
cd /opt/cartodb
RAILS_ENV=production /opt/rubies/ruby-2.2.3/bin/bundle exec /opt/cartodb/script/resque &> /var/log/carto/log/resque_log
