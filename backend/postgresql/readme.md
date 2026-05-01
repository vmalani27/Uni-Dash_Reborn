# PostgreSQL Command Line Quick Reference

## 1. Access the Database

```
psql -h localhost -U unidash_user -d unidash
```
- Host: localhost
- User: unidash_user
- Database: unidash
- Password: root (enter when prompted)

If `psql` is not installed, install it with:
```
sudo apt install postgresql-client
```

---

## 2. List All Tables

After connecting with `psql`, run:
```
\dt
```

---

## 3. List All Databases

```
\l
```

---

## 4. Describe a Table (Show Columns)

```
\d tablename
```

---

## 5. Truncate (Empty) a Table

```
TRUNCATE tablename;
```
To truncate multiple tables and reset IDs:
```
TRUNCATE table1, table2 RESTART IDENTITY;
```

---

## 6. Run a Custom SQL Query

```
SELECT * FROM tablename LIMIT 10;
```

---

## 7. Exit psql

```
\q
```

---

**Tip:** All `\` commands are run inside the `psql` prompt, not in your shell.
