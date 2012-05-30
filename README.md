# Dokuen, a Personal App Platform

Dokuen is a "personal app platform". It's the same idea as all of these PaaS and IaaS services out there, except you host it on your own machine. It's specifically for hosting multiple 12-factor applications on one Mac. [Here](http://bugsplat.info/2012-05-17-dokuen-a-personal-app-platform.html) is an article that explains my motivations.

## Requirements

* [Gitolite](https://github.com/sitaramc/gitolite)
* [Nginx](http://wiki.nginx.org/Main)

## Installation


### Step 1

WARNING: At the moment Dokuen needs a custom version of Mason. A patch has been accepted but as
of now (2012-05-19) there hasn't been a release with this patch. So, install mason:

```
$ git clone https://github.com/peterkeen/mason
$ cd mason
$ gem build mason.gemspec
$ gem install mason-0.0.11.gem
```

Then, install dokuen:
```
gem install dokuen
```

### Step 2

Install nginx using homebrew:

```
$ brew install nginx
```

### Step 3

Create a `git` user and install gitolite according to [package directions](http://sitaramc.github.com/gitolite/qi.html). You'll be making changes to the config later, but for now you should be able to create a new repository and push to it.

### Step 4

Run this:

```
$ sudo mkdir -p /usr/local/var/dokuen
$ cd /usr/local/var/dokuen
$ sudo dokuen setup
```

This will ask you a few questions, set up a few directories, and install a few useful commands. It'll also show you some things you need to do.

## Creating an App

```
$ ssh git@<your_host> dokuen create --application=<name>
git@<your_host>:<name>.git

$ git remote add dokuen git@<your_host>:<name>.git
```

### Add some environment variables

```
$ ssh git@<your_host> dokuen config_set -V BUILDPACK_URL="https://github.com/heroku/heroku-buildpack-ruby.git" DOKUEN_SCALE="web=1" --application=<name>
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

* `create`
* `config_set <key>=<value> ...`
* `config_delete <key> ...`
* `scale <type>=<num>...`
* `buildpacks`
* `install_buildpack <url>`
* `remove_buildpack <name>`

## DNS Setup

I have my home router set up to forward ports 80 and 443 to my mac mini, and I have a dynamic DNS system set up with a wildcard CNAME Unfortunately this setup is hard to automate so Dokuen doesn't manage any of it for you.

What it does do is set up Nginx server configs for you that you can choose to use. If you want to use them, put this at the bottom of the `http` section of `nginx.conf`:

```
include /usr/local/var/dokuen/nginx/*.conf;
```

Then, force a restart of your app:

```
$ ssh git@<your_host> dokuen scale web=0 --application=<name>
$ ssh git@<your_host> dokuen scale web=1 --application=<name>
```

## Rails

Unfortunately the stock Heroku buildpacks install a vendored node.js compiled for the Heroku platform, which happens to be linux. This doesn't work for Mac, which means you have to use a slightly patched version. This one works with a homebrew-installed node.js: https://github.com/peterkeen/heroku-buildpack-ruby


