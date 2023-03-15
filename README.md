# 💎 Redmine 💎 (the 🐍 python way)

## Install a Redmine and run it as a (`snake`)service

> There was a person so vexed and crossed,  
> Whose Redmine install was quite lost,   
> And with my guidance, plans were made,  
> Now Redmine's running at no extra cost!  

### let's get some packages first

```bash
root@pi:~# apt-get install ruby ruby-dev 
```

### let's get a guy for it
```bash
root@pi:~$ adduser -m -s /bin/bash --disabled-password --home /opt/redmine redmine
```
### prepare the database

```bash
root@pi:~$ psql -U postgres

CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD 'redmine' NOINHERIT VALID UNTIL 'infinity';
CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;
```

### impersonate the guy
```bash
root@pi:~# su - redmine

```
### let's make the virtual thing
```bash
redmine@pi:~ $ virtualenv RM
```
> created virtual environment CPython3.9.2.final.0-32 in 364ms
>   creator CPython3Posix(dest=/opt/redmine/RM, clear=False, no_vcs_ignore=False, global=False)
>   seeder FromAppData(download=False, pip=bundle, setuptools=bundle, >wheel=bundle, via=copy, app_data_dir=/opt/redmine/.local/share/virtualenv)
>     added seed packages: pip==20.3.4, pkg_resources==0.0.0, setuptools==44.1.1, wheel==0.34.2
>   activators BashActivator,CShellActivator,FishActivator,PowerShellActivator,PythonActivator,XonshActivator

## activate the virtual thing

```bash
redmine@pi:~ $ source RM/bin/activate
```
## dig the gold

```bash
(RM) redmine@pi:~ $ wget https://github.com/redmine/redmine/archive/refs/tags/5.0.5.tar.gz
```
## unpack it

```bash
(RM) redmine@pi:~ $ tar -xvzf 5.0.5.tar.gz -C /opt/redmine/RM --strip-components=1
(RM) redmine@pi:~ $ rm 5.0.5.tar.gz
(RM) redmine@pi:~ $ cd RM
(RM) redmine@pi:~/RM $ cd config/
(RM) redmine@pi:~/RM/config $ cp database.yml.example database.yml
(RM) redmine@pi:~/RM/config $ mcedit database.yml
```

```bash
# cat /opt/redmine/RM/config/database.yml
production:  
    adapter: postgresql  
    database: redmine  
    host: localhost   
    username: redmine  
    password: "redmine"   
    encoding: utf8  
```

## adding some variables to the neighbarhooh

```bash
(RM) redmine@pi:~/RM/config $ cd ..
(RM) redmine@pi:~/RM echo 'export PATH=$HOME/.gem/bin:$PATH' >> ~/.bashrc
(RM) redmine@pi:~/RM echo 'export GEM_HOME=~/.gem' >> ~/.bashrc
(RM) redmine@pi:~/RM export GEM_HOME=~/.gem

```

> There once was a guy named Bundler,  
> Whose skills installing Redmine made him a wonder.  
> He knew all the commands,  
> And helped with such demands,  
> That his reputation grew louder than thunder.  

```bash
(RM) redmine@pi:~/RM gem install bundler
```
> Fetching bundler-2.4.8.gem  
> Successfully installed bundler-2.4.8  
> Parsing documentation for bundler-2.4.8  
> Installing ri documentation for bundler-2.4.8  
> Done installing documentation for bundler after 0 seconds  
> 1 gem installed  
```
(RM) redmine@pi:~/RM $ bundle config set --local path 'vendor/bundle'
(RM) redmine@pi:~/RM $ bundle config set --local without 'development test'
(RM) redmine@pi:~/RM $ bundle install
```

<pre><small>
Fetching gem metadata from https://rubygems.org/.........  
Resolving dependencies...  
Fetching rake 13.0.6  
Installing rake 13.0.6  
Fetching minitest 5.18.0  
Fetching zeitwerk 2.6.7  
Fetching concurrent-ruby 1.2.2  
Fetching builder 3.2.4  
Installing zeitwerk 2.6.7  
Installing builder 3.2.4  
Installing minitest 5.18.0  
Fetching erubi 1.12.0  
Installing concurrent-ruby 1.2.2  
Fetching mini_portile2 2.8.1  
Fetching racc 1.6.2  
Installing erubi 1.12.0  
Installing mini_portile2 2.8.1  
Fetching crass 1.0.6  
Installing racc 1.6.2 with native extensions  
Fetching rack 2.2.6.4  
Installing crass 1.0.6  
Fetching nio4r 2.5.8  
Fetching websocket-extensions 0.1.5  
Installing rack 2.2.6.4  
Installing nio4r 2.5.8 with native extensions  
Installing websocket-extensions 0.1.5  
Fetching marcel 1.0.2  
Fetching mini_mime 1.1.2  
Installing marcel 1.0.2  
Installing mini_mime 1.1.2  
Fetching method_source 1.0.0  
Fetching thor 1.2.1  
Installing method_source 1.0.0  
Fetching public_suffix 5.0.1  
Installing thor 1.2.1  
Using bundler 2.4.8  
Fetching chunky_png 1.4.0  
Installing public_suffix 5.0.1  
Fetching commonmarker 0.23.8  
Installing chunky_png 1.4.0  
Installing commonmarker 0.23.8 with native extensions  
Fetching csv 3.2.6  
Installing csv 3.2.6  
Fetching digest 3.1.1  
Installing digest 3.1.1 with native extensions  
Fetching htmlentities 4.3.4  
Installing htmlentities 4.3.4  
Fetching mini_magick 4.11.0  
Installing mini_magick 4.11.0  
Fetching timeout 0.3.2  
Installing timeout 0.3.2  
Fetching strscan 3.0.6  
Installing strscan 3.0.6 with native extensions  
Fetching net-ldap 0.17.1  
Installing net-ldap 0.17.1  
Fetching pg 1.2.3  
Installing pg 1.2.3 with native extensions  
Fetching rbpdf-font 1.19.1  
Installing rbpdf-font 1.19.1  
Fetching redcarpet 3.5.1  
Installing redcarpet 3.5.1 with native extensions  
Fetching rotp 6.2.2  
Installing rotp 6.2.2  
Fetching rouge 3.28.0  
Installing rouge 3.28.0  
Fetching rqrcode_core 1.2.0  
Installing rqrcode_core 1.2.0  
Fetching rubyzip 2.3.2  
Installing rubyzip 2.3.2  
Fetching i18n 1.10.0  
Installing i18n 1.10.0  
Fetching tzinfo 2.0.6  
Installing tzinfo 2.0.6  
Fetching websocket-driver 0.7.5  
Installing websocket-driver 0.7.5 with native extensions  
Fetching rack-test 2.1.0  
Installing rack-test 2.1.0  
Fetching sprockets 4.2.0  
Installing sprockets 4.2.0  
Fetching request_store 1.5.1  
Installing request_store 1.5.1  
Fetching mail 2.7.1  
Installing mail 2.7.1  
Fetching addressable 2.8.1  
Installing addressable 2.8.1  
Fetching nokogiri 1.13.10  
Installing nokogiri 1.13.10 with native extensions  
Fetching net-protocol 0.2.1  
Installing net-protocol 0.2.1  
Fetching rbpdf 1.21.0  
Installing rbpdf 1.21.0  
Fetching rqrcode 2.1.2  
Installing rqrcode 2.1.2  
Fetching activesupport 6.1.7.2  
Installing activesupport 6.1.7.2  
Fetching css_parser 1.14.0  
Installing css_parser 1.14.0  
Fetching net-imap 0.2.3  
Installing net-imap 0.2.3  
Fetching net-pop 0.1.2  
Installing net-pop 0.1.2  
Fetching net-smtp 0.3.3  
Installing net-smtp 0.3.3  
Fetching globalid 1.1.0  
Installing globalid 1.1.0  
Fetching activemodel 6.1.7.2  
Installing activemodel 6.1.7.2  
Fetching activejob 6.1.7.2  
Installing activejob 6.1.7.2  
Fetching activerecord 6.1.7.2  
Installing activerecord 6.1.7.2  
Fetching loofah 2.19.1  
Fetching rails-dom-testing 2.0.3  
Fetching roadie 5.1.0  
Fetching html-pipeline 2.13.2  
Installing loofah 2.19.1  
Installing rails-dom-testing 2.0.3  
Installing html-pipeline 2.13.2  
Installing roadie 5.1.0  
Fetching sanitize 6.0.1  
Fetching rails-html-sanitizer 1.5.0  
Fetching deckar01-task_list 2.3.2  
Installing rails-html-sanitizer 1.5.0  
Installing sanitize 6.0.1  
Installing deckar01-task_list 2.3.2  
Fetching actionview 6.1.7.2  
Installing actionview 6.1.7.2  
Fetching actionpack 6.1.7.2  
Installing actionpack 6.1.7.2  
Fetching activestorage 6.1.7.2  
Fetching actioncable 6.1.7.2  
Fetching actionmailer 6.1.7.2  
Fetching railties 6.1.7.2  
Installing actionmailer 6.1.7.2  
Installing actioncable 6.1.7.2  
Installing activestorage 6.1.7.2  
Fetching sprockets-rails 3.4.2  
Installing railties 6.1.7.2  
Installing sprockets-rails 3.4.2  
Fetching actionmailbox 6.1.7.2  
Fetching actiontext 6.1.7.2  
Installing actionmailbox 6.1.7.2  
Installing actiontext 6.1.7.2  
Fetching actionpack-xml_parser 2.0.1  
Fetching rails 6.1.7.2  
Fetching roadie-rails 3.0.0  
Installing roadie-rails 3.0.0  
Installing rails 6.1.7.2  
Installing actionpack-xml_parser 2.0.1  
Bundle complete! 42 Gemfile dependencies, 74 gems now installed.  
Gems in the groups 'development' and 'test' were not installed.  
Bundled gems are installed into `./vendor/bundle`  
Post-install message from html-pipeline:  
-------------------------------------------------  
Thank you for installing html-pipeline!  
You must bundle Filter gem dependencies.  
See html-pipeline README.md for more details.  
https://github.com/jch/html-pipeline#dependencies  
-------------------------------------------------  
Post-install message from rubyzip:  
RubyZip 3.0 is coming!  
**********************  
  
The public API of some Rubyzip classes has been modernized to use named  
parameters for optional arguments. Please check your usage of the  
following classes:  
  * `Zip::File`  
  * `Zip::Entry`  
  * `Zip::InputStream`  
  * `Zip::OutputStream`  
  
Please ensure that your Gemfiles and .gemspecs are suitably restrictive  
to avoid an unexpected breakage when 3.0 is released (e.g. ~2.3.0).  
See https://github.com/rubyzip/rubyzip for details. The Changelog also  
lists other enhancements and bugfixes that have been implemented since  
version 2.3.0.  
</small></pre>

## Next, generate a secret token with the following command:

```bash 
(RM) redmine@pi:~/RM $ bundle exec rake generate_secret_token
```
## preparing the database for to serve the snake

```bash
(RM) redmine@pi:~/RM $ PGUSER=redmine PGPASSWORD=redmine RAILS_ENV=production bundle exec rake db:migrate
# [... a lot of info  ...]
(RM) redmine@pi:~/RM $ PGUSER=redmine PGPASSWORD=redmine RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data
```
> Default configuration data loaded.

```bash
(RM) redmine@pi:~/RM $ for i in tmp tmp/pdf public/plugin_assets; do [ -d $i ] || mkdir -p $i; done
(RM) redmine@pi:~/RM $ chown -R redmine:redmine files log tmp public/plugin_assets
(RM) redmine@pi:~/RM $ chmod -R 755 /opt/redmine/RM/
(RM) redmine@pi:~/RM $ cd
(RM) redmine@pi:~ $ gem install rack thin
```

> Fetching rack-3.0.6.1.gem  
> Successfully installed rack-3.0.6.1  
> Parsing documentation for rack-3.0.6.1  
> Installing ri documentation for rack-3.0.6.1  
> Done installing documentation for rack after 40 seconds  
> Fetching thin-1.8.1.gem  
> Fetching eventmachine-1.2.7.gem  
> Fetching daemons-1.4.1.gem  
> Building native extensions. This could take a while...  
> Successfully installed eventmachine-1.2.7  
> Successfully installed daemons-1.4.1  
> Building native extensions. This could take a while...  
> Successfully installed thin-1.8.1  
> Parsing documentation for eventmachine-1.2.7  
> Installing ri documentation for eventmachine-1.2.7  
> Parsing documentation for daemons-1.4.1  
> Installing ri documentation for daemons-1.4.1  
> Parsing documentation for thin-1.8.1  
> Installing ri documentation for thin-1.8.1  
> Done installing documentation for eventmachine, daemons, thin after 19 seconds  
> 4 gems installed  

```bash
(RM) redmine@pi:~/RM/public $ mcedit /opt/redmine/RM/public/config.ru
```

```bash 
# cat /opt/redmine/RM/public/config.ru
 require ::File.expand_path('../config/environment',  __FILE__)  
 run Rack::Adapter::Rails.new  
```





```bash
root@pi:~# mcedit /lib/systemd/system/redmine.service

```
```bash
# cat /lib/systemd/system/redmine.service
[Unit]
Description=cdn.zp1.net as a service (cdn)
After=network.target remote-fs.target nss-lookup.target
;Name=cdn-zp1-net

[Service]
;Type=forking
User=cdn
Group=users
WorkingDirectory=/home/cdn/cdn.zp1.net
ExecStart=rackup -DE production -o 192.168.178.6 -p 2080
Restart=always

[Install]
WantedBy=multi-user.target
```

## finally enabling and starting the service
```
root@pi:~# systemctl status redmine.service
? redmine.service - redmine as a service (cdn)
     Loaded: loaded (/lib/systemd/system/redmine.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
     
root@pi:~# systemctl enable redmine.service
Created symlink /etc/systemd/system/multi-user.target.wants/redmine.service ? /lib/systemd/system/redmine.service.

root@pi:~# systemctl status redmine.service
? redmine.service - redmine as a service (cdn)
     Loaded: loaded (/lib/systemd/system/redmine.service; enabled; vendor preset: enabled)
     Active: inactive (dead)
     
root@pi:~# systemctl start redmine.service

root@pi:~# systemctl status redmine.service
? redmine.service - redmine as a service (cdn)
     Loaded: loaded (/lib/systemd/system/redmine.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2023-03-15 04:00:11 CET; 2s ago
   Main PID: 31848 (rackup)
      Tasks: 1 (limit: 4915)
        CPU: 2.545s
     CGroup: /system.slice/redmine.service
             mq31848 /usr/bin/ruby2.7 /usr/local/bin/rackup -DE production -o 192.168.178.6 -p 2080
```
