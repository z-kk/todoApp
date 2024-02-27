import
  std / [strutils, sequtils, times, json],
  jester, htmlgenerator,
  taskdata, submodule, utils

type
  Page = enum
    pgTop = "/"

const
  AppTitle = "TODO"

proc topPage(req: Request): seq[string] =
  include "tmpl/top.tmpl"
  return topPageBody().splitLines

proc makePage(req: Request, page: Page): string =
  include "tmpl/base.tmpl"
  var
    param = req.newParams
  param.title = AppTitle

  case page
  of pgTop:
    param.body = req.topPage
    param.script.add req.newScript("/top.js").toHtml

  return param.basePage

proc updateData*(req: Request): JsonNode =
  ## Update task data.
  let json = req.body.parseJson
  var data: TaskData
  data.uuid = json["uuid"].getStr
  data.proj = json["proj"].getStr
  data.title = json["title"].getStr
  case TaskStatus(json["status"].getStr.parseInt)
  of Pending: discard
  of Doing: data.start
  of Waiting: data.wait(json["for"].getStr.parse(DateFormat))
  of Hide: data.hide(json["for"].getStr.parse(DateFormat))
  of Done: data.done
  if "due" in json:
    data.due = json["due"].getStr.parse(DateFormat)

  var target = @[data]
  if "parent" in json:
    var parent = getTaskData()[json["parent"].getStr]
    if data.uuid notin parent.children:
      parent.children.add data.uuid
    target.add parent

  target.commit
  result = %*{
    "result": true,
    "data": getTaskData().toJson,
  }

router rt:
  get "/":
    resp request.makePage(pgTop)
  get "/data":
    resp getTaskData().toJson
  post "/update":
    resp request.updateData

proc startWebServer*(port: int, appName = "") =
  let settings = newSettings(Port(port), appName = appName)
  var jest = initJester(rt, settings=settings)
  jest.serve
