import
  std / [strutils],
  todoApppkg / [cli, submodule, dbtables]

const
  DbName = "todo.db"

when isMainModule:
  let
    opt = readCmdOpt()
    db =
      if opt.dbname == "":
        echo "DBファイル[$1]を使用します" % DbName
        DbName.openDb
      else:
        opt.dbname.openDb

  db.createTables  # DBテーブルを作成

  db.beginCli
