import
  std / times,
  dbtables

type
  taskStatus* = enum
    tsNone
    tsDoing
    tsDone

  taskInfoImpl* = object
    id*: int
    title*: string
    status*: taskStatus
    children*: seq[taskInfo]

  taskInfo* = ref taskInfoImpl

func `$`*(task: taskInfo): string =
  $task[]

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
    t: TaskTable
    taskId = task.id
    isChanged = false
  proc setVal[T](prev: var T, val: T) =
    if prev != val:
      isChanged = true
    prev = val

  if taskId > 0:
    try:
      t = db.selectTaskTable("id = ?", @[], taskId)[0]
    except:
      discard

  t.title.setVal(task.title)
  t.status.setVal(task.status.ord)
  t.parent.setVal(parentId)
  if isChanged:
    let nw = now()
    t.updated_at = nw
    if taskId == 0:
      taskId = db.tryInsertTaskTable(t).int
    else:
      db.updateTaskTable(t)

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
    task.id = row.id
    task.children = db.getChildren(task.id)
    result.add task

proc getTask*(db: DbConn, id: int): taskInfo =
  ## タスクを取得
  let row = db.selectTaskTable("id = ?", id)[0]
  result = newTask(row.title, taskStatus(row.status))
  result.id = id
  result.children = db.getChildren(id)

proc getTask*(db: DbConn, title: string): seq[taskInfo] =
  ## タスクを取得
  let rows = db.selectTaskTable("title = ?", title)
  for row in rows:
    var task = newTask(row.title, taskStatus(row.status))
    task.id = row.id
    task.children = db.getChildren(task.id)
    result.add task

proc getTaskAll*(db: DbConn): seq[taskInfo] =
  ## タスクを取得
  return db.getChildren(0)
