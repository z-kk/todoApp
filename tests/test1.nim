import unittest
import
  std / [os, strutils, times, tables, json, osproc, envvars],
  todoApppkg / [taskdata, submodule]

suite "taskdata":
  const
    EnvKey = "TASKDATA"
  let
    origEnv = EnvKey.getEnv
    tmpDataDir = "." / "data"

  block setup:
    tmpDataDir.createDir
    EnvKey.putEnv(tmpDataDir)
  defer:
    EnvKey.putEnv(origEnv)
    tmpDataDir.removeDir

  test "get data":
    var uuids: seq[string]
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

  block reset:
    tmpDataDir.removeDir
    tmpDataDir.createDir

  test "add data":
    var data: seq[TaskData]
    block makeData:
      for i in 1 .. 6:
        var dat: TaskData
        dat.uuid = "dummyId" & $i
        dat.proj = "proj1"
        dat.title = "detail" & $i
        dat.due = ("2100-0$1-01" % [$i]).parse(DateFormat)
        case i
        of 1:
          dat.done
        of 2:
          dat.start
        of 3:
          dat.hide("2100-01-01".parse(DateFormat))
        of 4:
          dat.wait("2100-02-01".parse(DateFormat))
        of 6:
          dat.wait("2100-03-15".parse(DateFormat))
          dat.due = DateTime()
        else:
          discard

        data.add dat

      var dat: TaskData
      dat.uuid = "dummyId" & $(data.len + 1)
      dat.proj = "proj1"
      dat.title = "title1"
      dat.due = "2100-12-01".parse(DateFormat)
      for i in 1 .. 5:
        dat.children.add "dummyId" & $i
      data.add dat

    data.commit

    let checkData = getTaskData()
    check checkData.len == 7
    for i, val in checkData:
      case val.title
      of "detail1":
        check val.proj == "proj1"
        check val.status == Done
      of "detail2":
        check val.due == "2100-02-01".parse(DateFormat)
        check val.status == Doing
      of "detail3":
        check val.status == Hide
      of "detail4":
        check val.status == Waiting
      of "detail5":
        check val.status == Pending
      of "detail6":
        check val.status == Waiting
      of "title1":
        check val.children.len == 5

  test "update data":
    var data = getTaskData()
    for uuid, dat in data:
      data[uuid].proj = "proj2"
      if dat.status in {Doing, Waiting, Hide}:
        data[uuid].reset
      data[uuid].children = @[]

    data.commit

    for _, dat in getTaskData():
      if dat.title != "detail1":
        check dat.proj == "proj2"
        check dat.status == Pending

    for uuid, dat in data:
      case dat.title
      of "detail2":
        data[uuid].start
      of "detail3":
        data[uuid].hide("2100-01-01".parse(DateFormat))
      of "detail4":
        data[uuid].wait("2100-02-01".parse(DateFormat))
      of "detail6":
        data[uuid].wait("2100-03-15".parse(DateFormat))
      of "title1":
        data[uuid].title = "title2"
        for id, _ in data:
          if id != uuid:
            data[uuid].children.add id

    data.commit

    for _, dat in getTaskData():
      case dat.title
      of "detail2":
        check dat.status == Doing
      of "detail3":
        check dat.status == Hide
      of "detail4":
        check dat.status == Waiting
      check dat.isDetail != (dat.title == "title2")

  test "to json":
    let data = getTaskData()
    var uuids: Table[string, string]
    for uuid, dat in data:
      uuids[dat.title] = uuid

    check data.toJson == %*[
      {
        "proj": "proj2",
        "data": [
          {
            "uuid": uuids["title2"],
            "title": "title2",
            "status": Pending.ord,
            "due": "2100-12-01",
            "children": [
              {
                "uuid": uuids["detail1"],
                "title": "detail1",
                "status": Done.ord,
                "due": "2100-01-01",
              },
              {
                "uuid": uuids["detail2"],
                "title": "detail2",
                "status": Doing.ord,
                "due": "2100-02-01",
              },
              {
                "uuid": uuids["detail3"],
                "title": "detail3",
                "status": Hide.ord,
                "for": "2100-01-01",
                "due": "2100-03-01",
              },
              {
                "uuid": uuids["detail6"],
                "title": "detail6",
                "status": Waiting.ord,
                "for": "2100-03-15",
              },
              {
                "uuid": uuids["detail4"],
                "title": "detail4",
                "status": Waiting.ord,
                "for": "2100-02-01",
                "due": "2100-04-01",
              },
              {
                "uuid": uuids["detail5"],
                "title": "detail5",
                "status": Pending.ord,
                "due": "2100-05-01",
              },
            ],
          },
        ],
      },
    ]

  test "delete data":
    var uuid = ""
    for _, data in getTaskData():
      if data.title == "detail2":
        uuid = data.uuid
        data.delete
        break
    check uuid notin getTaskData()
