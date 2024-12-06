INSERT INTO spotify_api_prod.FACT_AUDIOBOOK 
(
ID,
MARKET_SR_KEY 
)
SELECT 
	SA.ID,
	COALESCE (DM.MARKET_SR_KEY,-1) 
	FROM spotify_api_stg.raw_spotify_audiobooks_api_stg SA 
		LEFT OUTER JOIN spotify_api_prod.DIM_MARKET DM 
	ON SA.AVAILABLE_MARKET = DM.ALPHA_2;