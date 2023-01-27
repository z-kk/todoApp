import
  std / [os, strutils],
  docopt

type
  cmdOpt* = object
    dbname*: string

const
  Version* {.strdefine.} = ""

let
  appName* = getAppFilename().extractFilename

proc readCmdOpt*(): cmdOpt =
  ## Read command line options.
  let doc = """
    $1

    Usage:
      $1 [<dbname>]

    Options:
      -h --help         Show this screen.
      --version         Show version.
      <dbname>          Database file name.
  """ % [appName]
  let args = doc.dedent.docopt(version = Version)
  if args["<dbname>"]:
    result.dbname = $args["<dbname>"]
