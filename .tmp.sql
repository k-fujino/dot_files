select * from users where id = ( select max(id) from users );
