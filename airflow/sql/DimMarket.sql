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
	NEXTVAL('spotify_api_prod.seq_market_sr_key'),
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
	spotify_api_stg."DIM_MARKET_STG" as src
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
select
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
on
	conflict (
    alpha_2,
    alpha_3,
    country_code,
    iso_3166_2
    ) 
do 
UPDATE
	SET etl_insert_date=CURRENT_TIMESTAMP;

DROP table spotify_api_stg."DIM_MARKET_STG";