import
  std / [strutils, rdstdin],
  cliSeqSelector,
  taskInfo, dbtables

type
  nextAction = enum
    naSelect = "タスクを選択"
    naEdit = "タスクを編集"
    naAppend = "タスクを追加"
    naRemove = "タスクを削除"
    naExit = "終了"

proc toStr(task: taskInfo): string =
  ## タスク表示文字列
  return "$1: $2; $3" % [$task.id, task.title, $task.status]

proc toStrSeq(list: seq[taskInfo]): seq[string] =
  ## 文字列リストを取得
  for task in list:
    result.add task.toStr

proc show(task: taskInfo, isShowChildren = false) =
  ## タスクを表示
  echo task.toStr
  if isShowChildren:
    for t in task.children:
      echo "  ", t.toStr

proc makeTask(): taskInfo =
  ## タスクを作成
  while true:
    let
      title = readLineFromStdin("title: ")
      status = taskStatus.select("status: ")
    result = newTask(title, status)
    if readLineFromStdin("OK?[Y/n] ").toLower != "n":
      break

proc editTask(task: taskInfo) =
  ## タスクを編集
  while true:
    let title = readLineFromStdin("title[$1]: " % task.title)
    if title != "":
      task.title = title
    task.status = taskStatus.select("status: ", task.status)
    if readLineFromStdin("OK?[Y/n] ").toLower != "n":
      break

proc beginCli*(db: DbConn) =
  ## CLI開始
  var
    taskList = db.getTaskAll
    selected: seq[taskInfo]
    next: nextAction
  while next != naExit:
    echo ""
    if selected.len == 0:
      for task in taskList:
        task.show
    else:
      selected[^1].show(true)

    if taskList.len == 0:
      next = naAppend
      echo $next
    else:
      next = nextAction.select
    case next
    of naSelect:  # タスク選択
      var list =
        if selected.len == 0:
          taskList.toStrSeq
        else:
          selected[^1].children.toStrSeq
      if selected.len > 0:
        list.insert("Parent")
      let res = list.select
      if selected.len == 0:
        selected.add taskList[res.idx]
      elif res.idx == 0:
        selected.delete(selected.high)
      else:
        selected.add selected[^1].children[res.idx - 1]
    of naEdit:  # タスク編集
      if selected.len > 0:
        selected[^1].editTask
    of naAppend:  # タスク追加
      let task = makeTask()
      if selected.len == 0:
        taskList.add task
      else:
        selected[^1].children.add task
    of naRemove:  # タスク削除
      if selected.len > 0:
        if readLineFromStdin("このタスクを削除?[Y/n] ").toLower != "n":
          discard  # TODO
    of naExit:  # 終了
      for task in taskList:
        db.saveTask(task)
