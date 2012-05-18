# Dokuen, a Personal App Platform

Dokuen is a "personal app platform". It's the same idea as all of these PaaS and IaaS services out there, except you host it on your own machine. It's specifically for hosting multiple 12-factor applications on one machine.

## Requirements

* [Gitolite](https://github.com/sitaramc/gitolite)
* [Nginx](http://wiki.nginx.org/Main)
* [daemontools](http://cr.yp.to/daemontools.html)

## Installation


### Step 1

```
gem install dokuen
```

### Step 2

Install daemontools and nginx using homebrew.

### Step 3

Create a `git` user and install gitolite according to package directions. You'll be making changes to the config later, but for now you should be able to create a new repository and push to it.

### Step 4

Run this:

```
$ sudo dokuen setup
```

This will ask you a few questions, set up a few directories, and install a few useful commands.

### Step 5

Edit your `.gitolite.rc` file and add this to the `COMMANDS` section:

```
'app' => 1
```

### Step 6

Edit your sudoers file and add this line:

```
git	ALL=NOPASSWD: /usr/local/bin/dokuen
```

## Creating an App

```
$ ssh git@<your_host> app create <name>
Creating new application named <name>
Remote: git@<your_host>:<name>.git

$ git remote add dokuen git@<your_host>:<name>.git
```

### Add some environment variables

```
$ ssh git@<your_host> app config <name> add BUILDPACK_URL="https://github.com/heroku/heroku-buildpack-ruby.git" BASE_PORT=12345 FOREMAN="web=1"
```

### Deploy
```
$ git push deploy master
<deploy transcript>
```

### Check it out!
```
$ open http://<your_host>:12345/
```

## Available "app" Sub-commands

* create <name>
* config <name>
  * add <key>=<value> ...
  * delete <key> ...
* restart <name>
* scale <name> <type>=<num>
* deploy <name>

## DNS Concerns

I have my home router set up to forward ports 80 and 443 to my mac mini, and I have a dynamic DNS system set up with CNAMEs for each of my Dokuen-managed projects where the CNAME matches the name of the app. Unfortunately this setup is hard to automate way so Dokuen doesn't manage any of it for you.

What it does do is set up Nginx server configs for you that you can choose to use. If you want to use them, put this at the bottom of the `http` section of `nginx.conf`:

```
include /usr/local/var/dokuen/nginx/*.conf;
```

Then, force a redeploy for the apps you've already deployed:

```
$ ssh git@<your_host> app deploy <name>
```

## Rails

Unfortunately the stock Heroku buildpacks install a vendored node.js compiled for the Heroku platform, which happens to be linux. This doesn't work for Mac, which means you have to use a slightly patched version. This one works with a homebrew-installed node.js: https://github.com/peterkeen/heroku-buildpack-ruby

