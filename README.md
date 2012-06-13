# Dokuen, a Personal App Platform

Dokuen is a "personal app platform". It's the same idea as all of these PaaS and IaaS services out there, except you host it on
your own machine. Currently, Dokuen supports Mac and Ubuntu. [Here](http://bugsplat.info/2012-05-17-dokuen-a-personal-app-platform.html) is an article that explains my motivations.

## Requirements

* [Gitolite](https://github.com/sitaramc/gitolite)
* [Nginx](http://wiki.nginx.org/Main)


## Installation


### Step 1

```
gem install dokuen
```

### Step 2

Install nginx using homebrew or your distro's package manager:

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
$ sudo dokuen setup .
```

This will ask you a few questions, set up a few directories, and install a few useful commands. It'll also show you some things you need to do. Crucially, you'll need to modify your gitolite config and install it.

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
* `run_command <command>`
* `shutdown`
* `restart`

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


## How it works

When you run `ssh git@<your_host> dokuen create --application=foo`, Dokuen creates a few directories in it's install directory, setting things up for app deployments. In particular, it creates this structure:

```
foo/
    releases/    # timestamped code pushes
    env/         # environment variables. FILENAME => file contents
    logs/        # log files, one per process
    build/       # cache directory for build side-effects like gems
```

When you run `git push dokuen master`, the following series of events happens:

* If the target git repo does not exist, gitolite creates it
* git runs the `pre-receive` hook, which invokes `/path/to/dokuen/install/bin/dokuen`, which is a wrapper around dokuen with the correct config file set
* runs `git archive <git repo> <sha1 of new master branch> > <tmpdir>`
* invokes `mason` on the tmpdir, building the application into a timestamped subdirectory of `releases`
* creates a symlink `current` that points at the new timestamped directory
* creates a symlink `previous` that points at the previous value of `current`
* spins up the configured number of processes as set using `dokuen scale`
* writes out a new nginx configuration and restarts nginx
* shuts down the previous processes

When Dokuen "spins up" a process, it forks the main process, creates a `Dokuen::Wrapper` instance and calls `run!` on it. The wrapper's job is to immediately daemonize and run the command line in the `Procfile` for the given named process, capture logging info, restarting the process if it dies, and forwarding signals to it as appropriate. It writes it's own pid as well as the port it was given at fork-time into a pidfile at `current/.dokuen/dokuen.<appname>.<process_name>.<index>.pid`.

## Rails

Unfortunately the stock Heroku buildpacks install a vendored node.js compiled for the Heroku platform, which happens to be linux. This doesn't work for Mac, which means you have to use a slightly patched version. This one works with a homebrew-installed node.js: https://github.com/peterkeen/heroku-buildpack-ruby

## License

MIT

## Contact and Development

Fork and send me a pull request. If you'd like to talk about Dokuen there's `#dokuen` on `irc.freenode.net`, as well as a [mailing list](https://groups.google.com/forum/#!forum/dokuen). 
