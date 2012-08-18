# Dokuen, a Personal App Platform

Dokuen is a "personal app platform". It's the same idea as all of these PaaS and IaaS services out there, except you host it on
your own machine. Currently, Dokuen supports Mac and Ubuntu. [Here](http://bugsplat.info/2012-05-17-dokuen-a-personal-app-platform.html) is an article that explains my motivations.

Note that earlier versions of Dokuen had server-side runtime components. Starting at this version (0.1.0), those components are replaced with Foreman exports and client-side
invocations.

## Requirements

* [Nginx](http://wiki.nginx.org/Main)

## Installation

### Step 1

```
$ gem install dokuen
```

### Step 2

Install nginx using homebrew or your distro's package manager:

On OS X:
```
$ brew install nginx
```

On Ubuntu:
```
$ sudo apt-get install nginx
```

### Step 3

Add a dokuen "remote" for your target server and run `dokuen remote prepare`:

```
$ dokuen remote add subspace peter@subspace.bugsplat.info:/usr/local/var/dokuen
Added subspace to /Users/peter/.dokuen
$ dokuen remote prepare subspace
Preparing subspace for dokuen
...
$
```

The user must have sudo permissions, and ideally will have passwordless sudo. This is
not the user that applications will be running as.

## Buildpacks

Dokuen uses buildpacks, just like Heroku does. In fact, if your host system
is running Ubuntu most buildpacks will run without modifications. Add a buildpack:

```
$ dokuen buildpack add https:///github.com/heroku/heroku-buildpack-ruby
Cloning buildpack... Done
$
```

## Applications

To release an application, first you need to create it:

```
$ dokuen app create subspace notes
Created application 'notes' on remote 'subspace'
$
```

Creating an application creates some directories under the root dokuen path
and creates a user named `dokuen-<appname>`.

Now, push a release:
```
$ dokuen app push subspace notes
Creating manifest...
Pushing files...
Detecting application type... ruby detected.
Compiling...
...
Released v1
$
```
