# Binary Builder Downloader

CLI to download artifacts produced by BinaryBuilder.

![](https://user-images.githubusercontent.com/1813121/79628394-d3fee500-80fd-11ea-9b11-d37a0cc98a0a.gif)

### Install

Download the command line tool from [releases](https://github.com/kdheepak/binary-builder-downloader/releases/latest).

### Usage

**Help**

```
$ bbd --help

Usage:
  bbd {SUBCMD}  [sub-command options & parameters]
where {SUBCMD} is one of:
  help      print comprehensive or per-cmd help
  list      Get package list.
  download  Download package.

bbd {-h|--help} or with no args at all prints this message.
bbd --help-syntax gives general cligen syntax help.
Run "bbd {help SUBCMD|SUBCMD --help}" to see help for just SUBCMD.
Run "bbd help" to get *comprehensive* help.
Top-level --version also available
```

**List all available packages**

```
$ bbd list --help

list [optional-params]
Get package list.
Options:
  -h, --help                  print this cligen-erated help
  --help-syntax               advanced: prepend,plurals,..
  --version      bool  false  print version
```

**Download package**

```
$ bbd download --help

download [required&optional-params]
Download package.
Options:
  -h, --help                                   print this cligen-erated help
  --help-syntax                                advanced: prepend,plurals,..
  --version              bool    false         print version
  -p=, --package=        string  REQUIRED      set package
  -o=, --os=             string  "${hostOS}"   set os
  -a=, --arch=           string  "${hostArch}" set arch
  -c=, --cxxstring-abi=  string  "cxx03"       set cxxstring_abi
  -l=, --libc=           string  ""            set libc
```
