import
  std / [strutils, sequtils],
  jester, htmlgenerator,
  taskdata, utils

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

router rt:
  get "/":
    resp request.makePage(pgTop)
  get "/data":
    resp getTaskData().toJson

proc startWebServer*(port: int, appName = "") =
  let settings = newSettings(Port(port), appName = appName)
  var jest = initJester(rt, settings=settings)
  jest.serve
