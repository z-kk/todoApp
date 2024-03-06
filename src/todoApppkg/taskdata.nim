import
  std / [strutils, sequtils, times, tables, osproc, json, algorithm],
  uuid4,
  submodule

type
  TaskStatus* = enum
    Pending,
    Doing,
    Waiting,
    Hide,
    Done

  TaskData* = object
    uuid*: string
    children*: seq[string]
    proj*: string
    status: TaskStatus
    title*: string
    due*: DateTime
    startAt: DateTime
    endAt: DateTime
    waitFor: DateTime
    isDetail: bool

const
  WarriorFormat = "yyyyMMdd'T'HHmmsszzz"

proc toCmdStr(node: JsonNode): string =
  for c in $node:
    if c in "\"{}":
      result.add '\\'
    result.add c

proc isUpdated(data, current: TaskData): bool =
  return data.children != current.children or
    data.proj != current.proj or
    data.status != current.status or
    data.title != current.title or
    data.due != current.due or
    data.waitFor != current.waitFor

proc sorted*(data: seq[TaskData]): seq[TaskData] =
  var projects: seq[string]
  for dat in data:
    if dat.proj notin projects:
      projects.add dat.proj

  for proj in projects:
    let dat = data.filterIt(it.proj == proj)
    for d in dat.filterIt(not it.isDetail).sortedByIt(
        if it.due != DateTime(): it.due
        elif it.startAt != DateTime(): it.startAt
        else: "9999-12-31".parse(DateFormat)
      ):
      result.add d
      result.add dat.filterIt(it.uuid in d.children).sortedByIt(
        if it.due != DateTime(): it.due
        elif it.startAt != DateTime(): it.startAt
        else: "9999-12-31".parse(DateFormat)
      )

proc sorted*(data: OrderedTable[string, TaskData]): OrderedTable[string, TaskData] =
  var target: seq[TaskData]
  for _, dat in data:
    target.add dat
  for dat in target.sorted:
    result[dat.uuid] = dat

proc toJson*(data: seq[TaskData]): JsonNode =
  result = %*[]
  for dat in data.sorted:
    if result.len == 0 or result[^1]["proj"].getStr != dat.proj:
      result.add %*{
        "proj": dat.proj,
        "data": [],
      }

    var j = %*{
      "uuid": dat.uuid,
      "title": dat.title,
      "status": dat.status.ord,
    }
    if dat.due != DateTime():
      j["due"] = %dat.due.format(DateFormat)
    if dat.status in {Waiting, Hide}:
      j["for"] = %dat.waitFor.format(DateFormat)

    if not dat.isDetail:
      j["children"] = %*[]
      result[^1]["data"].add j
    else:
      result[^1]["data"][^1]["children"].add j

proc toJson*(data: OrderedTable[string, TaskData]): JsonNode =
  var target: seq[TaskData]
  for _, dat in data:
    target.add dat
  return target.toJson

proc getTaskData*(): OrderedTable[string, TaskData] =
  proc getStrValue(n: JsonNode, key: string): string =
    if key in n:
      return n[key].getStr
  proc getTimeValue(n: JsonNode, key: string): DateTime =
    if key in n:
      return n[key].getStr.parse(WarriorFormat, utc()).local

  let json = if execProcess("which task") != "":
    execProcess("task export").parseJson
  else:
    %*[]

  for j in json:
    var data: TaskData

    case j["status"].getStr
    of "pending":
      if "wait" in j:
        data.status = Hide
        data.waitFor = j.getTimeValue("wait")
      elif "start" in j:
        data.status = Doing
        data.startAt = j.getTimeValue("start")
      elif "scheduled" in j and j.getTimeValue("scheduled") > now():
        data.status = Waiting
        data.waitFor = j.getTimeValue("scheduled")
    of "deleted":
      continue
    of "completed":
      data.status = Done
      data.endAt = j.getTimeValue("end")
    of "recurring":
      discard

    data.uuid = j.getStrValue("uuid")
    data.proj = j.getStrValue("project")
    data.title = j.getStrValue("description")
    if "depends" in j:
      for child in j["depends"]:
        data.children.add child.getStr
    data.due = j.getTimeValue("due")

    result[data.uuid] = data

  for _, data in result:
    for child in data.children:
      if child in result:
        result[child].isDetail = true

  return result.sorted

proc start*(data: var TaskData) =
  case data.status
  of Pending:
    data.status = Doing
  of Doing, Done:
    discard
  of Waiting, Hide:
    data.status = Doing
    data.waitFor = DateTime()

proc reset*(data: var TaskData) =
  if data.status != Done:
    data.status = Pending

proc done*(data: var TaskData) =
  data.status = Done

proc wait*(data: var TaskData, waitFor: DateTime) =
  case data.status
  of Pending, Hide:
    data.status = Waiting
    data.waitFor = waitFor
  of Doing, Waiting, Done:
    discard

proc hide*(data: var TaskData, hideFor: DateTime) =
  case data.status
  of Pending, Waiting:
    data.status = Hide
    data.waitFor = hideFor
  of Doing, Hide, Done:
    discard

proc delete*(data: TaskData) =
  let j = %*{
    "uuid": data.uuid,
    "description": data.title,
    "status": "deleted",
  }
  discard execProcess("echo $1 | task import" % [j.toCmdStr])

proc commit*(data: seq[TaskData]) =
  let currentData = getTaskData()
  var uuidTable: Table[string, string]
  for dat in data:
    assert dat.uuid != ""
    if dat.uuid in currentData:
      let current = currentData[dat.uuid]
      if not dat.isUpdated(current) or current.status == Done:
        continue

      var cmdLine = @["task mod", dat.uuid]
      case dat.status
      of Pending:
        cmdLine.add @["wait:", "sch:"]
        if current.status == Doing:
          discard execProcess("task $1 stop" % [dat.uuid])
      of Doing:
        cmdLine.add @["wait:", "sch:"]
        if current.status != Doing:
          discard execProcess("task $1 start" % [dat.uuid])
      of Waiting:
        cmdLine.add "wait:"
        cmdLine.add "sch:" & dat.waitFor.format(DateFormat)
        if current.status == Doing:
          discard execProcess("task $1 stop" % [dat.uuid])
      of Hide:
        cmdLine.add "sch:"
        cmdLine.add "wait:" & dat.waitFor.format(DateFormat)
        if current.status == Doing:
          discard execProcess("task $1 stop" % [dat.uuid])
      of Done:
        discard execProcess("task $1 done" % [dat.uuid])
        continue

      if dat.due != DateTime():
        cmdLine.add "due:" & dat.due.format(DateFormat)
      else:
        cmdLine.add "due:"
      cmdLine.add "proj:" & dat.proj
      cmdLine.add dat.title
      discard execProcess(cmdLine.join(" "))
    else:
      var j = %*{}
      try:
        j["uuid"] = %($dat.uuid.initUuid)
      except:
        uuidTable[dat.uuid] = $uuid4()
        j["uuid"] = %uuidTable[dat.uuid]
      if dat.proj != "":
        j["project"] = %dat.proj
      if dat.due != DateTime():
        j["due"] = %dat.due.utc.format(WarriorFormat)
      if dat.status == Waiting:
        j["scheduled"] = %dat.waitFor.utc.format(WarriorFormat)
      elif dat.status == Hide:
        j["wait"] = %dat.waitFor.utc.format(WarriorFormat)
      j["description"] = %dat.title
      discard execProcess("echo $1 | task import" % [j.toCmdStr])

      case dat.status
      of Doing:
        discard execProcess("task $1 start" % [j["uuid"].getStr])
      of Done:
        discard execProcess("task $1 done" % [j["uuid"].getStr])
      else:
        discard

  # depends
  for dat in data:
    if dat.children.len == 0:
      continue
    if dat.uuid in currentData and not dat.isUpdated(currentData[dat.uuid]):
      continue
    var
      cmdLine = "task mod "
      depends: seq[string]
    if dat.uuid in uuidTable:
      cmdLine.add uuidTable[dat.uuid]
    else:
      cmdLine.add dat.uuid
    cmdLine.add " depends:"
    for child in dat.children:
      if child in uuidTable:
        depends.add uuidTable[child]
      else:
        depends.add child
    cmdLine.add depends.join(",")
    discard execProcess(cmdLine)

proc commit*(data: OrderedTable[string, TaskData]) =
  var target: seq[TaskData]
  for _, dat in data:
    target.add dat
  target.commit

proc status*(data: TaskData): TaskStatus = data.status
proc waitFor*(data: TaskData): DateTime = data.waitFor
proc isDetail*(data: TaskData): bool = data.isDetail
