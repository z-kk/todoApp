import
  std / times,
  dbtables

type
  taskStatus* = enum
    tsNone
    tsDoing
    tsDone

  taskInfoImpl* = object
    title*: string
    status*: taskStatus
    children*: seq[taskInfo]
    dbRow: TaskTable

  taskInfo* = ref taskInfoImpl

func `$`*(task: taskInfo): string =
  $task[]

func id*(task: taskInfo): int =
  task.dbRow.id

proc newTask*(title = "", status = tsNone): taskInfo =
  ## タスク作成
  return taskInfo(title: title, status: status)

proc addChild*(task: taskInfo, title: string) =
  ## 子タスクを追加
  var newTask: taskInfo
  newTask.title = title
  task.children.add newTask

proc saveTask*(db: DbConn, task: taskInfo, parentId = 0) =
  ## タスクを保存
  var
    taskId = task.dbRow.id
    isChanged = false
  proc setVal[T](prev: var T, val: T) =
    if prev != val:
      isChanged = true
    prev = val

  task.dbRow.title.setVal(task.title)
  task.dbRow.status.setVal(task.status.ord)
  task.dbRow.parent.setVal(parentId)
  if isChanged:
    task.dbRow.updated_at = now()
    if taskId == 0:
      taskId = db.tryInsertTaskTable(task.dbRow).int
      task.dbRow = db.selectTaskTable("id = ?", taskId)[0]
    else:
      db.updateTaskTable(task.dbRow)

  for child in task.children:
    db.saveTask(child, taskId)

proc saveTask*(db: DbConn, taskList: seq[taskInfo], parentId = 0) =
  ## タスクを保存
  for task in taskList:
    db.saveTask(task, parentId)

proc getChildren(db: DbConn, parent: int): seq[taskInfo] =
  ## 子タスクを取得
  let rows = db.selectTaskTable("parent = ?", @["id"], parent)
  for row in rows:
    var task = newTask(row.title, taskStatus(row.status))
    task.children = db.getChildren(row.id)
    task.dbRow = row
    result.add task

proc getTask*(db: DbConn, id: int): taskInfo =
  ## タスクを取得
  let row = db.selectTaskTable("id = ?", id)[0]
  result = newTask(row.title, taskStatus(row.status))
  result.children = db.getChildren(id)
  result.dbRow = row

proc getTask*(db: DbConn, title: string): seq[taskInfo] =
  ## タスクを取得
  let rows = db.selectTaskTable("title = ?", title)
  for row in rows:
    var task = newTask(row.title, taskStatus(row.status))
    task.children = db.getChildren(row.id)
    task.dbRow = row
    result.add task

proc getTaskAll*(db: DbConn): seq[taskInfo] =
  ## タスクを取得
  return db.getChildren(0)
