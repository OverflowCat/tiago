#import "../lib.typ": *
#set page(width: auto, height: auto, margin: 1pt)

#let code = ```
# SQL Tables example
users: {
  shape: sql_table
  id: int {constraint: primary_key}
  name: varchar(255)
  email: varchar(255) {constraint: unique}
  created_at: timestamp
}

posts: {
  shape: sql_table
  id: int {constraint: primary_key}
  user_id: int {constraint: foreign_key}
  title: varchar(255)
  content: text
  published: boolean
}

comments: {
  shape: sql_table
  id: int {constraint: primary_key}
  post_id: int {constraint: foreign_key}
  user_id: int {constraint: foreign_key}
  body: text
}

users.id <-> posts.user_id
posts.id <-> comments.post_id
users.id <-> comments.user_id
```.text

#render(code)
