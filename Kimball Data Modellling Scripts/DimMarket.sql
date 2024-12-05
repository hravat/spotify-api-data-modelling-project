CREATE TABLE spotify_api_prod.DIM_MARKET 
(
    MARKET_SR_KEY BIGINT,
    NAME VARCHAR(100),
    ALPHA_2 VARCHAR(100),
    ALPHA_3 VARCHAR(100),
    COUNTRY_CODE VARCHAR(100),
    ISO_3166_2 VARCHAR(100),
    REGION VARCHAR(100),
    SUB_REGION VARCHAR(100),
    INTERMEDIATE_REGION VARCHAR(100),
    REGION_CODE VARCHAR(100),
    SUB_REGION_CODE VARCHAR(100),
    INTERMEDIATE_REGION_CODE VARCHAR(100),
    ACTIVE_FLAG VARCHAR(1),
    ETL_LOAD_DATE DATE,
    ETL_INSERT_DATE DATE 
);


CREATE UNIQUE INDEX idx_dim_market_unique_columns
ON public.dim_market(alpha_2, alpha_3, country_code, iso_3166_2);

CREATE SEQUENCE SEQ_MARKET_SR_KEY
    START WITH 1               -- Start value of the sequence
    INCREMENT BY 1             -- Increment value (1 is the default)
    MINVALUE 1                 -- Minimum value (default is 1)
    MAXVALUE 9223372036854775807 -- Maximum value for 64-bit integer
    CACHE 1;       


insert
	into
	spotify_api_prod.dim_market
(
		market_sr_key,
		"name",
		alpha_2,
		alpha_3,
		country_code,
		iso_3166_2,
		region,
		sub_region,
		intermediate_region,
		region_code,
		sub_region_code,
		intermediate_region_code,
		active_flag,
		etl_load_date,
		etl_insert_date
	)
select
	NEXTVAL('SEQ_MARKET_SR_KEY'),
	src."name",
	src.alpha_2,
	src.alpha_3,
	src.country_code,
	src.iso_3166_2,
	src.region,
	src.sub_region,
	src.intermediate_region,
	src.region_code,
	src.sub_region_code,
	src.intermediate_region_code,
	'Y',
	CURRENT_TIMESTAMP,
	CURRENT_TIMESTAMP
from
	spotify_api_stg.dim_market_stg as src
on
	conflict (
    alpha_2,
    alpha_3,
    country_code,
    iso_3166_2
    )
/* or you may use [DO NOTHING;] */
	do
update
set
	"name" = EXCLUDED."name",
	alpha_2 = EXCLUDED.alpha_2,
	alpha_3 = EXCLUDED.alpha_3,
	country_code = EXCLUDED.country_code,
	iso_3166_2 = EXCLUDED.iso_3166_2,
	region = EXCLUDED.region,
	sub_region = EXCLUDED.sub_region,
	intermediate_region = EXCLUDED.intermediate_region,
	region_code = EXCLUDED.region_code,
	sub_region_code = EXCLUDED.sub_region_code,
	intermediate_region_code = EXCLUDED.intermediate_region_code,
	etl_insert_date = CURRENT_TIMESTAMP;

INSERT INTO spotify_api_prod.dim_market (
    market_sr_key,
    "name",
    alpha_2,
    alpha_3,
    country_code,
    iso_3166_2,
    region,
    sub_region,
    intermediate_region,
    region_code,
    sub_region_code,
    intermediate_region_code,
    active_flag,
    etl_load_date,
    etl_insert_date
)
VALUES (
    -1,  -- Special surrogate key indicating missing data
    'UNKNOWN',
    'UNKNOWN',  -- Example country code
    'UNKNOWN',
    'UNKNOWN',
    'UNKNOWN',
    'UNKNOWN REGION',
    'UNKNOWN SUBREGION',
    'UNKNOWN INTERMEDIATE REGION',
    '-1',
    '-1',
    '-1',
    'Y',  -- Active flag
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);    