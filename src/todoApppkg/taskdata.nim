import
  std / [times, tables, osproc, json]

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

proc getTaskData*(): OrderedTable[string, TaskData] =
  proc getStrValue(n: JsonNode, key: string): string =
    if key in n:
      return n[key].getStr
  proc getTimeValue(n: JsonNode, key: string): DateTime =
    if key in n:
      return n[key].getStr.parse("yyyyMMdd'T'HHmmsszzz", utc()).local

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
