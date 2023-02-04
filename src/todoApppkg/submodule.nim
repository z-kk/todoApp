import
  std / [os, strutils],
  docopt,
  version

type
  cmdOpt* = object
    dbname*: string

let
  appName* = getAppFilename().extractFilename

proc readCmdOpt*(): cmdOpt =
  ## Read command line options.
  let doc = """
    $1

    Usage:
      $1 [<dbname>]

    Options:
      -h --help     Show this screen.
      -v --version  Show version.
      <dbname>      Database file name.
  """ % [appName]
  let args = doc.dedent.docopt(version = Version)
  if args["<dbname>"]:
    result.dbname = $args["<dbname>"]
