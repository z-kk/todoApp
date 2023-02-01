# Package

version       = "0.1.0"
author        = "z-kk"
description   = "TODO application"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["todoApp"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.6.0"
requires "docopt"
requires "cliSeqSelector"


# Tasks

import std / strutils
task r, "build and run":
  exec "nimble build -d:Version=$1" % version
  exec "nimble ex"

import std / os
task ex, "run without build":
  withDir binDir:
    exec "." / bin[0]
