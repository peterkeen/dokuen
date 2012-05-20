# Dokuen, a Personal App Platform

Dokuen is a "personal app platform". It's the same idea as all of these PaaS and IaaS services out there, except you host it on your own machine. It's specifically for hosting multiple 12-factor applications on one Mac.

## Requirements

* [Gitolite](https://github.com/sitaramc/gitolite)
* [Nginx](http://wiki.nginx.org/Main)

## Installation


### Step 1

```
gem install dokuen
```

### Step 2

Install nginx using homebrew.

### Step 3

Create a `git` user and install gitolite according to [package directions](http://sitaramc.github.com/gitolite/qi.html). You'll be making changes to the config later, but for now you should be able to create a new repository and push to it.

### Step 4

Run this:

```
$ sudo dokuen setup
```

This will ask you a few questions, set up a few directories, and install a few useful commands. It'll also show you some things you need to do.

## Creating an App

```
$ ssh git@<your_host> dokuen create <name>
Creating new application named <name>
Remote: git@<your_host>:<name>.git

$ git remote add dokuen git@<your_host>:<name>.git
```

### Add some environment variables

```
$ ssh git@<your_host> dokuen config <name> set -V BUILDPACK_URL="https://github.com/heroku/heroku-buildpack-ruby.git" PORT=12345 DOKUEN_SCALE="web=1"
```

### Deploy
```
$ git push dokuen master
<deploy transcript>
```

### Check it out!
```
$ open http://<your_host>:12345/
```

## Available "app" Sub-commands

* create <name>
* config <name>
  * set <key>=<value> ...
  * delete <key> ...
* restart_app <name>
* scale <name> <type>=<num>
* buildpacks
* install_buildpack
* remove_buildpack

## DNS Setup

I have my home router set up to forward ports 80 and 443 to my mac mini, and I have a dynamic DNS system set up with a wildcard CNAME Unfortunately this setup is hard to automate so Dokuen doesn't manage any of it for you.

What it does do is set up Nginx server configs for you that you can choose to use. If you want to use them, put this at the bottom of the `http` section of `nginx.conf`:

```
include /usr/local/var/dokuen/nginx/*.conf;
```

Then, force a restart of your app:

```
$ ssh git@<your_host> dokuen restart_app <name>
```

## Rails

Unfortunately the stock Heroku buildpacks install a vendored node.js compiled for the Heroku platform, which happens to be linux. This doesn't work for Mac, which means you have to use a slightly patched version. This one works with a homebrew-installed node.js: https://github.com/peterkeen/heroku-buildpack-ruby

