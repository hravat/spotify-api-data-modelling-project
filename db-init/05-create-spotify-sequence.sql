CREATE SEQUENCE spotify_api.SEQ_MARKET_SR_KEY
    START WITH 1               -- Start value of the sequence
    INCREMENT BY 1             -- Increment value (1 is the default)
    MINVALUE 1                 -- Minimum value (default is 1)
    MAXVALUE 9223372036854775807 -- Maximum value for 64-bit integer
    CACHE 1; 