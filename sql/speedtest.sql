CREATE TABLE speedtest (
    id          INTEGER PRIMARY KEY,
    time        INTEGER,
    ip          TEXT,
    downspeed   FLOAT,
    downtime    FLOAT,
    downsize    FLOAT,
    upspeed     FLOAT,
    uptime      FLOAT,
    upsize      FLOAT,
    useragent   TEXT,
    tag         TEXT,
    UNIQUE      (id)
);
