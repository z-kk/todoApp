import
  std / [strutils, times, tables, osproc, json],
  uuid4

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
    status*: TaskStatus
    title*: string
    due*: DateTime
    startAt*: DateTime
    endAt*: DateTime
    waitFor*: DateTime
    isDetail*: bool

const
  WarriorFormat = "yyyyMMdd'T'HHmmsszzz"

proc toCmdStr(node: JsonNode): string =
  for c in $node:
    if c in "\"{}":
      result.add '\\'
    result.add c

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

  for key, data in result:
    for child in data.children:
      result[child].isDetail = true

proc commit*(data: seq[TaskData]) =
  let currentData = getTaskData()
  var uuidTable: Table[string, string]
  for dat in data:
    assert dat.uuid != ""
    if dat.uuid in currentData:
      discard
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
