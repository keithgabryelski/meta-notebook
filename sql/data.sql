INSERT INTO users (username) VALUES ('keithgabryelski');

INSERT INTO notes
  (user_id, note_uuid, body)
VALUES
  (
    (SELECT id FROM users WHERE username = 'keithgabryelski'),
    'c9207e24-ed3f-11e5-9ce9-5e5517507c66',
    'This is a note'
  ),
  (
    (SELECT id FROM users WHERE username = 'keithgabryelski'),
    'c9207e24-ed3f-11e5-9ce9-5e5517507c67',
    'is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry''s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has'
  ),
  (
    (SELECT id FROM users WHERE username = 'keithgabryelski'),
    'c9207e24-ed3f-11e5-9ce9-5e5517507c68',
    'is simply dummy text of the printing and typesetting industry. 

Lorem Ipsum has been the industry''s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don''t look even slightly believable.

 If you are going to use a passage '
  );
