# Sty
[![Build Status](https://travis-ci.org/sozonnyk/sty.svg?branch=master)](https://travis-ci.org/sozonnyk/sty)

<a ti   tle="Jean-Pol GRANDMONT [CC BY 3.0 (https://creativecommons.org/licenses/by/3.0)], via Wikimedia Commons" href="https://commons.wikimedia.org/wiki/File:Fourneau_St-Michel_-_Porcherie_(Forri%C3%A8res).JPG">
<img alt="Fourneau St-Michel - Porcherie (Forrières)" src="https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Fourneau_St-Michel_-_Porcherie_%28Forri%C3%A8res%29.JPG/1024px-Fourneau_St-Michel_-_Porcherie_%28Forri%C3%A8res%29.JPG"></a>

## Overview

Sty is a set of handy command line tools meant to help with day to day
work with AWS. Sty is working on Mac and Linux using Bash or Zsh. Sty is
written in Ruby so you need to have it installed beforehand. It is
recommended to use Ruby version manager such as
[!Rbenv](https://github.com/rbenv/rbenv)

## Installation
`gem install sty`

During installation, Sty creates it executable `/usr/local/bin/sty`.
This installation step require sudo on Linux. 

Sty also creates `.sty` directory in your home folder. This is a place
where all configuration fileas are located.

## Functions

- Authenticate to AWS account, cache credentials
- Open browser console for the current session (Mac only)
- SSH to instances, incluging using jumphost
- Start SSM session to instances (require SSM plugin installed) 
- Switch command line proxy settings

## Configuration

All config files live in `~/.sty`

## TODO 

- [ ] Create test coverage 
- [ ] Use keychain on Mac to encrypt stored credentials
- [ ] Fix all issues on Linux
