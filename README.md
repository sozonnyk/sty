# Sty
[![Build Status](https://travis-ci.org/sozonnyk/sty.svg?branch=master)](https://travis-ci.org/sozonnyk/sty)

<a ti   tle="Jean-Pol GRANDMONT [CC BY 3.0 (https://creativecommons.org/licenses/by/3.0)], via Wikimedia Commons" href="https://commons.wikimedia.org/wiki/File:Fourneau_St-Michel_-_Porcherie_(Forri%C3%A8res).JPG">
<img alt="Fourneau St-Michel - Porcherie (Forrières)" src="https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Fourneau_St-Michel_-_Porcherie_%28Forri%C3%A8res%29.JPG/1024px-Fourneau_St-Michel_-_Porcherie_%28Forri%C3%A8res%29.JPG"></a>

## Overview

Sty is a set of handy command line tools meant to help with day-to-day
work with AWS. Sty is working on Mac and Linux using Bash or Zsh. 

The main use case for Sty is to obtain and store temporary AWS
credentials for MFA enabled AWS users who are required to assume a role
in the different account.

Sty can also help to access EC2 instances using SSH or SSM Session. It
provides a convenient command line interface to quickly select a server
and initiate a connection.

## Installation

Sty is written in Ruby so you need to ensure it installed beforehand.
Most modern Linux and Mac versions should have Ruby pre-installed. In
any case, it is recommended to use Ruby version manager such as
[rbenv](https://github.com/rbenv/rbenv)

To install Sty run:

`gem install sty`

During installation, Sty creates its executable `/usr/local/bin/sty`.
This installation step requires sudo on Linux.

Sty also creates `.sty` directory in your home folder. This is a place
where all configuration files are located.

## Functions

- Authenticate command line to AWS account, cache and reuse credentials
- Open browser console for the current session (Mac only)
- SSH to instances (jumphost supported)
- Start SSM session to instances (require SSM plugin installed) 
- Switch command line proxy settings

## Usage

Some Sty commands manipulate environment variables for your current
session. To allow current session to be modified, you need to *source*
Sty command, i.e.: `. sty login ...`

### Authentication

To authnticate to an account, run:
 
`. sty login [fqn]`

Where *fqn* is a full account name within the config file hierarchy
separated by `/`. E.g. `ga/prod/users`. Sty will ask for an MFA token,
create session, and assume role in the other account according to the
configuration. Once authenticated, credentials will be cached as well as
exported to the current session env variables. When the same credentials
are requested again form the other session, they will be loaded from the
cache.

To logout from the current account, i.e. clean env variables and delete
cache file, run:

`. sty logout`

To get information about currently authenticated session run:

`sty info`

### Browser console (Mac only)

if your session is authenticated, you can open a browser console
directly into the current account.

To open browser console, run:

`sty console`

This will open new session in the default browser. Note, you can't
create more then one session in the same browser window. Moreover you
must logout from the current console to login to the different role or
account.

To log out from the current session in the default browser run":

`sty console -l`

You can also open browser console in the different browser. Supported
browsers are `chrome` `firefox` `safari` and `vivaldi`

To open a console in Firefox run:

`sty console -b firefox`

Some browsers support *incognito* window, which can be enabled with `-i`
switch.

### Proxy switcher

To switch a proxy for the current session, run:

`. sty proxy [name]`

Where *name* is a proxy name from proxy configuration file
`~/.sty/proxy.yaml`

To get current proxy settings run the same command without proxy name.

To turm proxy off for the current session, run:
 
`. sty proxy off`

Note that you can't use word `off` for a proxy name in the config file.

## Configuration

All config files live in `~/.sty`

## Uninstallation

`gem uninstall sty` 

Sty will ask if you want to remove `~/.sty` with all your configuration.
Be careful not to lose your keys.

## Caveats

- Credentials are stored in plain unencrypted files
- Opening of a browser console is not working on Linux

## TODO 

- [ ] Create test coverage 
- [ ] Use keychain on Mac to encrypt stored credentials
- [ ] Fix all issues on Linux
