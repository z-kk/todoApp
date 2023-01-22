import unittest

import
  std / [os],
  todoApppkg / [submodule, taskInfo, dbtables]

test "correct welcome":
  check getWelcomeMessage() == "Hello, World!"

let dbName = "todo.db"
var db: DbConn
var testDir = currentSourcePath().parentDir

test "create db file":
  while testDir.dirExists:
    testDir = testDir / "tmp"
  testDir.createDir
  testDir.setCurrentDir
  db = dbName.openDb
  db.createTables
  check dbName.fileExists

test "make task":
  var task = newTask("dummy", tsDoing)
  db.saveTask(task)
  for i in 0 .. 2:
    task = newTask("task" & $(i * 3 + 1))
    for j in 1 .. 2:
      var t = newTask()
      t.title = "task" & $(i * 3 + j + 1)
      task.children.add t
    db.saveTask(task)

  check db.selectTaskTable.len > 0

test "get task by id":
  let task = db.getTask(1)
  check task.title == "dummy"
  check task.status == tsDoing

test "get task by title":
  let task = db.getTask("task1")
  check task[0].children[0].title == "task2"

test "get all task":
  let taskList = db.getTaskAll
  check taskList[1].title == "task1"
  check taskList[3].children[1].title == "task9"

test "remove db file":
  db.close
  testDir.removeDir
  check not testDir.dirExists
