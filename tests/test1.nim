import unittest
import
  std / [os, strutils, times, tables, osproc, envvars]

const
  DateFormat = "yyyy-MM-dd"

import todoApppkg/taskdata
suite "taskdata":
  const
    EnvKey = "TASKDATA"
  let
    origEnv = EnvKey.getEnv
    tmpDataDir = "." / "data"
  tmpDataDir.createDir
  EnvKey.putEnv(tmpDataDir)
  defer:
    EnvKey.putEnv(origEnv)
    tmpDataDir.removeDir

  var
    uuids: seq[string]
  block makeTask:
    let cmdFormat = "task add proj:$1 due:$2 $3"
    discard execProcess(cmdFormat % ["proj1", "2100-01-01", "detail1"])
    discard execProcess(cmdFormat % ["proj1", "2100-02-01", "detail2"])
    discard execProcess(cmdFormat % ["proj1", "2100-03-01", "detail3"])
    discard execProcess(cmdFormat % ["proj1", "2100-04-01", "detail4"])
    discard execProcess(cmdFormat % ["proj1", "2100-05-01", "detail5"])
    discard execProcess(cmdFormat % ["proj1", "2100-12-01", "title1"])
    discard execProcess("task 6 mod dep:1-5")
    for i in 1 .. 6:
      uuids.add execProcess("task $1 uuids" % [$i]).replace("\n")
    discard execProcess("task $1 done" % uuids[0])
    discard execProcess("task $1 start" % uuids[1])
    discard execProcess("task $1 mod wait:2100-01-01" % uuids[2])
    discard execProcess("task $1 mod sch:2100-02-01" % uuids[3])

  test "get data":
    let data = getTaskData()
    for idx, uuid in uuids:
      let dat = data[uuid]
      check dat.proj == "proj1"
      if idx < 5:
        check dat.title == "detail$1" % [$(idx + 1)]
        check dat.children.len == 0
        check dat.isDetail
      case idx
      of 0:
        check dat.status == Done
      of 1:
        check dat.status == Doing
        check dat.due == "2100-02-01".parse(DateFormat)
      of 2:
        check dat.status == Hide
        check dat.due == "2100-03-01".parse(DateFormat)
        check dat.waitFor == "2100-01-01".parse(DateFormat)
      of 3:
        check dat.status == Waiting
        check dat.due == "2100-04-01".parse(DateFormat)
        check dat.waitFor == "2100-02-01".parse(DateFormat)
      of 4:
        check dat.status == Pending
        check dat.due == "2100-05-01".parse(DateFormat)
      else:
        check dat.title == "title1"
        check dat.children.len == 5
        check not dat.isDetail
