create table users
(
  id                 serial not null primary key,
  created_at         timestamp not null default now(),
  last_updated_at    timestamp not null default now(),
  username           text not null unique
);

create table notes
(
  id                 serial not null primary key,
  created_at         timestamp not null default now(),
  updated_at         timestamp null,
  user_id            integer not null references users,
  note_uuid          uuid not null unique,
  body               text not null,
  deleted            boolean not null default false
);

CREATE INDEX notes_user_idx ON notes (user_id);
