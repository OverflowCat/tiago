#import "../lib.typ": *
#set page(width: auto, height: auto, margin: 1pt)

#let code = ```
# Sequence diagram example

shape: sequence_diagram

alice: Alice
bob: Bob
server: Server

alice -> bob: Hello
bob -> alice: "Hi there!"
alice -> server: Request data
server -> alice: Response
bob -> server: Another request
server -> bob: Another response
```.text

#render(code)
