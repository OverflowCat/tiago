#import "../lib.typ": *
#set page(width: auto, height: auto, margin: 1pt)

#let code = ```
# C4 Diagram example
# Context level view of a system

user: Customer {
  shape: person
}

system: E-Commerce System {
  webapp: Web Application {
    shape: rectangle
    style.fill: "#438DD5"
  }

  api: API Gateway {
    shape: rectangle
    style.fill: "#438DD5"
  }

  db: Database {
    shape: cylinder
    style.fill: "#438DD5"
  }
}

external: {
  payment: Payment Provider {
    shape: rectangle
    style.fill: "#999999"
  }

  email: Email Service {
    shape: rectangle
    style.fill: "#999999"
  }
}

user -> system.webapp: browses
system.webapp -> system.api: calls
system.api -> system.db: reads/writes
system.api -> external.payment: processes payments
system.api -> external.email: sends notifications
```.text

#render(code)
