This document provides a step-by-step introduction to the process of installing the full stack for Carto open-source onto a self-hosted server running CentOS 7. We've tried to provide enough narration along the way to make this guide useful to anyone with a cursory level of knowledge of linux and web servers and a high level of persistence. This guide was authored by Jeremy Kidwell at the University of Birmingham, but is the product of a collaboration with a range of persons who helped along the way, see the footnotes for credits and enjoy!

# 1. Provisioning

CartoDB can use a range of resources. For our purposes, which involve installing an instance of CartoDB on a virtual server hosted at the University of Birmingham for the [Mapping Community project](http://mapping.community) we plan to host a range of POI datasets, shapefiles, and demographic data pertaining to community groups in the UK, with the eventual goal of hosting data for the whole of Europe and whoever wants to join in the fun \(Austrailiasia anyone?\).

We set up a local PostgreSQL server with PostGIS extensions in order to test the size of these datasets and projected a maximum use for year 1 of this server of 500GB. For a whole host of best-practice reasons, we've provisioned this setup with a web server and PostGIS server hosted separately \(but on the same LAN\). We will run a parallel set of servers in a development platform which will mirror the production setup.

# 2. Installation

### A Few Notes on Converting "CartoDB Ubuntu" to Centos...

The CartoDB installation process is well-documented in the [official documentation](http://cartodb.readthedocs.io/en/latest/install.html), however this process is explicitly linked to Ubuntu 12.04 x64. Though relatively similar to Ubuntu, CentOS has a different package manager and dependencies will be handled in a slightly different way, so the purpose of this documentation is to indicate departures from that official documentation for our platform.

The basic components included in CartoDB include the following:

* PostgreSQL \(note, as of May 2017 CartoDB requires **PostgreSQL 9.5.x** and **PostGIS 2.2.x** - check the official docs at [http://cartodb.readthedocs.io/en/latest/components/postgresql.html](http://cartodb.readthedocs.io/en/latest/components/postgresql.html) to see if this has changed\)
* Redis \(note, CartoDB requires **redis 3.x** version - check [here](http://cartodb.readthedocs.io/en/latest/components/redis.html) to see if this has changed
* NodeJS 6.9 \(the Carto platform is on the way towards transitioning from the former requirement of 0.10 towards 6.x the latter of which we've installed with and tested here)\ and npm 3.10.9 \(same as before, so upgrading from official carto doc recommendation of 2.14.16)\
* Ruby \(recommended Ruby 2.2.3\)
* [GEOS](http://trac.osgeo.org/geos) 3.5.0, [GDAL](http://www.gdal.org/) 1.11 (though note that CartoDB uses ogr2ogr2 version 2.1.3 in parallel for some features), [Mapnik](http://mapnik.org/), ImageMagick
* unp, zip, [JSON-C](http://oss.metaparadigm.com/json-c), [PROJ4](http://trac.osgeo.org/proj)
* CartoDB SQL API \(found at: git://github.com/CartoDB/Windshaft-cartodb.git\)
* CartoDB MAPS API \(found at git://github.com/CartoDB/Windshaft-cartodb.git\)
* Editor \(found at [https://github.com/CartoDB/cartodb.git](https://github.com/CartoDB/cartodb.git\)

Packages are not directly equivalent in the CentOS package manager "[yum](https://en.wikipedia.org/wiki/Yellowdog_Updater,_Modified)" to Ubuntu's "[apt-get](https://en.wikipedia.org/wiki/Advanced_Packaging_Tool)", so we need to deviate sightly from those packages named in the Ubuntu-based CartoDB install. Best practice is to first check for an easy equivalent which uses the same name in yum. If this doesn't exist, you have two options. You can look for an error message in your compile process and use the command `yum whatprovides "/[filename here]*` or you can have a look at the actual contents of the Ubuntu package specified using their website here: [http://packages.ubuntu.com](http://packages.ubuntu.com%29%29 and try to find a package that bundles the same components %28or individually!%29 using yum. You can read a bit more about [how to install software on CentOS here]%28https://www.centos.org/forums/viewtopic.php?f=12&t=871) and then use `yum search [pattern to match in package name]`. It is also worth noting that the CartoDB Ubuntu install guide includes several instances where the guide needs packages which are beyond the standard Ubuntu repositories as well. In this case, they provide access to a Carto-specific Ubuntu PPA, PPA being an acronym for Personal Package Archive and essentially just a bundle of precompiled software known to be compatible with a specific system type. You can view the contents of the [CartoDB/GIS PPA by clicking here](https://launchpad.net/%7Ecartodb/+archive/ubuntu/gis). If you're running into compatibility issues or are wondering which version of a component is getting installed, check out the PPA which provides a very specific list!

Here's an example of how we've done this:

One of the first install commands in Ubuntu is to install the following using apt-get:

```bash
sudo apt-get install autoconf binutils-doc bison build-essential flex
```

A quick search [using the command line](https://www.centos.org/docs/5/html/yum/sn-searching-packages.html) reveals that there are some obvious yum equivalents:

`sudo yum install autoconf bison flex`

This is fine, and we should install these straight-away. But with the above example, we can see that "binutils-doc" and "build-essential" don't have exact name equivalents in yum. With some careful sleuthing we've found that the proper packages are[^5]:

```bash
sudo yum install binutils
sudo yum install gcc gcc-c++ make openssl-devel tcl
```

You won't need to go through this process here as we've already identified all the equivalent packages in this guide (or recommended installation from source code in some cases), but in future cases, there may be additional dependencies that need to be resolved, so hopefully enterprising users will be able to conduct appropriate reconnaissance.

Two other things that are worth noting about the translation from Ubuntu to CentOS/RHEL - paths are specified differently, and often CentOS is more conservative about not passing paths to the shell, this means that you may get file not found errors even when you know that you've already installed the proper package. We address this in a few ways below, but usually good to confirm first when you hit an erorr that it isn't just a matter of a path missing, especially if you're using `sudo`. The other matter to be aware of is that CentOS is tremendously conservative in terms of adopting new frameworks, so we'll just install straight from source below in some cases rather than bothering with the process of trying to get the code installed via a package.

That's it for now let's get started...

## 2.1 PostgresSQL Server ##

> Note, for our purposes, this guide makes use of two virtual servers . CartoDB can be run on a single server \(which is how the Ubuntu instructions go\), so this is just our approach here. We begin by configuring our second virtual server which will host PostgreSQL. This order is necessary because the database is needed when we do the configuration on the Web Server:

### a. Set System Locale[^4]

```bash
localedef -c -f UTF-8 -i en_GB en_GB.UTF-8
export LC_ALL=en_GB.UTF-8
```

### b. Install Basic Requirements:

Begin by installing some of the basic required components of your server:

```bash
sudo yum install autoconf bison flex binutils
sudo yum install gcc gcc-c++ make openssl-devel tcl
```

In contrast to Ubuntu, the main CentOS repository lacks many server packages, so it is typical to use the EPEL \([Extra Packages for Enterprise Linux](https://fedoraproject.org/wiki/EPEL/FAQ#howtouse%29\) repository and "voila" some of the packages noted below, including "redis" and "postgis" become available:

```bash
sudo rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
```

> Note: these versions change, so you may want to browse to [http://dl.fedoraproject.org/pub/epel/7/x86\_64/e/](http://dl.fedoraproject.org/pub/epel/7/x86_64/e/) to see what the latest version is if this doesn't work.

### c. Install Git

You will need git commands in order to handle some repositories and install some dependencies:

```bash
sudo yum install git
```

*Note: in the Ubuntu guide, there is a series of packages listed under "APT Tools", in case you're wondering, we've integrated these elsewhere already in this guide, so no need to worry!*

### d. PostgreSQL ###


#### Get postgresql 9.5 repository installed

> Note: The default in CentOS at the time this guide was put together was 9.2, so you'll want to be sure that you specify the proper repository. We've also altered all the below to be sure they are specific to 9.5.

Here's how you add the additional repository for postgresql 9.5:

```bash
sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-3.noarch.rpm
sudo yum update
```

#### Install client packages:

```bash
sudo yum install postgresql95 postgresql95-odbc PyGreSQL
```

> Note: we were just fine skipping these ubuntu packages from the official Carto install doc: libpq5  libpq-dev  postgresql-client-common \(many bits are already dependencies or specified in other ways above\)

#### Install server packages[^6]:

```bash
sudo yum install postgresql95-server postgresql95-contrib postgresql95-devel postgresql95-plpython
```

Now we need to initialize our database:

```
sudo /usr/pgsql-9.5/bin/postgresql95-setup initdb
```

Start the service:

```
sudo systemctl start postgresql-9.5
```

Enable the service to run on startup:

```
sudo systemctl enable postgresql-9.5.service
```

Modify the pg\_hba.conf file \(this is sort of like the firewall configuration for the database server\) to specify whether it should expect connections from outside, which is quite likely when working with PostGIS. We like to use nano as our text editor: `sudo nano /var/lib/pgsql/9.5/data/pg_hba.conf`

The contexts of your pg\_hba.conf should be something like the following \(with much of the documentation/comments from the actual file excluded here\), you should probably make it the following \(for now\):

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only, modified from stock to "trust" as per CartoDB docs
local   all             all                                     trust
# this addition from CartoDB docs
local   all             postgres                                trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# Allow Web Server connection:
host    all             Postgres        _webserver IP address_  trust
# IPv6 local connections:
host    all             all             ::1/128                 ident
# Allow replication connections from localhost, by a user with the
# replication privilege.
#local   replication     postgres                                peer
#host    replication     postgres        127.0.0.1/32            ident
#host    replication     postgres        ::1/128                 ident
```

Restart server for changes to take effect:

```
sudo systemctl restart postgresql-9.5
```

Now create your Postgres users:

```
sudo createuser publicuser --no-createrole --no-createdb --no-superuser -U postgres
sudo createuser tileuser --no-createrole --no-createdb --no-superuser -U postgres
```

**Install the CartoDB postgresql extension**.

This extension contains functions that are used by different parts of the CartoDB platform, included the Editor and the SQL and Maps API \(as below\).

```
cd ~/
git clone https://github.com/CartoDB/cartodb-postgresql.git
cd cartodb-postgresql/
```

> Note: for the next line, have a look at [https://github.com/CartoDB/cartodb-postgresql/tags](https://github.com/CartoDB/cartodb-postgresql/tags) to see what the latest tag is, and then substitute in the line below - this will detach your clone from the branch which may continue to develop! For this install, we've used 0.18.5. It is also worth noting that environment variables aren't passed by default in some linux distributions, including CentOS, so we need to explicitly pass the path variable or the command will fail.[^1]

```
git checkout <LATEST cartodb-postgresql tag>
export PATH=/usr/pgsql-9.5/bin:$PATH
sudo env "PATH=$PATH" make all install
```

### e. GIS dependencies

Install the following dependencies:

```
sudo yum install proj proj-devel json-c json-c-devel python-simplejson geos geos-devel gdal gdal-devel gdal-libs gdal-devel 
sudo yum install libjpeg-turbo libjpeg-turbo-devel ImageMagick-devel giflib-devel pango-devel
```

### f. PostGIS

Install PostGIS

```
sudo yum install libxml2-devel
sudo yum install postgis2_95 postgis2_95-devel libxml2-devel
```

Initialize template postgis database. We create a template database in postgresql that will contain the postgis extension. This way, every time CartoDB creates a new user database it just clones this template database

```
sudo createdb -T template0 -O postgres -U postgres -E UTF8 template_postgis
sudo createlang plpgsql -U postgres -d template_postgis
psql -U postgres template_postgis -c 'CREATE EXTENSION postgis;CREATE EXTENSION postgis_topology;'
sudo ldconfig
```

Run an installcheck to verify the database has been installed properly

```
sudo PGUSER=postgres make installcheck # to run tests
```

> Note: check [https://github.com/cartodb/cartodb-postgresql](https://github.com/cartodb/cartodb-postgresql) for further reference

Restart PostgreSQL after all this process

```
sudo systemctl restart postgresql-9.5
```

If you are working with a 2 server configuration, you may also want to edit the postgresql.conf file to tell the server to listen to hosts beyond "localhost".

```
sudo nano  /var/lib/pgsql/9.5/data/postgresql.conf
```

Edit the line beginning with `# listen_addresses = 'localhost' # what IP address(es) to listen on;`

At this point your PostgresSQL server installation should be all done, now let's move on to the web server installation:

## 2.2 Web Server ##

Login to Cartodb Web server ("Server01").

### a. Set System Locale[^4]

```bash
localedef -c -f UTF-8 -i en_GB en_GB.UTF-8
export LC_ALL=en_GB.UTF-8
```

### b. Install Basic Requirements:

```bash
sudo yum install autoconf bison flex binutils
sudo yum install gcc gcc-c++ make openssl-devel tcl
```

### c. Install Git

You will need git commands in order to handle some repositories and install some dependencies:

```bash
sudo yum install git
```

### d. PostgreSQL

Even though we're not running PostgreSQL on this server, the web server will require many of the same libraries, so we'll go through a similar process to what we began above for this server here. Add the additional repository for postgresql 9.5:

```bash
sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-3.noarch.rpm
sudo yum update
```

Install following packages:

```bash
sudo yum install postgresql95 postgresql95-odbc PyGreSQL postgresql95-devel postgresql95-plpython
```

### e. GIS dependencies

Install the following dependencies:

```
sudo yum install proj proj-devel json-c json-c-devel python-simplejson geos geos-devel gdal gdal-devel gdal-libs gdal-devel 
sudo yum install libjpeg-turbo libjpeg-turbo-devel ImageMagick-devel giflib-devel pango-devel
```

### f. PostGIS

Install PostGIS

```
sudo yum install libxml2-devel
sudo yum install postgis2_95 postgis2_95-devel libxml2-devel
```

### g. Redis

Now that we've finished the basics, and replicated essential postgresql components, we'll move on to installation of the web server and the Carto stack.

Centos is too conservative to provide redis 3.x in a package, so we must install from source. At the time of this writing, 3.2.8 was the latest "stable" release, but it's [worth clicking here to check first](https://redis.io/download) in case things have moved along. Get and install redis:

```
cd ~/
wget http://download.redis.io/releases/redis-3.2.8.tar.gz
tar xzf redis-3.2.8.tar.gz
cd redis-3.2.8
make
```

> *Note: if you follow the documentation on redis and attempt a "make test", make sure you first check for running "redis" processes and kill any that are still running you can find these processes using the following command:* `ps -ef|grep redis` then just run the command: `kill <process id number>`

Now install redis as a production server:

```
sudo make install
cd utils
chmod +x install_server.sh
sudo ./install_server.sh
```

> Note, the dialogue which will ensue when you run install \_server.sh, will ask you to specify the path to CLI executable. This should be "/usr/local/bin/redis-server"

Check the status of your redis server:

```
service redis_6379 status
```

If you want to allow outside access to the redis server \(which is not necessary, and I can't imagine why one might do so!\), you should definitely set a password for redis. Open the file for editing using: `nano /etc/redis/6379.conf` then look for the line beginning with `# requirepass foobared` and replace "foobared" with a strong alternative. Finish by restarting the redis server with `service redis_6379 restart`

### h. NodeJS[^7]

As above, it is easier just to install Node.js from source so you can be sure you have the right version installed. On your server, use wget and paste the link that you copied in order to download the archive file:

> Note: at the time of writing, we will need nodeJS v6.9.2 to work with Windshaft-cartodb.

```
cd ~/
wget http://nodejs.org/dist/v6.9.2/node-v6.9.2.tar.gz
```

Extract the archive and move into the new directory by typing:

```
tar xzvf node-v* && cd node-v*
```

Configure and compile the software:

```
./configure
make
```

The compilation will take a wee while. When it is finished, you can install the software onto your system by typing:

```
sudo make install
```

To check that the installation was successful, you can ask Node and NPM \(the node package manager\) to display its version number:

```
node --version
npm -v
```

### i. Create "Carto" User With Sudo Privilege ###

Now let's create a user account which the carto services can run under so that they aren't using your linux user account.

```
sudo adduser carto
```

Use the passwd command to update the new user's password (choose a strong option here, as you've already done for redis above. Do write it down, don't use the same password you've used for reds.):

```
sudo passwd carto
```

Use the usermod command to add the user to the wheel group.

```
sudo usermod -aG wheel carto
```

You're going to need to login to this new user account so that file permissions and ownership are set properly when you install the CartoDB stack in a moment.

```
su carto
```

### j. Ruby

Download ruby-install. Ruby-install is a script that makes ruby install easier. It’s not needed to get ruby installed but it helps in the process.

```bash
cd ~/
wget -O ruby-install-0.5.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.5.0.tar.gz
tar -xzvf ruby-install-0.5.0.tar.gz
cd ruby-install-0.5.0/
sudo make install
```

Install some ruby dependencies

```
sudo yum install readline-devel
```

Install ruby 2.2.3. CartoDB has been deeply tested with Ruby 2.2.

```
sudo env "PATH=$PATH" ruby-install ruby 2.2.3
```

Ruby-install will leave everything in /opt/rubies/ruby-2.2.3/bin. To be able to run ruby and gem later on, you’ll need to add the Ruby 2.2.3 bin folder to your PATH variable. It’s also a good idea to include this line in your bashrc so that it gets loaded on restart

```
export PATH=$PATH:/opt/rubies/ruby-2.2.3/bin
```

Install bundler. Bundler is an app used to manage ruby dependencies. It is needed by CartoDB’s editor

```
sudo env "PATH=$PATH" gem install bundler
```

Install compass. It will be needed later on by CartoDB’s editor

```
sudo env "PATH=$PATH" gem install compass
```

### k. GDAL 2.1.3

The Centos repository only provides GDAL v1.11.4 so we will need to install the latest GDAL v2.1.3 from source. As we've noted above, Carto uses two versions of GDAL in parallel, in order to borrow some features that were reintroduced in GDAL 2.x. Our installation here will 

```
cd ~/
wget http://download.osgeo.org/gdal/2.1.3/gdal-2.1.3.tar.gz
tar -xzf gdal-2.1.3.tar.gz
cd gdal-2.1.3
./configure --with-geos=yes --with-pg=/usr/pgsql-9.5/bin/pg_config --prefix=/usr
make
sudo make install
```

> Note: the two flags included above for 'configure' are very important. Make sure that GEOS support shows "yes" and that the install script is able to find pg_config and PostgresQL.

### l. GCC Library

The system wide GCC library from Centos 7 is incompatible with CatoDB MAP API. Therefore we will need to manually compile the library and make it available for the later use. The minimum version of GCC is v5.1.0. 

```
cd ~/
wget http://gnu.uberglobalmirror.com/gcc/gcc-5.1.0/gcc-5.1.0.tar.bz2
tar -xjf gcc-5.1.0.tar.bz2
cd gcc-5.1.0
./configure
make
```

> Note: the compile will take a while as there are huge number of objects to run through.

At this point, we do not need to "make install" as we only need to copy the library file (libstdc++.so.6.0.21) to the system /lib64 folder

```
sudo cp ./prev-x86_64-unknown-linux-gnu/libstdc++-v3/src/.libs/libstdc++.so.6.0.21 /lib64/
```
Update current symbolic link of the library
```
sudo rm /lib64/libstdc++.so.6
sudo ln -s /lib64/libstdc++.so.6.0.21 /lib64/libstdc++.so.6
```

### m. CartoDB Components ###

#### Editor

Download the editor code:

```
cd /opt
git clone --recursive https://github.com/CartoDB/cartodb.git
cd cartodb
```

Install pip:

```
sudo wget  -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
sudo python /tmp/get-pip.py
```

Install a necessary package for python dependencies:

```
sudo yum install python-devel
```

Install dependencies

```bash
sudo yum install ImageMagick unzip patch gdal-devel
export PATH=$PATH:/usr/pgsql-9.5/bin/
RAILS_ENV=production bundle install --deployment --without development test
npm install
sudo env "PATH=$PATH" pip install --no-use-wheel -r python_requirements.txt --global-option=build_ext --global-option="-I/usr/include/gdal"
```

> Reminder: environment name is used above. Also note that "bundle install" above will fail if "/usr/pgsql-9.5/bin" is not included in your $PATH statement. Best practices on CentOS suggest that your path should be modified using a script in /etc/profile.d.

Add the grunt command to the PATH:

```
export PATH=$PATH:$PWD/node_modules/grunt-cli/bin
```

Install all necessary gems:

```
bundle install
```

Precompile assets. Note that the last parameter is the environment used to run the application. It must be the same used in the Maps and SQL APIs

```bash
cp config/grunt_development.json config/grunt_production.json
ulimit -n 2560
bundle exec grunt --environment production
```

> Reminder: environment name here, but note that we're using the template for development to make our "grunt\_production.json". You can omit this first line above if working with a "development" environment as there is \(obviously\) already a config file for grunt\_development.

Create configuration files:

```
cp config/app_config.yml.sample config/app_config.yml
cp config/database.yml.sample config/database.yml
```

> Note: modify database.yml to include details of your database \(in our case using the details of Server02\) if you're not using localhost.

Initialise the metadata database:

```
RAILS_ENV=production bundle exec rake db:create
RAILS_ENV=production bundle exec rake db:migrate
```

> Reminder: above should be modified if using "development" environment.

Now modify configuration files for the carto web application:

```
nano /opt/cartodb/config/app_config.yml
```

Change the line starting with: `session_domain:     '.localhost.lan'` to: `session_domain:     'carto.mapping.community'`

Change the line starting with: `subdomainless_urls: false` to: `subdomainless_urls: true`

Change the line starting with: `vizjson_cache_domains: ['.localhost.lan']` to `#  vizjson_cache_domains: ['.localhost.lan']` (it should be commented out)

(JK Note: next line unsure - may need to revert this to a side loaded configuration, cf. original Readme.md from May, content under "Now finally edit the hosts file to include `localhost.lan` and whatever your server URL will be")

Change the line starting with: `binary:           'which ogr2ogr2.1'` to: `binary:           'which ogr2ogr'`

Change the line starting with: `account_host:       'localhost.lan:3000'` to: `account_host:       'carto.mapping.community'`

Make the following changes to the `sql_api` section of this file as below: 
```
  sql_api:
    private:
      protocol:   'https'
      domain:     'carto.mapping.community'
      endpoint:   '/api/v1/sql'
      port:       9090
    public:
      protocol:   'https'
      domain:     'carto.mapping.community'
      endpoint:   '/api/v2/sql'
      port:       9090
```

Save the app_config.yml file and then edit the hosts file to include `localhost.lan` and whatever your server URL will be:

```
sudo nano /etc/hosts
```

Add the following line:
```
127.0.0.1   localhost.lan carto.mapping.community
```

Create /etc/carto so we can edit all the config files in here
```
sudo mkdir /etc/carto
cd /etc/carto
ln -s /opt/cartodb/config
```

Create /var/log/carto so we can put all the logs files in here
```
sudo mkdir /var/log/carto
```

### n. CartoDB APIs

All the hard work above has paid off, as you have a working server environment that will provide the basis for an installation of the Carto platform:

#### SQL API:

Download API:

> Note, here and below we need to copy all the core cartodb files into the system-wise web server paths so that they aren't being served out of our home directory. We're going with /opt for our files here ([to see why, read here](http://serverfault.com/questions/96416/should-i-install-linux-applications-in-var-or-opt)):

```
cd /opt
sudo git clone git://github.com/CartoDB/CartoDB-SQL-API.git
sudo chown -R carto CartoDB-SQL-API
cd /opt/CartoDB-SQL-API
git checkout master
```

Install npm dependencies

```
npm install
```

Create your configuration files from the templates provided in the config directory. Note, the name of the filename of the configuration must be the same than the environment you are going to use to start the service.

> Note: departing from the standard Carto instruction set, we've specified the environment as production, because we are running two parallel environments \(yep, 4 virtual servers\). Do make a note of the fact that the name of the environment will crop up increasingly often further below, so best to do a word search for "production" and substitute as necessary if you want to run a "development" environment.

```
cp config/environments/production.js.example config/environments/production.js
```

Note: As you'll already know, our project is hosted at carto.mapping.community. You'll want to substitute every instance of "mapping.community" in the prescribed configuration changes here and below for your own DNS name otherwise the server will definitely not work.

We need to modify the SQL-API configuration file so that the server will work with our DNS name:

```
nano /opt/CartoDB-SQL-API/config/environments/production.js
```

Change the line `module.exports.node_host    = '127.0.0.1';` to `module.exports.node_host    = '';`

Change `module.exports.user_from_host` to `'^(.*)\\carto\\.mapping\\.community$'`

> Note: hostname to change above!

Change `module.exports.db_host` to `PostgresSQL server IP address`

Change `module.exports.db_port` to `5432`

Change `module.exports.ogr2ogrCommand` to `'/usr/bin/ogr2ogr'`

Change `allowedHosts` to `['carto.mapping.community']`

> Note: hostname to change above!

Now, try to start the service to confirm that it is installed correctly (note, again the second parameter is always the environment if the service. Remember to use the same you used in the configuration).

```
node app.js production
```

> Reminder: see note a few lines above re: "production" here which is "development" in carto documentation.

#### MAPS API:

Download the API:

```
cd /opt
sudo git clone git://github.com/CartoDB/Windshaft-cartodb.git
sudo chown -R carto Windshaft-cartodb
cd Windshaft-cartodb
git checkout master
```

Install npm dependencies:

```
npm install
```

Create configuration. The name of the filename of the configuration must be the same than the environment you are going to use to start the service. Let’s assume it’s production

> Reminder: environnment name below \(as noted above\)!

```
cp config/environments/production.js.example config/environments/production.js
```

You need to make some crucial modifications to the windshaft configuration file:

> Reminder: specific DNS settings below!

```
nano /opt/Windshaft-cartodb/config/environments/production.js
```

Change the line `,host: '127.0.0.1'` to `,host: ''`

Change the line `,user_from_host: '^(.*)\\.cartodb\\.com$'` to `,user_from_host: 'carto\\.mapping\\.community'`

Change postgres host to `PostgresSQL server IP address`

Change postgres port to `5432`

Change endpoint url to `'http://carto.mapping.community:8080/api/v2/sql/job'`

Change hostHeaderTemplate to `hostHeaderTemplate: '{{=it.username}}.carto.mapping.community'`

Change cache_basedir to `cache_basedir: '/opt/cartodb/tile_assets/'`

Save the changes you've made above to the windshaft configuration file and proceed. 

Now, create the cache_basedir folder if it doesn't exist: 

```bash
mkdir /opt/cartodb/tile_assets/
```

Start the service to check if it is installed correctly. The second parameter is always the environment of the service. Remember to use the same you used in the configuration.

```bash
node app.js production
```

> Reminder environnment name above \(as noted above\)! 

If this step fails saying log folder not found, you may need to manually create it, e.g. `mkdir /opt/Windshaft-cartodb/logs`


### o. Install Apache and Passenger ###

Now we need a web server which we'll use with passenger to connect to the Carto rails server. NGINX is what Carto uses for their production servers, but we've gone with Apache for the sake of convenience. There are some indications that performance is better for high-volume installations using NGINX, so that's the main reason to defer to the alternative.

Because Carto is fundamentally a rails web server, we will need to use Passenger to connect the rails web server to Apache. By default, web applications running behind rails use non-standard ports. We will use the passenger web proxy along with the apache web server to redirect traffic to default web server ports 80/443. 

For this section, you may want to brief the very helpful guides located on the [Passenger website](https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/nginx/oss/rubygems_norvm/install_passenger.html) \(for a non-rvm setup into NGINX on CentOS\) and [Passenger App install guide](https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/nginx/oss/rubygems_norvm/deploy_app.html) (starting from step 3).

Install Apache:

```
sudo yum install httpd
```

Install Passenger:

```
sudo gem install passenger
```

Set SELinux to permissive:
```
sudo setenforce 0
```

Run the Passenger Apache module installer:

```
sudo yum install libcurl-devel httpd-devel
sudo passenger-install-apache2-module
```

### p. Generate self-signed SSL certificate

Because we're using https, we need to assign some secure certificates to our web server. Note, you should strongly resist any suggestions that you need to pay for https certificates. There is absolutely no reason to pay a Certificate authority for your certificates when perfectly secure and respected services like letsencrypt.com exist! We'll start with self-signed certificates and then go on to install letsencrypt certificates which will be automatically renewed using certbot below:

```
sudo mkdir /etc/httpd/certs/ 
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/httpd/certs/OurKey.key
 -out /etc/httpd/certs/OurCert.crt
```

### q. Configure Apache/Passenger with virtualhost and reverse proxy

Add a new config file `passenger.conf`

```
cd /etc/httpd/conf.d/
sudo nano passenger.conf
```

Paste the following into your new `passenger.conf` file and save:

>Note: be sure you change DNS below to your own hostname

```
   LoadModule passenger_module /opt/rubies/ruby-2.2.3/lib/ruby/gems/2.2.0/gems/passenger-5.1.3/buildout/apache2/mod_passenger.so
   <IfModule mod_passenger.c>
     PassengerRoot /opt/rubies/ruby-2.2.3/lib/ruby/gems/2.2.0/gems/passenger-5.1.3
     PassengerDefaultRuby /opt/rubies/ruby-2.2.3/bin/ruby
   </IfModule>

<VirtualHost *:80>
    ServerName carto.mapping.community

    # Tell Apache and Passenger where your app's 'public' directory is
    DocumentRoot /opt/cartodb/public
    RailsEnv production
    SetEnv RAILS_LOG_BASE_PATH = /var/log/carto
    SetEnv RAILS_CONFIG_BASE_PATH = /etc/carto
    # Relax Apache security settings
    <Directory /opt/cartodb/public>
      AllowOverride all
      Allow from all
      Options -MultiViews
      # Uncomment this if you're on Apache >= 2.4:
      Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName carto.mapping.community
    ServerAlias carto.mapping.community
    # !!! Be sure to point DocumentRoot to 'public'!
    DocumentRoot /opt/cartodb/public
    RailsEnv production
    # This will let CartoDB write all logs to /var/log/carto
    SetEnv RAILS_LOG_BASE_PATH = /var/log/carto
    # This will change CartoDB to read all configs from /etc/carto
    SetEnv RAILS_CONFIG_BASE_PATH = /etc/carto
    PassengerSpawnMethod direct

    SSLEngine on

    SSLCertificateFile /etc/httpd/certs/OurCert.crt
    SSLCertificateKeyFile /etc/httpd/certs/OurKey.key

    <Directory /opt/cartodb/public>
        # This relaxes Apache security settings.
        AllowOverride all
        Allow from all
        Require all granted
        # MultiViews must be turned off.
        Options -MultiViews
    </Directory>
</VirtualHost>
```

We'll need to create a separate configuration file to enable reverse proxy for the Carto SQL_API:

```
nano sqlapi.conf
```

Paste the following into your new `sqlapi.conf` file and save:

>Note: be sure you change DNS below to your own hostname

```
Listen 9090

NameVirtualHost *:9090

<VirtualHost *:9090>
    SSLProxyEngine On 
    ServerName carto.mapping.community

    SSLEngine on

    SSLCertificateFile /etc/httpd/certs/OurCert.crt
    SSLCertificateKeyFile /etc/httpd/certs/OurKey.key

    # this preserves original header and domain
    ProxyPreserveHost On

    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/

</VirtualHost>
```

### r. Install Certbot to Use letsencrypt SSL Certificate (Optional) ###

The EFF has set up free hosting for secure certificates with a large federation of top-tier web-hosting firms via [http://letsencrypt.org]. You can read more on their website about the service. We'll be using the apache instance of "certbot" to keep our ssl certificates fresh:

```
sudo yum -y install yum-utils
sudo yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
sudo yum install python-certbot-apache
```

Once Certbot is installed, run it and let it replace the existing self-signed certificate we created above:

```
certbot --apache
```

#### **Start the Server \(to Test Out Functionality\)** ####

We're nearly done now, so it's time to start up all the services and see how they work!

First, start the `redis-server` that allows access to the SQL and Maps APIs:

Note, because we've run `sudo ./install_server.sh` as part of the redis install above, there's no need to run `redis-server &` here as is specified in the carto install documentation. Worth double checking, but if you've followed this guide redis should already be running.

Start the two import services using node:

```
cd /opt/CartoDB-SQL-API && node app.js production &
cd /opt/Windshaft-cartodb && node app.js production &
```

Start Apache/Passenger

```
sudo service httpd start
```

> Reminder: environment name above!

In a different process/console start the resque process (this serves map tiles and responds to requests)

```
export PATH=$PATH:/opt/rubies/ruby-2.2.3/bin
RAILS_ENV=production bundle exec ./script/resque
```

> Reminder: environment name above!

Test that your server is up:

```
curl localhost
```

This should return:
<html><body>You are being <a href="https://[yourURL]/login">redirected</a>.</body></html>


## Notes

[^1]: For more on this fix I've used here, see [http://unix.stackexchange.com/questions/83191/how-to-make-sudo-preserve-path](http://unix.stackexchange.com/questions/83191/how-to-make-sudo-preserve-path).

[^2]: Credit goes to the following for the above step: [https://docs.npmjs.com/getting-started/installing-node](https://docs.npmjs.com/getting-started/installing-node)

[^3]: Credit for the service files which I've hacked only lightly to produce what is in this guide goes to Javier Torres Niño &lt;jtorres@carto.com&gt;\). I've drawn these from his arch-linux distribution which can be found here: [https://aur.archlinux.org/packages/?O=0&SeB=n&K=carto&outdated=&SB=n&SO=a&PP=50&do\_Search=Go](https://aur.archlinux.org/packages/?O=0&SeB=n&K=carto&outdated=&SB=n&SO=a&PP=50&do_Search=Go). See also [http://cartodb.readthedocs.io/en/latest/configuration.html\#separate-folders](http://cartodb.readthedocs.io/en/latest/configuration.html#separate-folders). Other documentation I've consulted for this section includes: [http://serverfault.com/questions/616430/why-isnt-systemctl-starting-redis-server-on-centos-7](http://serverfault.com/questions/616430/why-isnt-systemctl-starting-redis-server-on-centos-7) and [https://scottlinux.com/2014/12/08/how-to-create-a-systemd-service-in-linux-centos-7/](https://scottlinux.com/2014/12/08/how-to-create-a-systemd-service-in-linux-centos-7/).

[^4]: Thanks to [http://serverfault.com/a/275411](http://serverfault.com/a/275411) for this answer. Though note that we've modified this for Britain. :\)

[^5]: Thanks to [http://unix.stackexchange.com/a/63068/94615](http://unix.stackexchange.com/a/63068/94615) for help with the section below.

[^6]: Note: some of the details below have been drawn \(with gratitude\) from [http://www.unixmen.com/postgresql-9-4-released-install-centos-7](http://www.unixmen.com/postgresql-9-4-released-install-centos-7)

[^7]: Thanks to [https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-a-centos-7-server](https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-a-centos-7-server) for most of the below details for installing node.js on centos.
