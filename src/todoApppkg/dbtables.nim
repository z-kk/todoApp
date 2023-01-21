import
  db_sqlite,
  csvDir / [task]
export
  db_sqlite,
  task
proc openDb*(path = "todo.db"): DbConn =
  let db = open(path, "", "", "")
  return db
proc createTables*(db: DbConn) =
  db.createTaskTable
