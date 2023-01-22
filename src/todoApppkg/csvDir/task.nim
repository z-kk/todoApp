import
  os, strutils, strformat, parsecsv,
  times,
  db_sqlite
type
  TaskCol* {.pure.} = enum
    id, title, status, parent, begin_at, end_at, duration, updated_at
  TaskTable* = object
    primKey: int
    id*: int
    title*: string
    status*: int
    parent*: int
    begin_at*: DateTime
    end_at*: DateTime
    duration*: string
    updated_at*: DateTime
proc setDataTaskTable*(data: var TaskTable, colName, value: string) =
  case colName
  of "id":
    try:
      data.id = value.parseInt
    except: discard
  of "title":
    try:
      data.title = value
    except: discard
  of "status":
    try:
      data.status = value.parseInt
    except: discard
  of "parent":
    try:
      data.parent = value.parseInt
    except: discard
  of "begin_at":
    try:
      data.begin_at = value.parse("yyyy-MM-dd HH:mm:ss")
    except: discard
  of "end_at":
    try:
      data.end_at = value.parse("yyyy-MM-dd HH:mm:ss")
    except: discard
  of "duration":
    try:
      data.duration = value
    except: discard
  of "updated_at":
    try:
      data.updated_at = value.parse("yyyy-MM-dd HH:mm:ss")
    except: discard
proc createTaskTable*(db: DbConn) =
  let sql = """create table if not exists task(
    id INTEGER not null primary key,
    title TEXT not null,
    status INTEGER not null,
    parent INTEGER default 0 not null,
    begin_at DATETIME,
    end_at DATETIME,
    duration TEXT,
    updated_at DATETIME default '9999-12-31' not null
  )""".sql
  db.exec(sql)
proc tryInsertTaskTable*(db: DbConn, rowData: TaskTable): int64 =
  var vals: seq[string]
  var sql = "insert into task("
  if rowData.id > 0:
    sql &= "id,"
  vals.add rowData.title
  sql &= "title,"
  vals.add $rowData.status
  sql &= "status,"
  vals.add $rowData.parent
  sql &= "parent,"
  if rowData.begin_at != DateTime():
    vals.add rowData.begin_at.format("yyyy-MM-dd HH:mm:ss")
    sql &= "begin_at,"
  if rowData.end_at != DateTime():
    vals.add rowData.end_at.format("yyyy-MM-dd HH:mm:ss")
    sql &= "end_at,"
  vals.add rowData.duration
  sql &= "duration,"
  if rowData.updated_at != DateTime():
    vals.add rowData.updated_at.format("yyyy-MM-dd HH:mm:ss")
    sql &= "updated_at,"
  sql[^1] = ')'
  sql &= " values ("
  if rowData.id > 0:
    sql &= &"{rowData.id},"
  sql &= "?,".repeat(vals.len)
  sql[^1] = ')'
  return db.tryInsertID(sql.sql, vals)
proc insertTaskTable*(db: DbConn, rowData: TaskTable) =
  let res = tryInsertTaskTable(db, rowData)
  if res < 0: db.dbError
proc insertTaskTable*(db: DbConn, rowDataSeq: seq[TaskTable]) =
  for rowData in rowDataSeq:
    db.insertTaskTable(rowData)
proc selectTaskTable*(db: DbConn, whereStr = "", orderBy: seq[string], whereVals: varargs[string, `$`]): seq[TaskTable] =
  var sql = "select * from task"
  if whereStr != "":
    sql &= " where " & whereStr
  if orderBy.len > 0:
    sql &= " order by " & orderBy.join(",")
  let rows = db.getAllRows(sql.sql, whereVals)
  for row in rows:
    var res: TaskTable
    res.primKey = row[TaskCol.id.ord].parseInt
    res.setDataTaskTable("id", row[TaskCol.id.ord])
    res.setDataTaskTable("title", row[TaskCol.title.ord])
    res.setDataTaskTable("status", row[TaskCol.status.ord])
    res.setDataTaskTable("parent", row[TaskCol.parent.ord])
    res.setDataTaskTable("begin_at", row[TaskCol.begin_at.ord])
    res.setDataTaskTable("end_at", row[TaskCol.end_at.ord])
    res.setDataTaskTable("duration", row[TaskCol.duration.ord])
    res.setDataTaskTable("updated_at", row[TaskCol.updated_at.ord])
    result.add(res)
proc selectTaskTable*(db: DbConn, whereStr = "", whereVals: varargs[string, `$`]): seq[TaskTable] =
  selectTaskTable(db, whereStr, @[], whereVals)
proc updateTaskTable*(db: DbConn, rowData: TaskTable) =
  if rowData.primKey < 1: return
  var vals: seq[string]
  var sql = "update task set "
  vals.add rowData.title
  sql &= "title = ?,"
  vals.add $rowData.status
  sql &= "status = ?,"
  vals.add $rowData.parent
  sql &= "parent = ?,"
  if rowData.begin_at != DateTime():
    vals.add rowData.begin_at.format("yyyy-MM-dd HH:mm:ss")
    sql &= "begin_at = ?,"
  if rowData.end_at != DateTime():
    vals.add rowData.end_at.format("yyyy-MM-dd HH:mm:ss")
    sql &= "end_at = ?,"
  vals.add rowData.duration
  sql &= "duration = ?,"
  if rowData.updated_at != DateTime():
    vals.add rowData.updated_at.format("yyyy-MM-dd HH:mm:ss")
    sql &= "updated_at = ?,"
  sql[^1] = ' '

  sql &= &"where id = {rowData.primKey}"
  db.exec(sql.sql, vals)
proc updateTaskTable*(db: DbConn, rowDataSeq: seq[TaskTable]) =
  for rowData in rowDataSeq:
    db.updateTaskTable(rowData)
proc dumpTaskTable*(db: DbConn, dirName = ".") =
  dirName.createDir
  let
    fileName = dirName / "task.csv"
    f = fileName.open(fmWrite)
  f.writeLine("id,title,status,parent,begin_at,end_at,duration,updated_at")
  for row in db.selectTaskTable:
    f.write('"', $row.id, '"', ',')
    f.write('"', $row.title, '"', ',')
    f.write('"', $row.status, '"', ',')
    f.write('"', $row.parent, '"', ',')
    if row.begin_at == DateTime():
      f.write(',')
    else:
      f.write(row.begin_at.format("yyyy-MM-dd HH:mm:ss"), ',')
    if row.end_at == DateTime():
      f.write(',')
    else:
      f.write(row.end_at.format("yyyy-MM-dd HH:mm:ss"), ',')
    f.write('"', $row.duration, '"', ',')
    if row.updated_at == DateTime():
      f.write(',')
    else:
      f.write(row.updated_at.format("yyyy-MM-dd HH:mm:ss"), ',')
    f.setFilePos(f.getFilePos - 1)
    f.writeLine("")
  f.close
proc insertCsvTaskTable*(db: DbConn, fileName: string) =
  var parser: CsvParser
  defer: parser.close
  parser.open(fileName)
  parser.readHeaderRow
  while parser.readRow:
    var data: TaskTable
    data.setDataTaskTable("id", parser.rowEntry("id"))
    data.setDataTaskTable("title", parser.rowEntry("title"))
    data.setDataTaskTable("status", parser.rowEntry("status"))
    data.setDataTaskTable("parent", parser.rowEntry("parent"))
    data.setDataTaskTable("begin_at", parser.rowEntry("begin_at"))
    data.setDataTaskTable("end_at", parser.rowEntry("end_at"))
    data.setDataTaskTable("duration", parser.rowEntry("duration"))
    data.setDataTaskTable("updated_at", parser.rowEntry("updated_at"))
    db.insertTaskTable(data)
proc restoreTaskTable*(db: DbConn, dirName = ".") =
  let fileName = dirName / "task.csv"
  db.exec("delete from task".sql)
  db.insertCsvTaskTable(fileName)
