import
  todoApppkg / [webserver]

const
  DefaultPort = 5000

when isMainModule:
  startWebServer(DefaultPort)
