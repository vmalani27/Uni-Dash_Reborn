sudo -u postgres psql


when creating a new backend in linux

CREATE DATABASE unidash;

CREATE USER unidash_user WITH PASSWORD '';

ALTER DATABASE unidash OWNER TO unidash_user;

GRANT ALL PRIVILEGES ON DATABASE unidash TO unidash_user;


and also setup env with the following,

change local db or user url with the url of current local db and run alembic migrations

install ngrok and sign up using vm27@gmail mail

ngrok http 8000

