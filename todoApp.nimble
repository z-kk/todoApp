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
  exec "nimble build"
  exec "nimble ex"

import std / os
task ex, "run without build":
  withDir binDir:
    exec "." / bin[0]


# Before

before build:
  let versionFile = srcDir / bin[0] & "pkg" / "version.nim"
  versionFile.parentDir.mkDir
  versionFile.writeFile("const Version* = \"$1\"\n" % version)


# After

after build:
  let versionFile = srcDir / bin[0] & "pkg" / "version.nim"
  versionFile.writeFile("const Version* = \"\"\n")
