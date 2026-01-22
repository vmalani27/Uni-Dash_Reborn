sudo -u postgres psql


when creating a new backend in linux

CREATE DATABASE unidash;

CREATE USER unidash_user WITH PASSWORD '';

ALTER DATABASE unidash OWNER TO unidash_user;

GRANT ALL PRIVILEGES ON DATABASE unidash TO unidash_user;
