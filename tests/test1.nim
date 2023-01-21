import unittest

import
  std / [os],
  todoApppkg / [submodule, dbtables]

test "correct welcome":
  check getWelcomeMessage() == "Hello, World!"

var testDir = currentSourcePath().parentDir

test "create db file":
  while testDir.dirExists:
    testDir = testDir / "tmp"
  testDir.createDir
  testDir.setCurrentDir
  let
    dbName = "todo.db"
    db = dbName.openDb
  db.createTables
  check dbName.fileExists

test "remove db file":
  testDir.removeDir
  check not testDir.dirExists
