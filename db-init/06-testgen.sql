--
-- PostgreSQL database dump
--

-- Dumped from database version 14.1
-- Dumped by pg_dump version 14.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: testgen; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE DATABASE datakitchen;
CREATE USER admin WITH PASSWORD 'admin@123';
GRANT ALL PRIVILEGES ON DATABASE datakitchen TO admin;
CREATE SCHEMA testgen;

CREATE ROLE testgen_execute_role;
GRANT USAGE ON SCHEMA testgen TO testgen_execute_role;
CREATE ROLE testgen_report_role;
GRANT USAGE ON SCHEMA testgen TO testgen_report_role;

-- Connect to the newly created database
\c datakitchen;


CREATE SCHEMA testgen;


ALTER SCHEMA testgen OWNER TO admin;

--
-- Name: datediff(character varying, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.datediff(difftype character varying, firstdate timestamp without time zone, seconddate timestamp without time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
   BEGIN
      RETURN
      CASE
        WHEN UPPER(difftype) IN ('DAY', 'DD')
              THEN DATE_PART('day', seconddate - firstdate)
        WHEN UPPER(difftype) IN ('WEEK','WK')
              THEN TRUNC(DATE_PART('day', seconddate - firstdate)/7)
        WHEN UPPER(difftype) IN ('MON', 'MM')
              THEN 12 * (DATE_PART('year', seconddate) - DATE_PART('year', firstdate))
                    + (DATE_PART('month', seconddate) - DATE_PART('month', firstdate))
        WHEN UPPER(difftype) IN ('QUARTER', 'QTR')
              THEN 4 * (DATE_PART('year', seconddate) - DATE_PART('year', firstdate))
                    + (DATE_PART('qtr', seconddate) - DATE_PART('month', firstdate))
        WHEN UPPER(difftype) IN ('YEAR', 'YY')
              THEN DATE_PART('year', seconddate) - DATE_PART('year', firstdate)
      END;
   END;
$$;


ALTER FUNCTION testgen.datediff(difftype character varying, firstdate timestamp without time zone, seconddate timestamp without time zone) OWNER TO admin;

--
-- Name: fn_charcount(character varying, character varying); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_charcount(instring character varying, searchstring character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
   BEGIN
      RETURN (CHAR_LENGTH(instring) - CHAR_LENGTH(REPLACE(instring, searchstring, ''))) / CHAR_LENGTH(searchstring);
   END;
$$;


ALTER FUNCTION testgen.fn_charcount(instring character varying, searchstring character varying) OWNER TO admin;

--
-- Name: fn_count_intersecting_items(character varying, character varying, character varying); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_count_intersecting_items(list1 character varying, list2 character varying, separator character varying) RETURNS bigint
    LANGUAGE sql
    AS $$
SELECT COUNT(*)
FROM (
    SELECT unnest(string_to_array(list1, separator)) AS element
    INTERSECT
    SELECT unnest(string_to_array(list2, separator))
) AS intersection
$$;


ALTER FUNCTION testgen.fn_count_intersecting_items(list1 character varying, list2 character varying, separator character varying) OWNER TO admin;

--
-- Name: fn_eval(text); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_eval(expression text) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
DECLARE
   result FLOAT;
   invalid_parts TEXT;
BEGIN
   -- Check the modified expression for invalid characters, allowing colons
   IF expression ~* E'[^0-9+\\-*/(),.\\sA-Z_:e\\\'"]' THEN
      RAISE EXCEPTION 'Invalid characters detected in expression: %', expression;
   END IF;

   -- Check for dangerous PostgreSQL-specific keywords
   IF expression ~* E'\b(DROP|ALTER|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE|COPY|EXECUTE|CREATE|COMMENT|SECURITY|WITH|SET ROLE|SET SESSION|DO|CALL|--|/\\*|;|pg_read_file|pg_write_file|pg_terminate_backend)\b' THEN
      RAISE EXCEPTION 'Invalid expression: dangerous statement detected';
   END IF;

   -- Remove all allowed tokens from the validation expression, treating 'FLOAT' as a keyword
   invalid_parts := regexp_replace(
      expression,
      E'(\\mGREATEST|LEAST|ABS|FN_NORMAL_CDF|DATEDIFF|DAY|FLOAT)\\M|[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?|[+\\-*/(),\\\'":]+|\\s+',
      '',
      'gi'
   );

   -- If anything is left in the validation expression, it's invalid
   IF invalid_parts <> '' THEN
      RAISE EXCEPTION 'Invalid expression contains invalid tokens "%" in expression: %', invalid_parts, expression;
   END IF;

   -- Use the original expression (with ::FLOAT) for execution
   EXECUTE format('SELECT (%s)::FLOAT', expression) INTO result;

   RETURN result;
END;
$$;


ALTER FUNCTION testgen.fn_eval(expression text) OWNER TO admin;

--
-- Name: fn_extract_distinct_items(character varying, character varying); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_extract_distinct_items(list character varying, separator character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
SELECT STRING_AGG(DISTINCT element, separator) as distinct_items
FROM (
    SELECT unnest(string_to_array(list, separator)) AS element
) AS all_items
$$;


ALTER FUNCTION testgen.fn_extract_distinct_items(list character varying, separator character varying) OWNER TO admin;

--
-- Name: fn_extract_intersecting_items(character varying, character varying, character varying); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_extract_intersecting_items(list1 character varying, list2 character varying, separator character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
SELECT STRING_AGG(DISTINCT element, separator) as shared_vals
FROM (
    SELECT unnest(string_to_array(list1, separator)) AS element
    INTERSECT
    SELECT unnest(string_to_array(list2, separator))
) AS intersection
$$;


ALTER FUNCTION testgen.fn_extract_intersecting_items(list1 character varying, list2 character varying, separator character varying) OWNER TO admin;

--
-- Name: fn_extract_top_values(text); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_extract_top_values(input_string text) RETURNS text
    LANGUAGE sql
    AS $$
SELECT string_agg(trim(split_part(value, '|', 2)), '|') AS values_only
FROM (
  SELECT unnest(regexp_split_to_array(input_string, E'\n')) AS value
) AS t
WHERE trim(value) <> ''
$$;


ALTER FUNCTION testgen.fn_extract_top_values(input_string text) OWNER TO admin;

--
-- Name: fn_format_csv_no_quotes(text); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_format_csv_no_quotes(str_csv text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT
        REGEXP_REPLACE(
                       REGEXP_REPLACE(str_csv::VARCHAR, '''', '', 'g'),  -- Remove single quotes
                       '\s*,\s*',  -- Match comma, with or without surrounding spaces
                       ', ',       -- Replace with comma followed by a space
                       'g'         -- Global replace
                      ) AS formatted_value
$$;


ALTER FUNCTION testgen.fn_format_csv_no_quotes(str_csv text) OWNER TO admin;

--
-- Name: fn_format_csv_quotes(text); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_format_csv_quotes(str_csv text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT
       '''' || REGEXP_REPLACE(str_csv::VARCHAR, '\s*,\s*', ''', ''', 'g') || ''''
   AS formatted_value
$$;


ALTER FUNCTION testgen.fn_format_csv_quotes(str_csv text) OWNER TO admin;

--
-- Name: fn_normal_cdf(double precision); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_normal_cdf(z_score double precision) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
/*
    This function calculates the cumulative distribution function (CDF)
    for the standard normal distribution for a given Z-score using
    the Abramowitz and Stegun approximation method. It returns the
    probability that a standard normal variable is less than or equal
    to the given Z-score.

    The approximation formula uses a series expansion to estimate the
    CDF, which is accurate for most practical purposes.
    
    To estimate the count of observations that fall outside a certain Z-score
    (both above and below), you can use the `normal_cdf()` function. For a
    total number of observations N, the proportion of values outside the Z-score
    is given by:  2 * (1 - normal_cdf(ABS(Z)))

    This gives the proportion of values greater than the positive Z-score and
    less than the negative Z-score combined. To get the estimated count of
    observations, multiply this proportion by N:   N * 2 * (1 - normal_cdf(ABS(Z)))
*/
DECLARE
    t DOUBLE PRECISION;
    cdf DOUBLE PRECISION;
BEGIN
    t := 1.0 / (1.0 + 0.2316419 * ABS(z_score));

    cdf := (1.0 / SQRT(2 * PI())) * EXP(-0.5 * z_score * z_score) *
           (0.319381530 * t
            - 0.356563782 * t * t
            + 1.781477937 * t * t * t
            - 1.821255978 * t * t * t * t
            + 1.330274429 * t * t * t * t * t);

    IF z_score >= 0 THEN
        RETURN 1.0 - cdf;
    ELSE
        RETURN cdf;
    END IF;
END;
$$;


ALTER FUNCTION testgen.fn_normal_cdf(z_score double precision) OWNER TO admin;

--
-- Name: fn_parsefreq(character varying, integer, integer); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_parsefreq(top_freq_values character varying, rowno integer, colno integer) RETURNS character varying
    LANGUAGE sql STABLE
    AS $$
    WITH first AS
    (
        SELECT SPLIT_PART(top_freq_values, CHR(10), rowno) AS first_row
    )
    SELECT
        CASE
            WHEN colno = 1 THEN CAST(TRIM(LEADING '|' FROM SUBSTRING(first_row, POSITION('|' IN first_row), LENGTH(first_row) - POSITION('|' IN REVERSE(first_row)))) AS VARCHAR)
            WHEN colno = 2 THEN CAST(TRIM(SUBSTRING(first_row, LENGTH(first_row) - POSITION('|' IN REVERSE(first_row)) + 2)) AS VARCHAR)
            ELSE NULL
            END
    FROM first
$$;


ALTER FUNCTION testgen.fn_parsefreq(top_freq_values character varying, rowno integer, colno integer) OWNER TO admin;

--
-- Name: fn_pct(numeric, numeric, integer); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_pct(numerator numeric, denominator numeric, decs integer DEFAULT 0) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
   BEGIN
      RETURN ROUND((100.0 * numerator/denominator), decs);
   END;
$$;


ALTER FUNCTION testgen.fn_pct(numerator numeric, denominator numeric, decs integer) OWNER TO admin;

--
-- Name: fn_prepcolumnname(text); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_prepcolumnname(value_to_check text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    keyword_arr TEXT[] := ARRAY ['ALL', 'ALTER', 'ANALYSE', 'ANALYZE', 'AND', 'ANY', 'ARRAY', 'AS', 'ASC', 'ASYMMETRIC',
                                 'AUTHORIZATION', 'BINARY', 'BOTH', 'CASE', 'CAST', 'CHECK', 'COLLATE', 'COLLATION',
                                 'COLUMN', 'CONCURRENTLY', 'CONSTRAINT', 'CREATE', 'CROSS', 'CURRENT_CATALOG',
                                 'CURRENT_DATE', 'CURRENT_ROLE', 'CURRENT_SCHEMA', 'CURRENT_TIME', 'CURRENT_TIMESTAMP',
                                 'CURRENT_USER', 'CREDENTIALS',
                                 'DEFAULT', 'DEFERRABLE', 'DESC', 'DISTINCT', 'DO', 'DROP',
                                 'ELSE', 'END', 'EXCEPT', 'FALSE', 'FETCH', 'FOR', 'FOREIGN', 'FREEZE', 'FROM', 'FULL',
                                 'GRANT', 'GROUP', 'HAVING', 'ILIKE', 'IN', 'INITIALLY', 'INNER', 'INTERSECT', 'INTO',
                                 'IS', 'ISNULL', 'JOIN', 'LATERAL', 'LEADING', 'LEFT', 'LIKE', 'LIMIT', 'LOCALTIME',
                                 'LOCALTIMESTAMP', 'NATURAL', 'NOT', 'NOTNULL', 'NULL', 'OFFSET', 'ON', 'ONLY', 'OR',
                                 'ORDER', 'OUTER', 'OVERLAPS', 'PLACING', 'PRIMARY', 'REFERENCES', 'RETURNING', 'RIGHT',
                                 'SELECT', 'SESSION_USER', 'SIMILAR', 'SOME', 'SYMMETRIC', 'TABLE', 'TABLESAMPLE',
                                 'THEN', 'TIMESTAMP', 'TIMEZONE', 'TO', 'TRAILING', 'TRUE', 'UNION', 'UNIQUE', 'USER', 'USING',
                                 'VARIADIC', 'VERBOSE', 'WHEN', 'WHERE', 'WINDOW', 'WITH']; -- Add more keywords here
BEGIN
    -- Check if the value matches any of the keywords (case-insensitive)
    IF value_to_check ILIKE ANY (keyword_arr) THEN
        RETURN '"' || value_to_check || '"';
    -- Check if the value contains a space or a comma or it starts with a number
    ELSIF value_to_check !~ '^[a-zA-Z_][a-zA-Z0-9_]*$' THEN
        RETURN '"' || value_to_check || '"';
    ELSE
        RETURN value_to_check;
    END IF;
END;
$_$;


ALTER FUNCTION testgen.fn_prepcolumnname(value_to_check text) OWNER TO admin;

--
-- Name: fn_quote_literal_escape(character varying, character varying); Type: FUNCTION; Schema: testgen; Owner: admin
--

CREATE FUNCTION testgen.fn_quote_literal_escape(var_value character varying, sql_flavor character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    escaped_value         varchar;
    lower_case_sql_flavor varchar;
BEGIN
    lower_case_sql_flavor := LOWER(sql_flavor);

    IF lower_case_sql_flavor = 'postgres'  OR lower_case_sql_flavor = 'postgresql' THEN
        escaped_value := QUOTE_LITERAL(var_value);
    ELSIF lower_case_sql_flavor = 'redshift' OR lower_case_sql_flavor = 'snowflake' THEN
        escaped_value := TRIM(LEADING 'E' FROM QUOTE_LITERAL(var_value));
    ELSIF lower_case_sql_flavor = 'mssql' THEN
        escaped_value := '''' || REPLACE(var_value, '''', '''''') || '''';
    ELSE
        RAISE EXCEPTION 'Invalid sql_flavor name: %', sql_flavor;
    END IF;

    RETURN escaped_value;
END;
$$;


ALTER FUNCTION testgen.fn_quote_literal_escape(var_value character varying, sql_flavor character varying) OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auth_users; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.auth_users (
    id uuid DEFAULT gen_random_uuid(),
    username character varying(20),
    email character varying(120),
    name character varying(120),
    password character varying(120),
    preauthorized boolean DEFAULT true,
    role character varying(20),
    CONSTRAINT username_check CHECK (((length((username)::text) >= 4) AND (length((username)::text) <= 20) AND ((username)::text ~ '^[a-zA-Z0-9_]+$'::text)))
);


ALTER TABLE testgen.auth_users OWNER TO admin;

--
-- Name: cat_test_conditions; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.cat_test_conditions (
    id character varying,
    test_type character varying(200) NOT NULL,
    sql_flavor character varying(20) NOT NULL,
    measure character varying(2000),
    test_operator character varying(20),
    test_condition character varying(2000)
);


ALTER TABLE testgen.cat_test_conditions OWNER TO admin;

--
-- Name: connections; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.connections (
    id uuid DEFAULT gen_random_uuid(),
    project_code character varying(30),
    connection_id bigint NOT NULL,
    sql_flavor character varying(30),
    project_host character varying(250),
    project_port character varying(5),
    project_user character varying(50),
    project_db character varying(100),
    connection_name character varying(40),
    project_pw_encrypted bytea,
    max_threads integer DEFAULT 4,
    max_query_chars integer,
    url character varying(200) DEFAULT ''::character varying,
    connect_by_url boolean DEFAULT false,
    connect_by_key boolean DEFAULT false,
    private_key bytea,
    private_key_passphrase bytea
);


ALTER TABLE testgen.connections OWNER TO admin;

--
-- Name: connections_connection_id_seq; Type: SEQUENCE; Schema: testgen; Owner: admin
--

ALTER TABLE testgen.connections ALTER COLUMN connection_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME testgen.connections_connection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: data_column_chars; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.data_column_chars (
    column_id uuid DEFAULT gen_random_uuid(),
    table_id uuid,
    table_groups_id uuid,
    schema_name character varying(50),
    table_name character varying(120),
    column_name character varying(120),
    general_type character varying(1),
    column_type character varying(50),
    functional_data_type character varying(50),
    critical_data_element boolean,
    data_source character varying(40),
    source_system character varying(40),
    source_process character varying(40),
    business_domain character varying(40),
    stakeholder_group character varying(40),
    transform_level character varying(40),
    aggregation_level character varying(40),
    add_date timestamp without time zone,
    last_mod_date timestamp without time zone,
    drop_date timestamp without time zone,
    test_ct integer,
    last_test_date timestamp without time zone,
    tests_last_run integer,
    tests_7_days_prior integer,
    tests_30_days_prior integer,
    fails_last_run integer,
    fails_7_days_prior integer,
    fails_30_days_prior integer,
    warnings_last_run integer,
    warnings_7_days_prior integer,
    warnings_30_days_prior integer,
    last_complete_profile_run_id uuid,
    dq_score_profiling double precision,
    dq_score_testing double precision
);


ALTER TABLE testgen.data_column_chars OWNER TO admin;

--
-- Name: data_structure_log; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.data_structure_log (
    project_code character varying(30),
    connection_id bigint,
    change_date timestamp without time zone,
    schema_name character varying(50),
    table_name character varying(100),
    ordinal_position integer,
    column_name character varying(100),
    data_type character varying(50),
    status character varying(10)
);


ALTER TABLE testgen.data_structure_log OWNER TO admin;

--
-- Name: data_table_chars; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.data_table_chars (
    table_id uuid DEFAULT gen_random_uuid(),
    table_groups_id uuid,
    schema_name character varying(50),
    table_name character varying(120),
    functional_table_type character varying(50),
    critical_data_element boolean,
    data_source character varying(40),
    source_system character varying(40),
    source_process character varying(40),
    business_domain character varying(40),
    stakeholder_group character varying(40),
    transform_level character varying(40),
    aggregation_level character varying(40),
    add_date timestamp without time zone,
    drop_date timestamp without time zone,
    record_ct bigint,
    column_ct bigint,
    data_point_ct bigint,
    last_complete_profile_run_id uuid,
    dq_score_profiling double precision,
    dq_score_testing double precision
);


ALTER TABLE testgen.data_table_chars OWNER TO admin;

--
-- Name: functional_test_results; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.functional_test_results (
    test_name character varying(50),
    error_ct bigint
);


ALTER TABLE testgen.functional_test_results OWNER TO admin;

--
-- Name: generation_sets; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.generation_sets (
    generation_set character varying NOT NULL,
    test_type character varying NOT NULL
);


ALTER TABLE testgen.generation_sets OWNER TO admin;

--
-- Name: profile_anomaly_results; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.profile_anomaly_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_code character varying(30),
    table_groups_id uuid,
    profile_run_id uuid,
    column_id uuid,
    schema_name character varying(50),
    table_name character varying(120),
    column_name character varying(500),
    column_type character varying(50),
    anomaly_id character varying(10),
    detail character varying,
    disposition character varying(20),
    dq_prevalence double precision
);


ALTER TABLE testgen.profile_anomaly_results OWNER TO admin;

--
-- Name: profile_anomaly_types; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.profile_anomaly_types (
    id character varying(10) NOT NULL,
    anomaly_type character varying(200) NOT NULL,
    data_object character varying(10),
    anomaly_name character varying(100),
    anomaly_description character varying(500),
    anomaly_criteria character varying(2000),
    detail_expression character varying(2000),
    issue_likelihood character varying(50),
    suggested_action character varying(1000),
    dq_score_prevalence_formula text,
    dq_score_risk_factor text
);


ALTER TABLE testgen.profile_anomaly_types OWNER TO admin;

--
-- Name: profile_pair_rules; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.profile_pair_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_run_id uuid,
    schema_name character varying(50),
    table_name character varying(120),
    cause_column_name character varying(500),
    cause_column_value character varying,
    effect_column_name character varying(500),
    effect_column_value character varying,
    pair_count bigint,
    cause_column_total bigint,
    effect_column_total bigint,
    rule_ratio numeric(6,4)
);


ALTER TABLE testgen.profile_pair_rules OWNER TO admin;

--
-- Name: profile_results; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.profile_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dk_id bigint NOT NULL,
    project_code character varying(30),
    connection_id bigint,
    table_groups_id uuid,
    profile_run_id uuid,
    schema_name character varying(50),
    run_date timestamp without time zone,
    table_name character varying(120),
    "position" integer,
    column_name character varying(120),
    column_type character varying(50),
    general_type character varying(1),
    record_ct bigint,
    value_ct bigint,
    distinct_value_ct bigint,
    distinct_std_value_ct bigint,
    null_value_ct bigint,
    min_length integer,
    max_length integer,
    avg_length double precision,
    zero_value_ct bigint,
    zero_length_ct bigint,
    lead_space_ct bigint,
    quoted_value_ct bigint,
    includes_digit_ct bigint,
    filled_value_ct bigint,
    min_text character varying(1000),
    max_text character varying(1000),
    upper_case_ct bigint,
    lower_case_ct bigint,
    non_alpha_ct bigint,
    mixed_case_ct bigint GENERATED ALWAYS AS ((((value_ct - upper_case_ct) - lower_case_ct) - non_alpha_ct)) STORED,
    numeric_ct bigint,
    date_ct bigint,
    top_patterns character varying(1000),
    top_freq_values character varying(1500),
    distinct_value_hash character varying(40),
    min_value double precision,
    min_value_over_0 double precision,
    max_value double precision,
    avg_value double precision,
    stdev_value double precision,
    percentile_25 double precision,
    percentile_50 double precision,
    percentile_75 double precision,
    fractional_sum numeric(38,6),
    min_date timestamp without time zone,
    max_date timestamp without time zone,
    before_1yr_date_ct bigint,
    before_5yr_date_ct bigint,
    before_20yr_date_ct bigint,
    before_100yr_date_ct bigint,
    within_1yr_date_ct bigint,
    within_1mo_date_ct bigint,
    future_date_ct bigint,
    distant_future_date_ct bigint,
    date_days_present bigint,
    date_weeks_present bigint,
    date_months_present bigint,
    boolean_true_ct bigint,
    datatype_suggestion character varying(50),
    distinct_pattern_ct bigint,
    embedded_space_ct bigint,
    avg_embedded_spaces double precision,
    std_pattern_match character varying(30),
    pii_flag character varying(50),
    functional_data_type character varying(50),
    functional_table_type character varying(50),
    sample_ratio double precision
);


ALTER TABLE testgen.profile_results OWNER TO admin;

--
-- Name: profile_results_dk_id_seq; Type: SEQUENCE; Schema: testgen; Owner: admin
--

CREATE SEQUENCE testgen.profile_results_dk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE testgen.profile_results_dk_id_seq OWNER TO admin;

--
-- Name: profile_results_dk_id_seq; Type: SEQUENCE OWNED BY; Schema: testgen; Owner: admin
--

ALTER SEQUENCE testgen.profile_results_dk_id_seq OWNED BY testgen.profile_results.dk_id;


--
-- Name: profile_results_dk_id_seq1; Type: SEQUENCE; Schema: testgen; Owner: admin
--

ALTER TABLE testgen.profile_results ALTER COLUMN dk_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME testgen.profile_results_dk_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: profiling_runs; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.profiling_runs (
    id uuid NOT NULL,
    project_code character varying(30) NOT NULL,
    connection_id bigint NOT NULL,
    table_groups_id uuid NOT NULL,
    profiling_starttime timestamp without time zone,
    profiling_endtime timestamp without time zone,
    status character varying(100) DEFAULT 'Running'::character varying,
    log_message character varying,
    table_ct bigint,
    column_ct bigint,
    anomaly_ct bigint,
    anomaly_table_ct bigint,
    anomaly_column_ct bigint,
    dq_affected_data_points bigint,
    dq_total_data_points bigint,
    dq_score_profiling double precision,
    process_id integer
);


ALTER TABLE testgen.profiling_runs OWNER TO admin;

--
-- Name: projects; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.projects (
    id uuid DEFAULT gen_random_uuid(),
    project_code character varying(30) NOT NULL,
    project_name character varying(50),
    effective_from_date date,
    effective_thru_date date,
    observability_api_key text,
    observability_api_url text DEFAULT ''::text
);


ALTER TABLE testgen.projects OWNER TO admin;

--
-- Name: stg_functional_table_updates; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.stg_functional_table_updates (
    project_code character varying(30),
    schema_name character varying(50),
    run_date timestamp without time zone,
    table_name character varying(120),
    table_period character varying(10),
    table_type character varying(11)
);


ALTER TABLE testgen.stg_functional_table_updates OWNER TO admin;

--
-- Name: stg_secondary_profile_updates; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.stg_secondary_profile_updates (
    project_code character varying(30),
    schema_name character varying(50),
    run_date timestamp without time zone,
    table_name character varying(120),
    column_name character varying(120),
    top_freq_values character varying(1500),
    distinct_value_hash character varying(40)
);


ALTER TABLE testgen.stg_secondary_profile_updates OWNER TO admin;

--
-- Name: table_groups; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.table_groups (
    id uuid DEFAULT gen_random_uuid(),
    project_code character varying(30),
    connection_id bigint,
    table_groups_name character varying(100),
    table_group_schema character varying(100),
    profiling_table_set character varying(2000),
    profiling_include_mask character varying(2000),
    profiling_exclude_mask character varying(2000),
    profile_id_column_mask character varying(2000) DEFAULT '%id'::character varying(2000),
    profile_sk_column_mask character varying(150) DEFAULT '%_sk'::character varying,
    profile_use_sampling character varying(3) DEFAULT 'N'::character varying,
    profile_sample_percent character varying(3) DEFAULT '30'::character varying,
    profile_sample_min_count bigint DEFAULT 100000,
    profiling_delay_days character varying(3) DEFAULT '0'::character varying,
    profile_do_pair_rules character varying(3) DEFAULT 'N'::character varying,
    profile_pair_rule_pct integer DEFAULT 95,
    data_source character varying(40),
    source_system character varying(40),
    data_location character varying(40),
    source_process character varying(40),
    business_domain character varying(40),
    stakeholder_group character varying(40),
    transform_level character varying(40),
    last_complete_profile_run_id uuid,
    dq_score_profiling double precision,
    dq_score_testing double precision
);


ALTER TABLE testgen.table_groups OWNER TO admin;

--
-- Name: target_data_lookups; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.target_data_lookups (
    id character varying,
    test_id character varying,
    test_type character varying(200) NOT NULL,
    sql_flavor character varying(20) NOT NULL,
    lookup_type character varying(10),
    lookup_query character varying,
    error_type character varying(30) NOT NULL
);


ALTER TABLE testgen.target_data_lookups OWNER TO admin;

--
-- Name: test_definitions; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.test_definitions (
    id uuid DEFAULT gen_random_uuid(),
    cat_test_id bigint NOT NULL,
    table_groups_id uuid,
    profile_run_id uuid,
    test_type character varying(200),
    test_suite_id uuid NOT NULL,
    test_description character varying(1000),
    test_action character varying(100),
    schema_name character varying(100),
    table_name character varying(100),
    column_name character varying(500),
    skip_errors integer,
    baseline_ct character varying(1000),
    baseline_unique_ct character varying(1000),
    baseline_value character varying(1000),
    baseline_value_ct character varying(1000),
    threshold_value character varying(1000),
    baseline_sum character varying(1000),
    baseline_avg character varying(1000),
    baseline_sd character varying(1000),
    subset_condition character varying(500),
    groupby_names character varying(200),
    having_condition character varying(500),
    window_date_column character varying(100),
    window_days integer,
    match_schema_name character varying(100),
    match_table_name character varying(100),
    match_column_names character varying(200),
    match_subset_condition character varying(500),
    match_groupby_names character varying(200),
    match_having_condition character varying(500),
    test_mode character varying(20),
    custom_query character varying,
    test_active character varying(10) DEFAULT 'Y'::character varying,
    test_definition_status character varying(200),
    severity character varying(10),
    watch_level character varying(10) DEFAULT 'WARN'::character varying,
    check_result character varying(500),
    lock_refresh character varying(10) DEFAULT 'N'::character varying NOT NULL,
    last_auto_gen_date timestamp without time zone,
    profiling_as_of_date timestamp without time zone,
    last_manual_update timestamp without time zone,
    export_to_observability character varying(5)
);


ALTER TABLE testgen.test_definitions OWNER TO admin;

--
-- Name: test_definitions_cat_test_id_seq; Type: SEQUENCE; Schema: testgen; Owner: admin
--

CREATE SEQUENCE testgen.test_definitions_cat_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE testgen.test_definitions_cat_test_id_seq OWNER TO admin;

--
-- Name: test_definitions_cat_test_id_seq; Type: SEQUENCE OWNED BY; Schema: testgen; Owner: admin
--

ALTER SEQUENCE testgen.test_definitions_cat_test_id_seq OWNED BY testgen.test_definitions.cat_test_id;


--
-- Name: test_definitions_cat_test_id_seq1; Type: SEQUENCE; Schema: testgen; Owner: admin
--

ALTER TABLE testgen.test_definitions ALTER COLUMN cat_test_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME testgen.test_definitions_cat_test_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: test_results; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.test_results (
    id uuid DEFAULT gen_random_uuid(),
    result_id bigint NOT NULL,
    test_type character varying(50),
    test_suite_id uuid NOT NULL,
    test_definition_id uuid,
    auto_gen boolean,
    test_time timestamp without time zone,
    starttime timestamp without time zone,
    endtime timestamp without time zone,
    schema_name character varying(100),
    table_name character varying(100),
    column_names character varying(500),
    skip_errors integer,
    input_parameters character varying(1000),
    result_code integer,
    severity character varying(10),
    result_status character varying(10),
    result_message character varying(1000),
    result_measure character varying(1000),
    threshold_value character varying(1000),
    result_error_data character varying(4000),
    test_action character varying(100),
    disposition character varying(20),
    subset_condition character varying(500),
    result_query character varying(4000),
    test_description character varying(1000),
    test_run_id uuid NOT NULL,
    table_groups_id uuid,
    dq_prevalence double precision,
    dq_record_ct bigint,
    observability_status character varying(10)
);


ALTER TABLE testgen.test_results OWNER TO admin;

--
-- Name: test_results_result_id_seq; Type: SEQUENCE; Schema: testgen; Owner: admin
--

ALTER TABLE testgen.test_results ALTER COLUMN result_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME testgen.test_results_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: test_runs; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.test_runs (
    id uuid NOT NULL,
    test_suite_id uuid NOT NULL,
    test_starttime timestamp without time zone,
    test_endtime timestamp without time zone,
    status character varying(100) DEFAULT 'Running'::character varying,
    log_message text,
    duration character varying(50),
    test_ct integer,
    passed_ct integer,
    failed_ct integer,
    warning_ct integer,
    error_ct integer,
    table_ct integer,
    column_ct integer,
    column_failed_ct integer,
    column_warning_ct integer,
    dq_affected_data_points bigint,
    dq_total_data_points bigint,
    dq_score_test_run double precision,
    process_id integer
);


ALTER TABLE testgen.test_runs OWNER TO admin;

--
-- Name: test_suites; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.test_suites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_code character varying(30) NOT NULL,
    test_suite character varying(200) NOT NULL,
    connection_id bigint,
    table_groups_id uuid,
    test_suite_description character varying(1000),
    test_action character varying(100),
    severity character varying(10),
    export_to_observability character varying(5) DEFAULT 'Y'::character varying,
    test_suite_schema character varying(100),
    component_key character varying(100),
    component_type character varying(100),
    component_name character varying(100),
    last_complete_test_run_id uuid,
    dq_score_exclude boolean DEFAULT false
);


ALTER TABLE testgen.test_suites OWNER TO admin;

--
-- Name: test_templates; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.test_templates (
    id character varying,
    test_type character varying(200) NOT NULL,
    sql_flavor character varying(20) NOT NULL,
    template_name character varying(400)
);


ALTER TABLE testgen.test_templates OWNER TO admin;

--
-- Name: test_types; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.test_types (
    id character varying,
    test_type character varying(200) NOT NULL,
    test_name_short character varying(30),
    test_name_long character varying(100),
    test_description character varying(1000),
    except_message character varying(1000),
    measure_uom character varying(100),
    measure_uom_description character varying(200),
    selection_criteria text,
    dq_score_prevalence_formula text,
    dq_score_risk_factor text,
    column_name_prompt text,
    column_name_help text,
    default_parm_columns text,
    default_parm_values text,
    default_parm_prompts text,
    default_parm_help text,
    default_severity character varying(10),
    run_type character varying(10),
    test_scope character varying,
    dq_dimension character varying(50),
    health_dimension character varying(50),
    threshold_description character varying(200),
    usage_notes character varying,
    active character varying
);


ALTER TABLE testgen.test_types OWNER TO admin;

--
-- Name: tg_revision; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.tg_revision (
    component character varying(50) NOT NULL,
    revision integer
);


ALTER TABLE testgen.tg_revision OWNER TO admin;

--
-- Name: v_inactive_anomalies; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_inactive_anomalies AS
 SELECT DISTINCT profile_anomaly_results.anomaly_id,
    profile_anomaly_results.table_groups_id,
    profile_anomaly_results.schema_name,
    profile_anomaly_results.table_name,
    profile_anomaly_results.column_name,
    profile_anomaly_results.column_id
   FROM testgen.profile_anomaly_results
  WHERE ((profile_anomaly_results.disposition)::text = 'Inactive'::text);


ALTER TABLE testgen.v_inactive_anomalies OWNER TO admin;

--
-- Name: v_latest_profile_anomalies; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_latest_profile_anomalies AS
 WITH last_profile_date AS (
         SELECT profiling_runs.table_groups_id,
            max(profiling_runs.profiling_starttime) AS last_profile_run_date
           FROM testgen.profiling_runs
          GROUP BY profiling_runs.table_groups_id
        )
 SELECT r.id,
    r.project_code,
    r.table_groups_id,
    r.profile_run_id,
    pr.profiling_starttime AS profile_run_date,
    r.schema_name,
    r.table_name,
    r.column_name,
    r.column_type,
    t.anomaly_name,
    t.anomaly_description,
    t.issue_likelihood,
    r.detail,
    t.suggested_action,
    r.disposition
   FROM (((testgen.profile_anomaly_results r
     JOIN testgen.profile_anomaly_types t ON (((r.anomaly_id)::text = (t.id)::text)))
     JOIN testgen.profiling_runs pr ON ((r.profile_run_id = pr.id)))
     JOIN last_profile_date l ON (((pr.table_groups_id = l.table_groups_id) AND (pr.profiling_starttime = l.last_profile_run_date))));


ALTER TABLE testgen.v_latest_profile_anomalies OWNER TO admin;

--
-- Name: v_latest_profile_results; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_latest_profile_results AS
 WITH last_run AS (
         SELECT profiling_runs.table_groups_id,
            max(profiling_runs.profiling_starttime) AS last_run_date
           FROM testgen.profiling_runs
          GROUP BY profiling_runs.table_groups_id
        )
 SELECT r.id,
    r.dk_id,
    r.project_code,
    r.connection_id,
    r.table_groups_id,
    r.profile_run_id,
    r.schema_name,
    r.run_date,
    r.table_name,
    r."position",
    r.column_name,
    r.column_type,
    r.general_type,
    r.record_ct,
    r.value_ct,
    r.distinct_value_ct,
    r.distinct_std_value_ct,
    r.null_value_ct,
    r.min_length,
    r.max_length,
    r.avg_length,
    r.zero_value_ct,
    r.zero_length_ct,
    r.lead_space_ct,
    r.quoted_value_ct,
    r.includes_digit_ct,
    r.filled_value_ct,
    r.min_text,
    r.max_text,
    r.upper_case_ct,
    r.lower_case_ct,
    r.non_alpha_ct,
    r.mixed_case_ct,
    r.numeric_ct,
    r.date_ct,
    r.top_patterns,
    r.top_freq_values,
    r.distinct_value_hash,
    r.min_value,
    r.min_value_over_0,
    r.max_value,
    r.avg_value,
    r.stdev_value,
    r.percentile_25,
    r.percentile_50,
    r.percentile_75,
    r.fractional_sum,
    r.min_date,
    r.max_date,
    r.before_1yr_date_ct,
    r.before_5yr_date_ct,
    r.before_20yr_date_ct,
    r.before_100yr_date_ct,
    r.within_1yr_date_ct,
    r.within_1mo_date_ct,
    r.future_date_ct,
    r.distant_future_date_ct,
    r.date_days_present,
    r.date_weeks_present,
    r.date_months_present,
    r.boolean_true_ct,
    r.datatype_suggestion,
    r.distinct_pattern_ct,
    r.embedded_space_ct,
    r.avg_embedded_spaces,
    r.std_pattern_match,
    r.pii_flag,
    r.functional_data_type,
    r.functional_table_type,
    r.sample_ratio
   FROM ((last_run lr
     JOIN testgen.profiling_runs p ON (((lr.table_groups_id = p.table_groups_id) AND (lr.last_run_date = p.profiling_starttime))))
     JOIN testgen.profile_results r ON ((p.id = r.profile_run_id)));


ALTER TABLE testgen.v_latest_profile_results OWNER TO admin;

--
-- Name: v_profiling_runs; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_profiling_runs AS
SELECT
    NULL::uuid AS profiling_run_id,
    NULL::character varying(30) AS project_code,
    NULL::character varying(40) AS connection_name,
    NULL::bigint AS connection_id,
    NULL::uuid AS table_groups_id,
    NULL::character varying(100) AS table_groups_name,
    NULL::character varying(100) AS schema_name,
    NULL::timestamp without time zone AS start_time,
    NULL::text AS duration,
    NULL::character varying(100) AS status,
    NULL::character varying AS log_message,
    NULL::bigint AS table_ct,
    NULL::bigint AS column_ct,
    NULL::bigint AS anomaly_ct,
    NULL::bigint AS anomaly_table_ct,
    NULL::bigint AS anomaly_column_ct,
    NULL::integer AS process_id;


ALTER TABLE testgen.v_profiling_runs OWNER TO admin;

--
-- Name: v_queued_observability_results; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_queued_observability_results AS
 SELECT p.project_name,
    cn.sql_flavor AS component_tool,
    ts.test_suite_schema AS schema,
    cn.connection_name,
    cn.project_db,
        CASE
            WHEN ((tg.profile_use_sampling)::text = 'Y'::text) THEN tg.profile_sample_min_count
            ELSE NULL::bigint
        END AS sample_min_count,
    tg.id AS group_id,
    ((tg.profile_use_sampling)::text = 'Y'::text) AS uses_sampling,
    ts.project_code,
        CASE
            WHEN ((tg.profile_use_sampling)::text = 'Y'::text) THEN tg.profile_sample_percent
            ELSE NULL::character varying
        END AS sample_percentage,
    tg.profiling_table_set,
    tg.profiling_include_mask,
    tg.profiling_exclude_mask,
    COALESCE(ts.component_type, 'dataset'::character varying) AS component_type,
    COALESCE(ts.component_key, (tg.id)::character varying) AS component_key,
    COALESCE(ts.component_name, tg.table_groups_name) AS component_name,
    r.column_names,
    r.table_name,
    ts.test_suite,
    ts.id AS test_suite_id,
    r.input_parameters,
    r.test_definition_id,
    tt.test_name_short AS type,
        CASE
            WHEN ((c.test_operator)::text = ANY ((ARRAY['>'::character varying, '>='::character varying])::text[])) THEN d.threshold_value
            ELSE NULL::character varying
        END AS min_threshold,
        CASE
            WHEN ((c.test_operator)::text = ANY ((ARRAY['<'::character varying, '<='::character varying])::text[])) THEN d.threshold_value
            ELSE NULL::character varying
        END AS max_threshold,
    tt.test_name_long AS name,
    tt.test_description AS description,
    r.test_time AS start_time,
    r.test_time AS end_time,
    r.result_message,
    tt.dq_dimension,
    r.result_status,
    r.result_id,
    r.result_measure AS metric_value,
    tt.measure_uom,
    tt.measure_uom_description
   FROM (((((((testgen.test_results r
     JOIN testgen.test_types tt ON (((r.test_type)::text = (tt.test_type)::text)))
     JOIN testgen.test_definitions d ON ((r.test_definition_id = d.id)))
     JOIN testgen.test_suites ts ON ((r.test_suite_id = ts.id)))
     JOIN testgen.table_groups tg ON ((d.table_groups_id = tg.id)))
     JOIN testgen.connections cn ON ((tg.connection_id = cn.connection_id)))
     JOIN testgen.projects p ON (((ts.project_code)::text = (p.project_code)::text)))
     JOIN testgen.cat_test_conditions c ON ((((cn.sql_flavor)::text = (c.sql_flavor)::text) AND ((d.test_type)::text = (c.test_type)::text))))
  WHERE ((r.observability_status)::text = 'Queued'::text);


ALTER TABLE testgen.v_queued_observability_results OWNER TO admin;

--
-- Name: v_test_results; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_test_results AS
 SELECT p.project_name,
    ts.test_suite,
    tg.table_groups_name,
    cn.connection_name,
    cn.project_host,
    cn.sql_flavor,
    tt.dq_dimension,
    r.schema_name,
    r.table_name,
    r.column_names,
    r.test_time AS test_date,
    r.test_type,
    tt.id AS test_type_id,
    tt.test_name_short,
    tt.test_name_long,
    r.test_description,
    tt.measure_uom,
    tt.measure_uom_description,
    c.test_operator,
    (r.threshold_value)::numeric(16,5) AS threshold_value,
    (r.result_measure)::numeric(16,5) AS result_measure,
    r.result_status,
    r.input_parameters,
    r.result_message,
        CASE
            WHEN (r.result_code <> 1) THEN r.severity
            ELSE NULL::character varying
        END AS severity,
        CASE
            WHEN (r.result_code <> 1) THEN r.disposition
            ELSE 'Passed'::character varying
        END AS disposition,
    r.result_code AS passed_ct,
    (1 - COALESCE(r.result_code, 0)) AS exception_ct,
        CASE
            WHEN (((r.result_status)::text = 'Warning'::text) AND ((r.result_message)::text !~~* 'Inactivated%'::text)) THEN 1
            ELSE NULL::integer
        END AS warning_ct,
        CASE
            WHEN (((r.result_status)::text = 'Failed'::text) AND ((r.result_message)::text !~~* 'Inactivated%'::text)) THEN 1
            ELSE NULL::integer
        END AS failed_ct,
        CASE
            WHEN ((r.result_message)::text ~~* 'Inactivated%'::text) THEN 1
            ELSE NULL::integer
        END AS execution_error_ct,
    p.project_code,
    r.table_groups_id,
    r.id AS test_result_id,
    c.id AS connection_id,
    r.test_suite_id,
    r.test_definition_id AS test_definition_id_runtime,
        CASE
            WHEN (r.auto_gen = true) THEN d.id
            ELSE r.test_definition_id
        END AS test_definition_id_current,
    r.test_run_id,
    r.auto_gen
   FROM (((((((testgen.test_results r
     JOIN testgen.test_types tt ON (((r.test_type)::text = (tt.test_type)::text)))
     LEFT JOIN testgen.test_definitions d ON (((r.test_suite_id = d.test_suite_id) AND ((r.table_name)::text = (d.table_name)::text) AND ((r.column_names)::text = (COALESCE(d.column_name, 'N/A'::character varying))::text) AND ((r.test_type)::text = (d.test_type)::text) AND (r.auto_gen = true) AND (d.last_auto_gen_date IS NOT NULL))))
     JOIN testgen.test_suites ts ON ((r.test_suite_id = ts.id)))
     JOIN testgen.projects p ON (((ts.project_code)::text = (p.project_code)::text)))
     JOIN testgen.table_groups tg ON ((r.table_groups_id = tg.id)))
     JOIN testgen.connections cn ON ((tg.connection_id = cn.connection_id)))
     LEFT JOIN testgen.cat_test_conditions c ON ((((cn.sql_flavor)::text = (c.sql_flavor)::text) AND ((r.test_type)::text = (c.test_type)::text))));


ALTER TABLE testgen.v_test_results OWNER TO admin;

--
-- Name: v_test_runs; Type: VIEW; Schema: testgen; Owner: admin
--

CREATE VIEW testgen.v_test_runs AS
 SELECT r.id AS test_run_id,
    p.project_code,
    p.project_name,
    ts.test_suite,
    r.test_starttime,
    to_char((r.test_endtime - r.test_starttime), 'HH24:MI:SS'::text) AS duration,
    r.status,
    r.log_message,
    count(*) AS test_ct,
    sum(tr.result_code) AS passed_ct,
    COALESCE(sum(
        CASE
            WHEN ((tr.result_status)::text = 'Failed'::text) THEN 1
            ELSE NULL::integer
        END), (0)::bigint) AS failed_ct,
    COALESCE(sum(
        CASE
            WHEN ((tr.result_status)::text = 'Warning'::text) THEN 1
            ELSE NULL::integer
        END), (0)::bigint) AS warning_ct,
    r.process_id
   FROM (((testgen.test_runs r
     JOIN testgen.test_suites ts ON ((r.test_suite_id = ts.id)))
     JOIN testgen.projects p ON (((ts.project_code)::text = (p.project_code)::text)))
     JOIN testgen.test_results tr ON ((r.id = tr.test_run_id)))
  GROUP BY r.id, p.project_code, ts.test_suite, r.test_starttime, r.test_endtime, r.process_id, r.status, r.log_message, p.project_name;


ALTER TABLE testgen.v_test_runs OWNER TO admin;

--
-- Name: variant_codings; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.variant_codings (
    value_type character varying,
    check_values character varying
);


ALTER TABLE testgen.variant_codings OWNER TO admin;

--
-- Name: working_agg_cat_results; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.working_agg_cat_results (
    test_run_id uuid NOT NULL,
    schema_name character varying(200) NOT NULL,
    table_name character varying(200) NOT NULL,
    cat_sequence integer NOT NULL,
    measure_results text,
    test_results text
);


ALTER TABLE testgen.working_agg_cat_results OWNER TO admin;

--
-- Name: working_agg_cat_tests; Type: TABLE; Schema: testgen; Owner: admin
--

CREATE TABLE testgen.working_agg_cat_tests (
    test_run_id uuid NOT NULL,
    schema_name character varying(200) NOT NULL,
    table_name character varying(200) NOT NULL,
    cat_sequence integer NOT NULL,
    test_count integer,
    test_time timestamp without time zone,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    column_names text,
    test_types text,
    test_definition_ids text,
    test_actions text,
    test_descriptions text,
    test_parms text,
    test_measures text,
    test_conditions text
);


ALTER TABLE testgen.working_agg_cat_tests OWNER TO admin;

--
-- Data for Name: auth_users; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.auth_users (id, username, email, name, password, preauthorized, role) FROM stdin;
dec82642-b632-4913-ad9c-bbd534e02d03	admin		admin	$2b$12$1TdU4.cHTNjjGgYsdn7R8er4WCPvpnqOaFZjn2qsb5UM3NVfo/iZW	true	admin
\.


--
-- Data for Name: cat_test_conditions; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.cat_test_conditions (id, test_type, sql_flavor, measure, test_operator, test_condition) FROM stdin;
1001	Alpha_Trunc	redshift	MAX(LENGTH({COLUMN_NAME}))	<	{THRESHOLD_VALUE}
1002	Avg_Shift	redshift	ABS( (AVG({COLUMN_NAME}::FLOAT) - {BASELINE_AVG}) / SQRT(((COUNT({COLUMN_NAME})::FLOAT-1)*STDDEV({COLUMN_NAME})^2 + ({BASELINE_VALUE_CT}::FLOAT-1) * {BASELINE_SD}::FLOAT^2) /NULLIF(COUNT({COLUMN_NAME})::FLOAT + {BASELINE_VALUE_CT}::FLOAT, 0) ))	>=	{THRESHOLD_VALUE}
1003	Condition_Flag	redshift	SUM(CASE WHEN {CUSTOM_QUERY} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1004	Constant	redshift	SUM(CASE WHEN {COLUMN_NAME} <> {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1005	Daily_Record_Ct	redshift	DATEDIFF('DAY', MIN({COLUMN_NAME}), MAX({COLUMN_NAME}))+1-COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
1006	Dec_Trunc	redshift	ROUND(SUM(ABS({COLUMN_NAME})::DECIMAL(18,4) % 1), 0)	<	{THRESHOLD_VALUE}
1007	Distinct_Date_Ct	redshift	COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
1008	Distinct_Value_Ct	redshift	COUNT(DISTINCT {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
1009	Email_Format	redshift	SUM(CASE WHEN {COLUMN_NAME} !~ '^[A-Za-z0-9._''%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1010	Future_Date	redshift	SUM(GREATEST(0, SIGN({COLUMN_NAME}::DATE - '{RUN_DATE}'::DATE)))	>	{THRESHOLD_VALUE}
1011	Future_Date_1Y	redshift	SUM(GREATEST(0, SIGN({COLUMN_NAME}::DATE - ('{RUN_DATE}'::DATE+365))))	>	{THRESHOLD_VALUE}
1012	Incr_Avg_Shift	redshift	NVL(ABS( ({BASELINE_AVG} - (SUM({COLUMN_NAME}) - {BASELINE_SUM}) / NULLIF(COUNT({COLUMN_NAME})::FLOAT - {BASELINE_VALUE_CT}, 0)) / {BASELINE_SD} ), 0)	>=	{THRESHOLD_VALUE}
1013	LOV_All	redshift	LISTAGG(DISTINCT {COLUMN_NAME}, '|') WITHIN GROUP (ORDER BY {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
1014	LOV_Match	redshift	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1015	Min_Date	redshift	SUM(CASE WHEN {COLUMN_NAME} < '{BASELINE_VALUE}' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1016	Min_Val	redshift	SUM(CASE WHEN {COLUMN_NAME} < {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1017	Missing_Pct	redshift	ABS( 2.0 * ASIN( SQRT( {BASELINE_VALUE_CT}::FLOAT / {BASELINE_CT}::FLOAT ) ) - 2 * ASIN( SQRT( COUNT( {COLUMN_NAME} )::FLOAT / NULLIF(COUNT(*), 0)::FLOAT )) )	>=	{THRESHOLD_VALUE}
1018	Monthly_Rec_Ct	redshift	(MAX(DATEDIFF(month, {COLUMN_NAME}, '{RUN_DATE}'::DATE)) - MIN(DATEDIFF(month, {COLUMN_NAME}, '{RUN_DATE}'::DATE)) + 1) - COUNT(DISTINCT DATEDIFF(month, {COLUMN_NAME}, '{RUN_DATE}'::DATE))	>	{THRESHOLD_VALUE}
1019	Outlier_Pct_Above	redshift	SUM(CASE WHEN {COLUMN_NAME}::FLOAT > {BASELINE_AVG}+(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	>	{THRESHOLD_VALUE}
1020	Outlier_Pct_Below	redshift	SUM(CASE WHEN {COLUMN_NAME}::FLOAT < {BASELINE_AVG}-(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	>	{THRESHOLD_VALUE}
1021	Pattern_Match	redshift	COUNT(NULLIF({COLUMN_NAME}, '')) - SUM((NULLIF({COLUMN_NAME}, '') SIMILAR TO '{BASELINE_VALUE}')::BIGINT)	>	{THRESHOLD_VALUE}
1022	Recency	redshift	DATEDIFF('D', MAX({COLUMN_NAME}), '{RUN_DATE}'::DATE)	>	{THRESHOLD_VALUE}
1023	Required	redshift	COUNT(*) - COUNT( {COLUMN_NAME} )	>	{THRESHOLD_VALUE}
1024	Row_Ct	redshift	COUNT(*)	<	{THRESHOLD_VALUE}
1025	Row_Ct_Pct	redshift	ABS(ROUND(100.0 * (COUNT(*) - {BASELINE_CT})::FLOAT / {BASELINE_CT}::FLOAT, 2))	>	{THRESHOLD_VALUE}
1026	Street_Addr_Pattern	redshift	100.0*SUM(({COLUMN_NAME} ~ '^[0-9]{1,5}[a-zA-Z]?\\\\s\\\\w{1,5}\\\\.?\\\\s?\\\\w*\\\\s?\\\\w*\\\\s[a-zA-Z]{1,6}\\\\.?\\\\s?[0-9]{0,5}[A-Z]{0,1}$')::BIGINT)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	<	{THRESHOLD_VALUE}
1027	US_State	redshift	SUM(CASE WHEN {COLUMN_NAME} NOT IN ('','AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1028	Unique	redshift	COUNT(*) - COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
1029	Unique_Pct	redshift	ABS( 2.0 * ASIN( SQRT({BASELINE_UNIQUE_CT}::FLOAT / {BASELINE_VALUE_CT}::FLOAT ) ) - 2 * ASIN( SQRT( COUNT( DISTINCT {COLUMN_NAME} )::FLOAT / NULLIF(COUNT( {COLUMN_NAME} ), 0)::FLOAT )) )	>=	{THRESHOLD_VALUE}
1030	Weekly_Rec_Ct	redshift	MAX(DATEDIFF(week, '1800-01-01'::DATE, {COLUMN_NAME})) - MIN(DATEDIFF(week, '1800-01-01'::DATE, {COLUMN_NAME}))+1 - COUNT(DISTINCT DATEDIFF(week, '1800-01-01'::DATE, {COLUMN_NAME}))	>	{THRESHOLD_VALUE}
2001	Alpha_Trunc	snowflake	MAX(LENGTH({COLUMN_NAME}))	<	{THRESHOLD_VALUE}
2002	Avg_Shift	snowflake	ABS( (AVG({COLUMN_NAME}::FLOAT) - {BASELINE_AVG}) / SQRT(((COUNT({COLUMN_NAME})::FLOAT-1)*POWER(STDDEV({COLUMN_NAME}),2) + ({BASELINE_VALUE_CT}::FLOAT-1) * POWER({BASELINE_SD}::FLOAT,2)) /NULLIF(COUNT({COLUMN_NAME})::FLOAT + {BASELINE_VALUE_CT}::FLOAT, 0) ))	>=	{THRESHOLD_VALUE}
2003	Condition_Flag	snowflake	SUM(CASE WHEN {CUSTOM_QUERY} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2004	Constant	snowflake	SUM(CASE WHEN {COLUMN_NAME} <> {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2005	Daily_Record_Ct	snowflake	DATEDIFF(day, MIN({COLUMN_NAME}), MAX({COLUMN_NAME}))+1-COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
2006	Dec_Trunc	snowflake	ROUND(SUM(ABS({COLUMN_NAME})::DECIMAL(18,4) % 1), 0)	<	{THRESHOLD_VALUE}
2007	Distinct_Date_Ct	snowflake	COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
2008	Distinct_Value_Ct	snowflake	COUNT(DISTINCT {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
2009	Email_Format	snowflake	SUM(CASE WHEN NOT REGEXP_LIKE({COLUMN_NAME}::VARCHAR, '^[A-Za-z0-9._''%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2010	Future_Date	snowflake	SUM(GREATEST(0, SIGN({COLUMN_NAME}::DATE - '{RUN_DATE}'::DATE)))	>	{THRESHOLD_VALUE}
2011	Future_Date_1Y	snowflake	SUM(GREATEST(0, SIGN({COLUMN_NAME}::DATE - ('{RUN_DATE}'::DATE+365))))	>	{THRESHOLD_VALUE}
2012	Incr_Avg_Shift	snowflake	COALESCE(ABS( ({BASELINE_AVG} - (SUM({COLUMN_NAME}) - {BASELINE_SUM}) / NULLIF(COUNT({COLUMN_NAME})::FLOAT - {BASELINE_VALUE_CT}, 0)) / {BASELINE_SD} ), 0)	>=	{THRESHOLD_VALUE}
2013	LOV_All	snowflake	LISTAGG(DISTINCT {COLUMN_NAME}, '|') WITHIN GROUP (ORDER BY {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
2014	LOV_Match	snowflake	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2015	Min_Date	snowflake	SUM(CASE WHEN {COLUMN_NAME} < '{BASELINE_VALUE}' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2016	Min_Val	snowflake	SUM(CASE WHEN {COLUMN_NAME} < {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2017	Missing_Pct	snowflake	ABS( 2.0 * ASIN( SQRT( {BASELINE_VALUE_CT}::FLOAT / {BASELINE_CT}::FLOAT ) ) - 2 * ASIN( SQRT( COUNT( {COLUMN_NAME} )::FLOAT / NULLIF(COUNT(*), 0)::FLOAT )) )	>=	{THRESHOLD_VALUE}
2018	Monthly_Rec_Ct	snowflake	(MAX(DATEDIFF(month, {COLUMN_NAME}, '{RUN_DATE}'::DATE)) - MIN(DATEDIFF(month, {COLUMN_NAME}, '{RUN_DATE}'::DATE)) + 1) - COUNT(DISTINCT DATEDIFF(month, {COLUMN_NAME}, '{RUN_DATE}'::DATE))	>	{THRESHOLD_VALUE}
2019	Outlier_Pct_Above	snowflake	SUM(CASE WHEN {COLUMN_NAME}::FLOAT > {BASELINE_AVG}+(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	>	{THRESHOLD_VALUE}
2020	Outlier_Pct_Below	snowflake	SUM(CASE WHEN {COLUMN_NAME}::FLOAT < {BASELINE_AVG}-(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	>	{THRESHOLD_VALUE}
2021	Pattern_Match	snowflake	COUNT(NULLIF({COLUMN_NAME}, '')) - SUM(REGEXP_LIKE(NULLIF({COLUMN_NAME}::VARCHAR, ''), '{BASELINE_VALUE}')::BIGINT)	>	{THRESHOLD_VALUE}
2022	Recency	snowflake	DATEDIFF('D', MAX({COLUMN_NAME}), '{RUN_DATE}'::DATE)	>	{THRESHOLD_VALUE}
2023	Required	snowflake	COUNT(*) - COUNT( {COLUMN_NAME} )	>	{THRESHOLD_VALUE}
2024	Row_Ct	snowflake	COUNT(*)	<	{THRESHOLD_VALUE}
2025	Row_Ct_Pct	snowflake	ABS(ROUND(100.0 * (COUNT(*) - {BASELINE_CT})::FLOAT / {BASELINE_CT}::FLOAT, 2))	>	{THRESHOLD_VALUE}
2026	Street_Addr_Pattern	snowflake	100.0*SUM((regexp_like({COLUMN_NAME}::VARCHAR, '^[0-9]{1,5}[a-zA-Z]?\\\\s\\\\w{1,5}\\\\.?\\\\s?\\\\w*\\\\s?\\\\w*\\\\s[a-zA-Z]{1,6}\\\\.?\\\\s?[0-9]{0,5}[A-Z]{0,1}$'))::BIGINT)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	<	{THRESHOLD_VALUE}
2027	US_State	snowflake	SUM(CASE WHEN {COLUMN_NAME} NOT IN ('','AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2028	Unique	snowflake	COUNT(*) - COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
2029	Unique_Pct	snowflake	ABS( 2.0 * ASIN( SQRT({BASELINE_UNIQUE_CT}::FLOAT / {BASELINE_VALUE_CT}::FLOAT ) ) - 2 * ASIN( SQRT( COUNT( DISTINCT {COLUMN_NAME} )::FLOAT / NULLIF(COUNT( {COLUMN_NAME} ), 0)::FLOAT )) )	>=	{THRESHOLD_VALUE}
2030	Weekly_Rec_Ct	snowflake	MAX(DATEDIFF(week, '1800-01-01'::DATE, {COLUMN_NAME})) - MIN(DATEDIFF(week, '1800-01-01'::DATE, {COLUMN_NAME}))+1 - COUNT(DISTINCT DATEDIFF(week, '1800-01-01'::DATE, {COLUMN_NAME}))	>	{THRESHOLD_VALUE}
3001	Alpha_Trunc	mssql	MAX(LEN({COLUMN_NAME}))	<	{THRESHOLD_VALUE}
3002	Avg_Shift	mssql	ABS( (AVG(CAST({COLUMN_NAME} AS FLOAT)) - {BASELINE_AVG}) / SQRT(((COUNT({COLUMN_NAME})-1)*POWER(STDEV({COLUMN_NAME}), 2) + ({BASELINE_VALUE_CT}-1) * POWER({BASELINE_SD}, 2)) /NULLIF(COUNT({COLUMN_NAME}) + {BASELINE_VALUE_CT}, 0) ))	>=	{THRESHOLD_VALUE}
3003	Condition_Flag	mssql	SUM(CASE WHEN {CUSTOM_QUERY} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3004	Constant	mssql	SUM(CASE WHEN {COLUMN_NAME} <> {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3005	Daily_Record_Ct	mssql	DATEDIFF(day, MIN({COLUMN_NAME}), MAX({COLUMN_NAME}))+1-COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
3006	Dec_Trunc	mssql	ROUND(SUM(ABS(CAST({COLUMN_NAME} AS DECIMAL(18,4))) % 1), 0)	<	{THRESHOLD_VALUE}
3007	Distinct_Date_Ct	mssql	COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
3008	Distinct_Value_Ct	mssql	COUNT(DISTINCT {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
3009	Email_Format	mssql	SUM(CASE WHEN {COLUMN_NAME} NOT LIKE '[A-Za-z0-9._''%+-]%@[A-Za-z0-9.-]%.[A-Za-z][A-Za-z]%' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3010	Future_Date	mssql	SUM(CASE WHEN CAST({COLUMN_NAME} AS DATE) >= CONVERT(DATE, '{RUN_DATE}') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3011	Future_Date_1Y	mssql	SUM(CASE WHEN CAST({COLUMN_NAME} AS DATE) >= DATEADD(DAY, 365, CONVERT(DATE, '{RUN_DATE}')) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3012	Incr_Avg_Shift	mssql	COALESCE(ABS( ({BASELINE_AVG} - (SUM({COLUMN_NAME}) - {BASELINE_SUM}) / NULLIF(CAST(COUNT({COLUMN_NAME}) AS FLOAT) - {BASELINE_VALUE_CT}, 0)) / {BASELINE_SD} ), 0)	>=	{THRESHOLD_VALUE}
3013	LOV_All	mssql	STRING_AGG(DISTINCT {COLUMN_NAME}, '|') WITHIN GROUP (ORDER BY {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
3014	LOV_Match	mssql	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3015	Min_Date	mssql	SUM(CASE WHEN {COLUMN_NAME} < '{BASELINE_VALUE}' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3016	Min_Val	mssql	SUM(CASE WHEN {COLUMN_NAME} < {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3017	Missing_Pct	mssql	ABS( 2.0 * ASIN( SQRT( CAST({BASELINE_VALUE_CT}  AS FLOAT) / CAST({BASELINE_CT} AS FLOAT) ) ) - 2 * ASIN( SQRT( CAST(COUNT( {COLUMN_NAME} ) AS FLOAT) / CAST(NULLIF(COUNT(*), 0) AS FLOAT) )) )	>=	{THRESHOLD_VALUE}
3018	Monthly_Rec_Ct	mssql	(MAX(DATEDIFF(month, {COLUMN_NAME}, CAST('{RUN_DATE}'AS DATE))) - MIN(DATEDIFF(month, {COLUMN_NAME}, CAST('{RUN_DATE}' AS DATE))) + 1) - COUNT(DISTINCT DATEDIFF(month, {COLUMN_NAME}, CAST('{RUN_DATE}'AS DATE)))	>	{THRESHOLD_VALUE}
3019	Outlier_Pct_Above	mssql	CAST(SUM(CASE WHEN CAST({COLUMN_NAME} AS FLOAT) > {BASELINE_AVG}+(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END) AS FLOAT) / CAST(COUNT({COLUMN_NAME}) AS FLOAT)	>	{THRESHOLD_VALUE}
3020	Outlier_Pct_Below	mssql	CAST(SUM(CASE WHEN CAST( {COLUMN_NAME} AS FLOAT) < {BASELINE_AVG}-(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END) AS FLOAT) / CAST(COUNT({COLUMN_NAME}) AS FLOAT)	>	{THRESHOLD_VALUE}
3021	Pattern_Match	mssql	COUNT(NULLIF({COLUMN_NAME}, '')) - CAST(SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') LIKE '{BASELINE_VALUE}' THEN 1 ELSE  0 END) AS BIGINT)	>	{THRESHOLD_VALUE}
3022	Recency	mssql	DATEDIFF(day, MAX({COLUMN_NAME}), CAST('{RUN_DATE}'AS DATE))	>	{THRESHOLD_VALUE}
3023	Required	mssql	COUNT(*) - COUNT( {COLUMN_NAME} )	>	{THRESHOLD_VALUE}
3024	Row_Ct	mssql	COUNT(*)	<	{THRESHOLD_VALUE}
3025	Row_Ct_Pct	mssql	ABS(ROUND(100.0 * CAST((COUNT(*) - {BASELINE_CT} ) AS FLOAT)/ CAST({BASELINE_CT} AS FLOAT, 2)))	>	{THRESHOLD_VALUE}
3026	Street_Addr_Pattern	mssql	CAST(100.0*SUM(CASE WHEN UPPER({COLUMN_NAME}) LIKE '[1-9]% [A-Z]% %' AND CHARINDEX(' ', {COLUMN_NAME}) BETWEEN 2 AND 6 THEN 1 ELSE 0 END) as FLOAT) /CAST(COUNT({COLUMN_NAME}) AS FLOAT)	<	{THRESHOLD_VALUE}
3027	US_State	mssql	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3028	Unique	mssql	COUNT(*) - COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
3029	Unique_Pct	mssql	ABS( 2.0 * ASIN( SQRT(CAST({BASELINE_UNIQUE_CT} AS FLOAT) / CAST({BASELINE_VALUE_CT} AS FLOAT) ) ) - 2 * ASIN( SQRT( CAST(COUNT( DISTINCT {COLUMN_NAME} ) AS FLOAT) / CAST(NULLIF(COUNT( {COLUMN_NAME} ), 0) AS FLOAT) )) )	>=	{THRESHOLD_VALUE}
3030	Weekly_Rec_Ct	mssql	MAX(DATEDIFF(week, CAST('1800-01-01' AS DATE), "{COLUMN_NAME}")) - MIN(DATEDIFF(week, CAST('1800-01-01' AS DATE), "{COLUMN_NAME}"))+1 - COUNT(DISTINCT DATEDIFF(week, CAST('1800-01-01' AS DATE), "{COLUMN_NAME}"))	>	{THRESHOLD_VALUE}
4001	Alpha_Trunc	postgresql	MAX(LENGTH({COLUMN_NAME}))	<	{THRESHOLD_VALUE}
4002	Avg_Shift	postgresql	ABS( (AVG({COLUMN_NAME}::FLOAT) - {BASELINE_AVG}) / SQRT(((COUNT({COLUMN_NAME})::FLOAT-1)*STDDEV({COLUMN_NAME})^2 + ({BASELINE_VALUE_CT}::FLOAT-1) * {BASELINE_SD}::FLOAT^2) /NULLIF(COUNT({COLUMN_NAME})::FLOAT + {BASELINE_VALUE_CT}::FLOAT, 0) ))	>=	{THRESHOLD_VALUE}
4003	Condition_Flag	postgresql	SUM(CASE WHEN {CUSTOM_QUERY} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4004	Constant	postgresql	SUM(CASE WHEN {COLUMN_NAME} <> {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4005	Daily_Record_Ct	postgresql	{{DKFN_DATEDIFF_DAY;;MIN({COLUMN_NAME});;MAX({COLUMN_NAME})}} +1-COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
4006	Dec_Trunc	postgresql	ROUND(SUM(ABS({COLUMN_NAME})::DECIMAL(18,4) % 1), 0)	<	{THRESHOLD_VALUE}
4007	Distinct_Date_Ct	postgresql	COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
4008	Distinct_Value_Ct	postgresql	COUNT(DISTINCT {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
4009	Email_Format	postgresql	SUM(CASE WHEN {COLUMN_NAME} !~ '^[A-Za-z0-9._''%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4010	Future_Date	postgresql	SUM(GREATEST(0, SIGN({COLUMN_NAME}::DATE - '{RUN_DATE}'::DATE)))	>	{THRESHOLD_VALUE}
4011	Future_Date_1Y	postgresql	SUM(GREATEST(0, SIGN({COLUMN_NAME}::DATE - ('{RUN_DATE}'::DATE+365))))	>	{THRESHOLD_VALUE}
4012	Incr_Avg_Shift	postgresql	COALESCE(ABS( ({BASELINE_AVG} - (SUM({COLUMN_NAME}) - {BASELINE_SUM}) / NULLIF(COUNT({COLUMN_NAME})::FLOAT - {BASELINE_VALUE_CT}, 0)) / {BASELINE_SD} ), 0)	>=	{THRESHOLD_VALUE}
4013	LOV_All	postgresql	STRING_AGG(DISTINCT {COLUMN_NAME}, '|') WITHIN GROUP (ORDER BY {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
4014	LOV_Match	postgresql	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4015	Min_Date	postgresql	SUM(CASE WHEN {COLUMN_NAME} < '{BASELINE_VALUE}' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4016	Min_Val	postgresql	SUM(CASE WHEN {COLUMN_NAME} < {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4017	Missing_Pct	postgresql	ABS( 2.0 * ASIN( SQRT( {BASELINE_VALUE_CT}::FLOAT / {BASELINE_CT}::FLOAT ) ) - 2 * ASIN( SQRT( COUNT( {COLUMN_NAME} )::FLOAT / NULLIF(COUNT(*), 0)::FLOAT )) )	>=	{THRESHOLD_VALUE}
4018	Monthly_Rec_Ct	postgresql	(MAX({{DKFN_DATEDIFF_MONTH;;{COLUMN_NAME};;'{RUN_DATE}'::DATE}} ) - MIN({{DKFN_DATEDIFF_MONTH;;{COLUMN_NAME};;'{RUN_DATE}'::DATE}} ) + 1) - COUNT(DISTINCT {{DKFN_DATEDIFF_MONTH;;{COLUMN_NAME};;'{RUN_DATE}'::DATE}} )	>	{THRESHOLD_VALUE}
4019	Outlier_Pct_Above	postgresql	SUM(CASE WHEN {COLUMN_NAME}::FLOAT > {BASELINE_AVG}+(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	>	{THRESHOLD_VALUE}
4020	Outlier_Pct_Below	postgresql	SUM(CASE WHEN {COLUMN_NAME}::FLOAT < {BASELINE_AVG}-(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	>	{THRESHOLD_VALUE}
4021	Pattern_Match	postgresql	COUNT(NULLIF({COLUMN_NAME}, '')) - SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') ~ '{BASELINE_VALUE}' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4022	Recency	postgresql	{{DKFN_DATEDIFF_DAY;;MAX({COLUMN_NAME});;'{RUN_DATE}'::DATE}} 	>	{THRESHOLD_VALUE}
4023	Required	postgresql	COUNT(*) - COUNT({COLUMN_NAME})	>	{THRESHOLD_VALUE}
4024	Row_Ct	postgresql	COUNT(*)	<	{THRESHOLD_VALUE}
4025	Row_Ct_Pct	postgresql	ABS(ROUND(100.0 * (COUNT(*) - {BASELINE_CT})::DECIMAL(18,4) / {BASELINE_CT}::DECIMAL(18,4), 2))	>	{THRESHOLD_VALUE}
4026	Street_Addr_Pattern	postgresql	100.0*SUM(CASE WHEN {COLUMN_NAME} ~ '^[0-9]{1,5}[a-zA-Z]?\\s\\w{1,5}\\.?\\s?\\w*\\s?\\w*\\s[a-zA-Z]{1,6}\\.?\\s?[0-9]{0,5}[A-Z]{0,1}$' THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT({COLUMN_NAME}), 0)::FLOAT	<	{THRESHOLD_VALUE}
4027	US_State	postgresql	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4028	Unique	postgresql	COUNT(*) - COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
4029	Unique_Pct	postgresql	ABS( 2.0 * ASIN( SQRT({BASELINE_UNIQUE_CT}::FLOAT / {BASELINE_VALUE_CT}::FLOAT ) ) - 2 * ASIN( SQRT( COUNT( DISTINCT {COLUMN_NAME} )::FLOAT / NULLIF(COUNT( {COLUMN_NAME} ), 0)::FLOAT )) )	>=	{THRESHOLD_VALUE}
4030	Weekly_Rec_Ct	postgresql	MAX({{DKFN_DATEDIFF_WEEK;;'1800-01-01'::DATE;;{COLUMN_NAME}}} ) - MIN({{DKFN_DATEDIFF_WEEK;;'1800-01-01'::DATE;;{COLUMN_NAME}}} )+1 - COUNT(DISTINCT {{DKFN_DATEDIFF_WEEK;;'1800-01-01'::DATE;;{COLUMN_NAME}}} )	>	{THRESHOLD_VALUE}
1031	Variability_Increase	redshift	100.0*STDDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	>	{THRESHOLD_VALUE}
1032	Variability_Decrease	redshift	100.0*STDDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	<	{THRESHOLD_VALUE}
2031	Variability_Increase	snowflake	100.0*STDDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	>	{THRESHOLD_VALUE}
2032	Variability_Decrease	snowflake	100.0*STDDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	<	{THRESHOLD_VALUE}
3031	Variability_Increase	mssql	100.0*STDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	>	{THRESHOLD_VALUE}
3032	Variability_Decrease	mssql	100.0*STDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	<	{THRESHOLD_VALUE}
4031	Variability_Increase	postgresql	100.0*STDDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	>	{THRESHOLD_VALUE}
4032	Variability_Decrease	postgresql	100.0*STDDEV(CAST("{COLUMN_NAME}" AS FLOAT))/{BASELINE_SD}	<	{THRESHOLD_VALUE}
5001	Alpha_Trunc	trino	MAX(LENGTH({COLUMN_NAME}))	<	{THRESHOLD_VALUE}
5002	Avg_Shift	trino	ABS( (CAST(AVG({COLUMN_NAME} AS REAL)) - {BASELINE_AVG}) / SQRT(((CAST(COUNT({COLUMN_NAME}) AS REAL)-1)*STDDEV({COLUMN_NAME})^2 + (CAST({BASELINE_VALUE_CT} AS REAL)-1) * CAST({BASELINE_SD} AS REAL)^2) /NULLIF(CAST(COUNT({COLUMN_NAME}) AS REAL) + CAST({BASELINE_VALUE_CT} AS REAL), 0) ))	>=	{THRESHOLD_VALUE}
5003	Condition_Flag	trino	SUM(CASE WHEN {BASELINE_VALUE} IS NOT NULL THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5004	Constant	trino	SUM(CASE WHEN {COLUMN_NAME} <> {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5005	Daily_Record_Ct	trino	DATE_DIFF('DAY', MIN({COLUMN_NAME}), MAX({COLUMN_NAME}))+1-COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
5006	Dec_Trunc	trino	ROUND(SUM(ABS(CAST({COLUMN_NAME} AS DECIMAL(18,4))) % 1), 0)	<	{THRESHOLD_VALUE}
5007	Distinct_Date_Ct	trino	COUNT(DISTINCT {COLUMN_NAME})	<	{THRESHOLD_VALUE}
5008	Distinct_Value_Ct	trino	COUNT(DISTINCT {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
5009	Email_Format	trino	SUM(CASE WHEN REGEXP_LIKE({COLUMN_NAME} , '^[A-Za-z0-9._''%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') != TRUE THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5010	Future_Date	trino	SUM(CASE WHEN CAST({COLUMN_NAME} AS DATE) >= CAST('{RUN_DATE}' AS DATE) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5011	Future_Date_1Y	trino	SUM(CASE WHEN CAST({COLUMN_NAME} AS DATE) >= (FROM_ISO8601_DATE('{RUN_DATE}') + interval '365' day ) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5012	Incr_Avg_Shift	trino	COALESCE(ABS( ({BASELINE_AVG} - (SUM({COLUMN_NAME}) - {BASELINE_SUM}) / NULLIF(CAST(COUNT({COLUMN_NAME}) AS REAL) - {BASELINE_VALUE_CT}, 0)) / {BASELINE_SD} ), 0)	>=	{THRESHOLD_VALUE}
5013	LOV_All	trino	LISTAGG(DISTINCT {COLUMN_NAME}, '|') WITHIN GROUP (ORDER BY {COLUMN_NAME})	<>	{THRESHOLD_VALUE}
5014	LOV_Match	trino	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5015	Min_Date	trino	SUM(CASE WHEN {COLUMN_NAME} < CAST('{BASELINE_VALUE}' AS DATE) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5016	Min_Val	trino	SUM(CASE WHEN {COLUMN_NAME} < {BASELINE_VALUE} THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5017	Missing_Pct	trino	ABS(2.0 * ASIN(SQRT(CAST({BASELINE_VALUE_CT} AS REAL) / CAST({BASELINE_CT} AS REAL))) - 2 * ASIN(SQRT(CAST(COUNT({COLUMN_NAME}) AS REAL) / CAST(NULLIF(COUNT(*), 0) AS REAL) )))	>=	{THRESHOLD_VALUE}
5018	Monthly_Rec_Ct	trino	(MAX(DATE_DIFF('month', {COLUMN_NAME}, CAST('{RUN_DATE}' AS DATE))) - MIN(DATE_DIFF('month', {COLUMN_NAME}, CAST('{RUN_DATE}' AS DATE))) + 1) - COUNT(DISTINCT DATE_DIFF('month', {COLUMN_NAME}, CAST('{RUN_DATE}' AS DATE)))	>	{THRESHOLD_VALUE}
5019	Outlier_Pct_Above	trino	CAST(SUM(CASE WHEN CAST({COLUMN_NAME} AS REAL) > {BASELINE_AVG}+(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END) AS REAL) / CAST(COUNT({COLUMN_NAME}) AS REAL)	>	{THRESHOLD_VALUE}
5020	Outlier_Pct_Below	trino	CAST(SUM(CASE WHEN CAST( {COLUMN_NAME} AS REAL) < {BASELINE_AVG}-(2.0*{BASELINE_SD}) THEN 1 ELSE 0 END) AS REAL) / CAST(COUNT({COLUMN_NAME}) AS REAL)	>	{THRESHOLD_VALUE}
5021	Pattern_Match	trino	COUNT(NULLIF({COLUMN_NAME}, '')) - SUM(CASE WHEN REGEXP_LIKE(NULLIF({COLUMN_NAME}, '') , '{BASELINE_VALUE}') = TRUE THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5022	Recency	trino	DATE_DIFF('day', MAX({COLUMN_NAME}), CAST('{RUN_DATE}' AS DATE))	>	{THRESHOLD_VALUE}
5023	Required	trino	COUNT(*) - COUNT({COLUMN_NAME})	>	{THRESHOLD_VALUE}
5024	Row_Ct	trino	COUNT(*)	<	{THRESHOLD_VALUE}
5025	Row_Ct_Pct	trino	ABS(ROUND(100.0 * CAST((COUNT(*) - {BASELINE_CT}) AS DECIMAL(18,4)) /CAST( {BASELINE_CT} AS DECIMAL(18,4) ), 2))	>	{THRESHOLD_VALUE}
5026	Street_Addr_Pattern	trino	CAST(100.0*SUM(CASE WHEN REGEXP_LIKE({COLUMN_NAME} , '^[0-9]{1,5}[a-zA-Z]?\\s\\w{1,5}\\.?\\s?\\w*\\s?\\w*\\s[a-zA-Z]{1,6}\\.?\\s?[0-9]{0,5}[A-Z]{0,1}$') = TRUE THEN 1 ELSE 0 END) AS REAL )/ CAST(COUNT({COLUMN_NAME}) AS REAL)	<	{THRESHOLD_VALUE}
5027	US_State	trino	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5028	Unique	trino	COUNT(*) - COUNT(DISTINCT {COLUMN_NAME})	>	{THRESHOLD_VALUE}
5029	Unique_Pct	trino	ABS( 2.0 * ASIN( SQRT(CAST({BASELINE_UNIQUE_CT} AS REAL) / CAST({BASELINE_VALUE_CT} AS REAL) ) ) - 2 * ASIN( SQRT( CAST(COUNT( DISTINCT {COLUMN_NAME} ) AS REAL) / CAST(NULLIF(COUNT( {COLUMN_NAME} ), 0) AS REAL) )))	>=	{THRESHOLD_VALUE}
5030	Weekly_Rec_Ct	trino	MAX(DATE_DIFF('week', CAST('1800-01-01' AS DATE), "{COLUMN_NAME}")) - MIN(DATE_DIFF('week', CAST('1800-01-01' AS DATE), "{COLUMN_NAME}")) +1 - COUNT(DISTINCT DATE_DIFF('week', CAST('1800-01-01' AS DATE), "{COLUMN_NAME}"))	>	{THRESHOLD_VALUE}
5031	Variability_Increase	trino	100.0*STDDEV(CAST("{COLUMN_NAME}" AS REAL))/{BASELINE_SD}	>	{THRESHOLD_VALUE}
5032	Variability_Decrease	trino	100.0*STDDEV(CAST("{COLUMN_NAME}" AS REAL))/{BASELINE_SD}	<	{THRESHOLD_VALUE}
1033	Valid_Month	redshift	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ({BASELINE_VALUE}) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2033	Valid_Month	snowflake	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ({BASELINE_VALUE}) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3033	Valid_Month	mssql	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ({BASELINE_VALUE}) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4033	Valid_Month	postgresql	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ({BASELINE_VALUE}) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5033	Valid_Month	trino	SUM(CASE WHEN NULLIF({COLUMN_NAME}, '') NOT IN ({BASELINE_VALUE}) THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1034	Valid_US_Zip	redshift	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4034	Valid_US_Zip	postgresql	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2034	Valid_US_Zip	snowflake	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5034	Valid_US_Zip	trino	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3034	Valid_US_Zip	mssql	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1035	Valid_US_Zip3	redshift	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') <> '999' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4035	Valid_US_Zip3	postgresql	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') <> '999' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2035	Valid_US_Zip3	snowflake	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') <> '999' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5035	Valid_US_Zip3	trino	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') <> '999' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3035	Valid_US_Zip3	mssql	SUM(CASE WHEN TRANSLATE({COLUMN_NAME},'012345678','999999999') <> '999' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
1036	Valid_Characters	redshift	SUM(CASE WHEN {COLUMN_NAME} ~ '[[:cntrl:]]' OR {COLUMN_NAME} LIKE ' %' OR {COLUMN_NAME} LIKE '''%''' OR {COLUMN_NAME} LIKE '"%"' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
4036	Valid_Characters	postgresql	SUM(CASE WHEN {COLUMN_NAME} ~ '[[:cntrl:]]' OR {COLUMN_NAME} LIKE ' %' OR {COLUMN_NAME}::VARCHAR LIKE '''%''' OR column_name::VARCHAR LIKE '"%"' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
2036	Valid_Characters	snowflake	SUM(CASE WHEN REGEXP_LIKE({COLUMN_NAME}::VARCHAR, '.*[[:cntrl:]].*') OR {COLUMN_NAME} LIKE ' %' OR {COLUMN_NAME} LIKE '''%''' OR {COLUMN_NAME} LIKE '"%"' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
5036	Valid_Characters	trino	SUM(CASE WHEN REGEXP_LIKE({COLUMN_NAME}, '[\\x00-\\x1F\\x7F]') OR {COLUMN_NAME} LIKE ' %' OR {COLUMN_NAME} LIKE '''%''' OR column_name LIKE '"%"' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
3036	Valid_Characters	mssql	SUM(CASE WHEN PATINDEX('%[' + CHAR(1) + '-' + CHAR(8) + CHAR(11) + CHAR(12) + CHAR(14) + '-' + CHAR(31) + ']%', {COLUMN_NAME}) > 0 OR {COLUMN_NAME} LIKE ' %' OR {COLUMN_NAME} LIKE '''%''' OR column_name LIKE '"%"' THEN 1 ELSE 0 END)	>	{THRESHOLD_VALUE}
\.


--
-- Data for Name: connections; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.connections (id, project_code, connection_id, sql_flavor, project_host, project_port, project_user, project_db, connection_name, project_pw_encrypted, max_threads, max_query_chars, url, connect_by_url, connect_by_key, private_key, private_key_passphrase) FROM stdin;
a98ef3ae-a960-4ae6-a99c-d22621da55de	DEFAULT	1	postgresql	postgres	5432	admin	demo_db	default	\\x672b774867582f6c544176667a4b41742f647739356479506a61523052697a3832304d70384c616b6732383d	4	5000		f	f	\N	\N
\.


--
-- Data for Name: data_column_chars; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.data_column_chars (column_id, table_id, table_groups_id, schema_name, table_name, column_name, general_type, column_type, functional_data_type, critical_data_element, data_source, source_system, source_process, business_domain, stakeholder_group, transform_level, aggregation_level, add_date, last_mod_date, drop_date, test_ct, last_test_date, tests_last_run, tests_7_days_prior, tests_30_days_prior, fails_last_run, fails_7_days_prior, fails_30_days_prior, warnings_last_run, warnings_7_days_prior, warnings_30_days_prior, last_complete_profile_run_id, dq_score_profiling, dq_score_testing) FROM stdin;
\.


--
-- Data for Name: data_structure_log; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.data_structure_log (project_code, connection_id, change_date, schema_name, table_name, ordinal_position, column_name, data_type, status) FROM stdin;
\.


--
-- Data for Name: data_table_chars; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.data_table_chars (table_id, table_groups_id, schema_name, table_name, functional_table_type, critical_data_element, data_source, source_system, source_process, business_domain, stakeholder_group, transform_level, aggregation_level, add_date, drop_date, record_ct, column_ct, data_point_ct, last_complete_profile_run_id, dq_score_profiling, dq_score_testing) FROM stdin;
\.


--
-- Data for Name: functional_test_results; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.functional_test_results (test_name, error_ct) FROM stdin;
\.


--
-- Data for Name: generation_sets; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.generation_sets (generation_set, test_type) FROM stdin;
Monitor	Recency
Monitor	Row_Ct
Monitor	Row_Ct_Pct
Monitor	Daily_Record_Ct
Monitor	Monthly_Rec_Ct
Monitor	Weekly_Rec_Ct
\.


--
-- Data for Name: profile_anomaly_results; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.profile_anomaly_results (id, project_code, table_groups_id, profile_run_id, column_id, schema_name, table_name, column_name, column_type, anomaly_id, detail, disposition, dq_prevalence) FROM stdin;
\.


--
-- Data for Name: profile_anomaly_types; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.profile_anomaly_types (id, anomaly_type, data_object, anomaly_name, anomaly_description, anomaly_criteria, detail_expression, issue_likelihood, suggested_action, dq_score_prevalence_formula, dq_score_risk_factor) FROM stdin;
1001	Suggested_Type	Column	Suggested Data Type	Data stored as text all meets criteria for a more suitable type. 	(functional_data_type NOT IN ('Boolean', 'Flag') ) AND (column_type ILIKE '%ch\nar%' OR column_type ILIKE 'text') AND NOT (datatype_suggestion ILIKE '%char%' OR datatype_suggestion ILIKE 'text')	p.datatype_suggestion::VARCHAR(200)	Likely	Consider changing the column data type to tighte\nn controls over data ingested and to make values more efficient, consistent and suitable for downstream analysis.	\N	\N
1002	Non_Standard_Blanks	Column	Non-Standard Blank Values	Values representing missing data may be unexpected or inconsistent. Non-standard values may include empty strings as opposed to nulls, dummy entries such as "MISSING" or repeated characters that may have been used to bypass entry requirements, processing artifacts such as "NULL", or spreadsheet artifacts such as "NA", "ERROR".	(p.filled_value_ct > 0 OR p.zero_length_ct > 0)	'Filled Values: ' || p.filled_value_ct::VARCHAR || ', Empty String: ' || p.zero_length_ct::VARCHAR || ', Null: ' || p.null_value_ct::VARCHAR || ', Records: ' || p.record_ct::VARCHAR	Definite	Consider cleansing the column upon ingestion to replace all variants of missing data with a standard designation, like Null.	p.filled_value_ct::FLOAT/p.record_ct::FLOAT	1.0
1003	Invalid_Zip_USA	Column	Invalid USA Zip Code Format	Some values present do not conform with the expected format of USA Zip Codes.	p.std_pattern_match = 'ZIP_USA' AND (p.general_type <> 'A' OR p.filled_value_ct > 0 OR p.min_length >= 1 AND p.min_length <= 4 OR p.max_length > 10)	CASE WHEN p.general_type = 'N' THEN 'Type: ' || p.column_type || ', ' ELSE '' END || 'Min Length: ' || p.min_length::VARCHAR || ', Max Length: ' || p.max_length::VARCHAR || ', Filled Values: ' || p.filled_value_ct::VARCHAR	Definite	Consider correcting invalid column values or changing them to indicate a missing value if corrections cannot be made.	\N	1.0
1004	Multiple_Types_Minor	Multi-Col	Multiple Data Types per Column Name - Minor	Columns with the same name have the same general type across tables, but the types do not exactly match. Truncation issues may result if columns are commingled and assumed to be the same format.	m.general_type_ct = 1 AND m.type_ct > 1	'Found ' || m.column_ct::VARCHAR || ' columns, ' || m.type_ct::VARCHAR(10) || ' types, ' || m.min_type || ' to ' || m.max_type	Possible	Consider changing the column data types to be fully consistent. This will tighten your standards at ingestion and assure that data is consistent between tables.	\N	\N
1005	Multiple_Types_Major	Multi-Col	Multiple Data Types per Column Name - Major	Columns with the same name have broadly different types across tables. Differences could be significant enough to cause errors in downstream analysis, extra steps resulting in divergent business logic and inconsistencies in results.	m.general_type_ct > 1	'Found ' || m.column_ct::VARCHAR || ' columns, ' || m.type_ct::VARCHAR(10) || ' types, ' || m.min_type || ' to ' || m.max_type	Likely	Ideally, you should change the column data types to be fully consistent. If the data is meant to be different, you should change column names so downstream users aren't led astray.	\N	\N
1006	No_Values	Column	No Column Values Present	This column is present in the table, but no values have been ingested or assigned in any records. This could indicate missing data or a processing error. Note that this considers dummy values and zero-length values as missing data. 	(p.null_value_ct + p.filled_value_ct + p.zero_length_ct) = p.record_ct	'Null: ' || p.null_value_ct::VARCHAR(10) || ', Filled: ' || p.filled_value_ct::VARCHAR(10) || ', Zero Len: ' || p.zero_length_ct::VARCHAR(10)	Possible	Review your source data, ingestion process, and any processing steps that update this column.	1.0	0.33
1007	Column_Pattern_Mismatch	Column	Pattern Inconsistency Within Column	Alpha-numeric string data within this column conforms to 2-4 different patterns, with 95% matching the first pattern. This could indicate data errors in the remaining values. 	p.general_type = 'A'\n   AND p.max_length > 3\n   AND p.value_ct > (p.numeric_ct + p.filled_value_ct)\n   AND p.distinct_pattern_ct BETWEEN 2 AND 4\n   AND STRPOS(p.top_patterns, 'N') > 0\n   AND (\n         ( (STRPOS(p.top_patterns, 'A') > 0 OR STRPOS(p.top_patterns, 'a') > 0)\n           AND SPLIT_PART(p.top_patterns, '|', 3)::NUMERIC / SPLIT_PART(p.top_patterns, '|', 1)::NUMERIC < 0.05)\n        OR\n         SPLIT_PART(p.top_patterns, '|', 3)::NUMERIC / SPLIT_PART(p.top_patterns, '|', 1)::NUMERIC < 0.1\n    )	'Patterns: ' || p.top_patterns	Likely	Review the values for any data that doesn't conform to the most common pattern and correct any data errors.	(p.record_ct - SPLIT_PART(p.top_patterns, '|', 1)::INT)::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.66
1008	Table_Pattern_Mismatch	Multi-Col	Pattern Inconsistency Across Tables	Alpha-numeric string data within this column matches a single pattern, but other columns with the same name have data that matches a different single pattern. Inconsistent formatting may contradict user assumptions and cause downstream errors, extra steps and inconsistent business logic.	p.general_type = 'A'\n               AND p.max_length > 3\n               AND p.value_ct > (p.numeric_ct + p.filled_value_ct)\n               AND m.max_pattern_ct = 1\n               AND m.column_ct > 1\n               AND SPLIT_PART(p.top_patterns, '|', 2) <> SPLIT_PART(m.very_top_pattern, '|', 2)\n               AND SPLIT_PART(p.top_patterns, '|', 1)::NUMERIC / SPLIT_PART(m.very_top_pattern, '|', 1)::NUMERIC < 0.1	'Patterns: ' || SPLIT_PART(p.top_patterns, '|', 2) || ', ' || SPLIT_PART(ltrim(m.very_top_pattern, '0'), '|', 2)	Likely	Review the profiled patterns for the same column in other tables. You may want to add a hygiene step to your processing to make patterns consistent.	\N	\N
1009	Leading_Spaces	Column	Leading Spaces Found in Column Values	Spaces were found before data at the front of column string values. This likely contradicts user expectations and could be a sign of broader ingestion or processing errors.	p.lead_space_ct > 0	'Cases Found: ' || p.lead_space_ct::VARCHAR(10)	Likely	Review your source data, ingestion process, and any processing steps that update this column.	p.lead_space_ct::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.66
1010	Quoted_Values	Column	Quoted Values Found in Column Values	Column values were found within quotes. This likely contradicts user expectations and could be a sign of broader ingestion or processing errors.	p.quoted_value_ct > 0	'Cases Found: ' || p.quoted_value_ct::VARCHAR(10)	Likely	Review your source data, ingestion process, and any processing steps that update this column.	p.quoted_value_ct::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.66
1021	Unexpected US States	Column	Unexpected Column Contains US States	This column is not labeled as a state, but contains mostly US State abbreviations. This could indicate shifted or switched source data columns.	p.std_pattern_match = 'STATE_USA'\n       AND p.distinct_value_ct > 5\n       AND NOT (p.column_name ILIKE '%state%' OR p.column_name ILIKE '%_st')	'Value Range: ' || p.min_text || ' thru ' || max_text || CASE WHEN p.top_freq_values > '' THEN 'Top Freq Values: ' || REPLACE(p.top_freq_values, CHR(10), ' ; ') ELSE '' END 	Possible	Review your source data and follow-up with data owners to determine whether column should be populated with US states.	\N	0.33
1011	Char_Column_Number_Values	Column	Character Column with Mostly Numeric Values	This column is defined as alpha, but more than 95% of its values are numeric. Numbers in alpha columns won't sort correctly, and might contradict user expectations downstream. It's also possible that more than one type of information is stored in the column, making it harder to retrieve.	p.general_type = 'A'\n   AND p.column_name NOT ILIKE '%zip%'\n   AND p.functional_data_type NOT ILIKE 'id%'\n   AND p.value_ct > p.numeric_ct\n   AND p.numeric_ct::NUMERIC > (0.95 * p.value_ct::NUMERIC)	'Numeric Ct: ' || p.numeric_ct || ' of ' || p.value_ct || ' (Numeric Percent: ' || ROUND(100.0 * p.numeric_ct::NUMERIC(18, 5) / p.value_ct::NUMERIC(18, 5), 2) || ' )'::VARCHAR(200)	Likely	Review your source data and ingestion process. Consider whether it might be better to store the numeric data in a numeric column. If the alpha data is significant, you could store it in a different column.	p.numeric_ct::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.66
1012	Char_Column_Date_Values	Column	Character Column with Mostly Date Values	This column is defined as alpha, but more than 95% of its values are dates. Dates in alpha columns might not sort correctly, and might contradict user expectations downstream. It's also possible that more than one type of information is stored in the column, making it harder to retrieve.    	p.general_type = 'A'\n   AND p.value_ct > p.date_ct\n   AND p.date_ct::NUMERIC > (0.95 * p.value_ct::NUMERIC)	' Date Ct: ' || p.date_ct || ' of ' || p.value_ct || ' (Date Percent: ' || ROUND(100.0 * p.date_ct::NUMERIC(18, 5) / p.value_ct::NUMERIC(18, 5), 2) || ' )'::VARCHAR(200)	Likely	Review your source data and ingestion process. Consider whether it might be better to store the date values as a date or datetime column. If the alpha data is also significant, you could store it in a different column.	p.date_ct::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.66
1013	Small Missing Value Ct	Column	Small Percentage of Missing Values Found	Under 3% of values in this column were found to be null, zero-length or dummy values, but values are not universally present. This could indicate unexpected missing values in a required column.	(p.value_ct - p.zero_length_ct - p.filled_value_ct)::FLOAT / p.record_ct::FLOAT > 0.97\n   AND (p.value_ct - p.zero_length_ct - p.filled_value_ct) < p.record_ct	(p.record_ct - (p.value_ct - p.zero_length_ct - p.filled_value_ct))::VARCHAR(20) ||\n          ' of ' || p.record_ct::VARCHAR(20) || ' blank values:  ' ||\n          ROUND(100.0 * (p.record_ct - (p.value_ct - p.zero_length_ct - p.filled_value_ct))::NUMERIC(18, 5)\n                   / NULLIF(p.value_ct, 0)::NUMERIC(18, 5), 2)::VARCHAR(40) || '%'	Possible	Review your source data and follow-up with data owners to determine whether this data needs to be corrected, supplemented or excluded.	(p.null_value_ct + filled_value_ct + zero_length_ct)::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.33
1014	Small Divergent Value Ct	Column	Small Percentage of Divergent Values Found	Under 3% of values in this column were found to be different from the most common value. This could indicate a data error.	(100.0 * fn_parsefreq(p.top_freq_values, 1, 2)::FLOAT /\n        p.value_ct::FLOAT) > 97::FLOAT\n   AND (100.0 * fn_parsefreq(p.top_freq_values, 1, 2)::FLOAT /\n        NULLIF(p.value_ct, 0)::FLOAT) < 100::FLOAT	'Single Value Pct: ' || ROUND(100.0 * fn_parsefreq(p.top_freq_values, 1, 2)::FLOAT\n                                   / NULLIF(p.value_ct, 0)::FLOAT)::VARCHAR(40)\n          || ', Value | Freq: ' || top_freq_values	Possible	Review your source data and follow-up with data owners to determine whether this data needs to be corrected.	(p.record_ct - fn_parsefreq(p.top_freq_values, 1, 2)::INT)::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.33
1015	Boolean_Value_Mismatch	Column	Unexpected Boolean Values Found	This column appears to contain boolean (True/False) data, but unexpected values were found. This could indicate inconsistent coding for the same intended values, potentially leading to downstream errors or inconsistent business logic.  	(distinct_value_ct > 1 AND\n\t\t     ((lower(top_freq_values) ILIKE '| true |%' OR lower(top_freq_values) ILIKE '| false |%') AND NOT (lower(top_freq_values) ILIKE '%| true |%' AND lower(top_freq_values) ILIKE '%| false |%'))\n\t\t  OR ((lower(top_freq_values) ILIKE '| yes |%'  OR lower(top_freq_values) ILIKE '| no |%'   ) AND NOT (lower(top_freq_values) ILIKE '%| yes |%'  AND lower(top_freq_values) ILIKE '%| no |%')) )	CASE WHEN p.top_freq_values IS NULL THEN 'Min: ' || p.min_text || ', Max: ' || p.max_text\n            ELSE 'Top Freq: ' || p.top_freq_values END	Likely	Review your source data and follow-up with data owners to determine whether this data needs to be corrected. 	\N	0.66
1016	Potential_Duplicates	Column	Potential Duplicate Values Found	This column is largely unique, but some duplicate values are present. This pattern is uncommon and could indicate inadvertant duplication. 	p.distinct_value_ct > 1000\n   AND fn_parsefreq(p.top_freq_values, 1, 2)::BIGINT BETWEEN 2 AND 4	'Top Freq: ' || p.top_freq_values	Possible	Review your source data and follow-up with data owners to determine whether this data needs to be corrected. 	(p.value_ct - p.distinct_value_ct)::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.33
1017	Standardized_Value_Matches	Column	Similar Values Match When Standardized	When column values are standardized (removing spaces, single-quotes, periods and dashes), matching values are found in other records. This may indicate that formats should be further standardized to allow consistent comparisons for merges, joins and roll-ups. It could also indicate the presence of unintended duplicates.	p.general_type = 'A' AND p.distinct_std_value_ct <> p.distinct_value_ct	'Distinct Values: ' || p.distinct_value_ct::VARCHAR\n          || ', Standardized: ' || p.distinct_std_value_ct::VARCHAR	Likely	Review standardized vs. raw data values for all matches. Correct data if values should be consistent.	(p.distinct_value_ct - p.distinct_std_value_ct)::FLOAT/NULLIF(p.value_ct, 0)	0.66
1018	Unlikely_Date_Values	Column	Unlikely Dates out of Typical Range	Some date values in this column are earlier than 1900-01-01 or later than 30 years after Profiling date.	p.general_type = 'D'\n   AND (p.min_date BETWEEN '0001-01-02'::DATE AND '1900-01-01'::DATE\n    OR p.max_date > CURRENT_DATE + INTERVAL '30 year')	'Date Range: ' || p.min_date::VARCHAR || ' thru ' || p.max_date::VARCHAR	Likely	Review your source data and follow-up with data owners to determine whether this data needs to be corrected or removed.	(COALESCE(p.before_100yr_date_ct,0)+COALESCE(p.distant_future_date_ct, 0))::FLOAT/NULLIF(p.record_ct, 0)	0.66
1019	Recency_One_Year	Dates	Recency - No Table Dates within 1 Year	Among all date columns present in the table, none fall inside of one year from Profile date.	MAX(p.max_date) < CURRENT_DATE - INTERVAL '1 year'	'Most Recent Date: ' || MAX(p.max_date)::VARCHAR	Possible	Review your source data and follow-up with data owners to determine whether dates in table should be more recent.	\N	\N
1020	Recency_Six_Months	Dates	Recency - No Table Dates within 6 Months	Among all date columns present in the table, the most recent date falls 6 months to 1 year back from Profile date. 	MAX(p.max_date) >= CURRENT_DATE - INTERVAL '1 year' AND MAX(p.max_date) < CURRENT_DATE - INTERVAL '6 months'	'Most Recent Date: ' || MAX(p.max_date)::VARCHAR	Possible	Review your source data and follow-up with data owners to determine whether dates in table should be more recent.	\N	\N
1022	Unexpected Emails	Column	Unexpected Column Contains Emails	This column is not labeled as email, but contains mostly email addresses. This could indicate shifted or switched source data columns.	p.std_pattern_match = 'EMAIL'\n       AND NOT (p.column_name ILIKE '%email%' OR p.column_name ILIKE '%addr%')	'Value Range: ' || p.min_text || ' thru ' || max_text	Possible	Review your source data and follow-up with data owners to determine whether column should be populated with email addresses.	\N	0.33
1023	Small_Numeric_Value_Ct	Column	Unexpected Numeric Values Found	Under 3% of values in this column were found to be numeric. This could indicate a data error.	p.general_type = 'A'\n   AND p.numeric_ct::FLOAT/NULLIF(p.record_ct, 0)::FLOAT < 0.03\n   AND p.numeric_ct > 0	'Numeric Ct: ' || p.numeric_ct || ' of ' || p.value_ct || ' (Numeric Percent: ' || ROUND(100.0 * p.numeric_ct::NUMERIC(18, 5)/NULLIF(p.value_ct, 0)::NUMERIC(18, 5), 2) || ' )'::VARCHAR(200)	Likely	Review your source data and follow-up with data owners to determine whether numeric values are invalid entries here.	p.numeric_ct::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	0.66
1024	Invalid_Zip3_USA	Column	Invalid USA ZIP-3 Format	The majority of values in this column are 3-digit zips, but divergent patterns were found. This could indicate an incorrect roll-up category or a PII concern.	p.distinct_pattern_ct > 1\n   AND (p.column_name ilike '%zip%' OR p.column_name ILIKE '%postal%')\n   AND SPLIT_PART(p.top_patterns, ' | ', 2) = 'NNN'\n   AND SPLIT_PART(p.top_patterns, ' | ', 1)::FLOAT/NULLIF(value_ct, 0)::FLOAT > 0.50	'Pattern: ' || p.top_patterns	Definite	Review your source data, ingestion process, and any processing steps that update this column.	(NULLIF(p.record_ct, 0)::INT - SPLIT_PART(p.top_patterns, ' | ', 1)::INT)::FLOAT/NULLIF(p.record_ct, 0)::FLOAT	1
1025	Delimited_Data_Embedded	Column	Delimited Data Embedded in Column	Delimited data, separated by a common delimiter (comma, tab, pipe or caret) is present in over 80% of column values. This could indicate data that was incorrectly ingested, or data that would be better represented in parsed form.	p.std_pattern_match = 'DELIMITED_DATA'	CASE WHEN p.top_freq_values IS NULL THEN 'Min: ' || p.min_text || ', Max: ' || p.max_text ELSE 'Top Freq: ' || p.top_freq_values END	Likely	Review your source data and follow-up with data consumers to determine the most useful representation of this data.	\N	0.66
1026	Char_Column_Number_Units	Column	Character Column with Numbers and Units	This column is defined as alpha, but values include numbers with percents or common units. Embedded measures in alpha columns are harder to access, won't sort correctly, and might contradict user expectations downstream. Consider parsing into numeric and UOM columns to improve usability.	p.includes_digit_ct::FLOAT/NULLIF(p.value_ct, 0)::FLOAT > 0.5 AND TRIM(fn_parsefreq(p.top_freq_values, 1, 1))  ~ '(?i)^[0-9]+(\\.[0-9]+)? ?(%|lb|oz|kg|g|mg|km|m|cm|mm|mi|ft|in)$'	'Top Freq: ' || p.top_freq_values	Possible	Review your source data and ingestion process. Consider whether it might be better to parse the numeric and unit data and store in separate columns.	\N	0.33
1027	Variant_Coded_Values	Variant	Variant Codings for Same Values	This column contains more than one common variants that represent a single value or state. This can occur when data is integrated from multiple sources with different standards, or when free entry is permitted without validation. The variations can cause confusion and error for downstream data users and multiple versions of the truth. 	p.distinct_value_ct <= 20	'Variants Found: ' || intersect_list	Definite	Review your source data and ingestion process. Consider cleansing this data to standardize on a single set of definitive codes.	\N	\N
1100	Potential_PII	Column	Personally Identifiable Information	This column contains data that could be Personally Identifiable Information (PII)	p.pii_flag > ''	'Risk: ' || CASE LEFT(p.pii_flag, 1) WHEN 'A' THEN 'HIGH' WHEN 'B' THEN 'MODERATE' WHEN 'C' THEN 'LOW' END || ', PII Type: ' || SUBSTRING(p.pii_flag, 3)	Potential PII	PII may require steps to ensure data security and compliance with relevant privacy regulations and legal requirements. You may have to classify and inventory PII, implement appropriate access controls, encrypt data, and monitor for unauthorized access. Your organization might be required to update privacy policies and train staff on data protection practices. Note that PII that is lower-risk in isolation might be high-risk in conjunction with other data.	\N	CASE LEFT(p.pii_flag, 1) WHEN 'A' THEN 1 WHEN 'B' THEN 0.66 WHEN 'C' THEN 0.33 END
\.


--
-- Data for Name: profile_pair_rules; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.profile_pair_rules (id, profile_run_id, schema_name, table_name, cause_column_name, cause_column_value, effect_column_name, effect_column_value, pair_count, cause_column_total, effect_column_total, rule_ratio) FROM stdin;
\.


--
-- Data for Name: profile_results; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.profile_results (id, dk_id, project_code, connection_id, table_groups_id, profile_run_id, schema_name, run_date, table_name, "position", column_name, column_type, general_type, record_ct, value_ct, distinct_value_ct, distinct_std_value_ct, null_value_ct, min_length, max_length, avg_length, zero_value_ct, zero_length_ct, lead_space_ct, quoted_value_ct, includes_digit_ct, filled_value_ct, min_text, max_text, upper_case_ct, lower_case_ct, non_alpha_ct, numeric_ct, date_ct, top_patterns, top_freq_values, distinct_value_hash, min_value, min_value_over_0, max_value, avg_value, stdev_value, percentile_25, percentile_50, percentile_75, fractional_sum, min_date, max_date, before_1yr_date_ct, before_5yr_date_ct, before_20yr_date_ct, before_100yr_date_ct, within_1yr_date_ct, within_1mo_date_ct, future_date_ct, distant_future_date_ct, date_days_present, date_weeks_present, date_months_present, boolean_true_ct, datatype_suggestion, distinct_pattern_ct, embedded_space_ct, avg_embedded_spaces, std_pattern_match, pii_flag, functional_data_type, functional_table_type, sample_ratio) FROM stdin;
\.


--
-- Data for Name: profiling_runs; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.profiling_runs (id, project_code, connection_id, table_groups_id, profiling_starttime, profiling_endtime, status, log_message, table_ct, column_ct, anomaly_ct, anomaly_table_ct, anomaly_column_ct, dq_affected_data_points, dq_total_data_points, dq_score_profiling, process_id) FROM stdin;
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.projects (id, project_code, project_name, effective_from_date, effective_thru_date, observability_api_key, observability_api_url) FROM stdin;
2daa3e80-824a-475d-a86a-82c236aa64ee	DEFAULT	Demo	2024-12-14	\N		
\.


--
-- Data for Name: stg_functional_table_updates; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.stg_functional_table_updates (project_code, schema_name, run_date, table_name, table_period, table_type) FROM stdin;
\.


--
-- Data for Name: stg_secondary_profile_updates; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.stg_secondary_profile_updates (project_code, schema_name, run_date, table_name, column_name, top_freq_values, distinct_value_hash) FROM stdin;
\.


--
-- Data for Name: table_groups; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.table_groups (id, project_code, connection_id, table_groups_name, table_group_schema, profiling_table_set, profiling_include_mask, profiling_exclude_mask, profile_id_column_mask, profile_sk_column_mask, profile_use_sampling, profile_sample_percent, profile_sample_min_count, profiling_delay_days, profile_do_pair_rules, profile_pair_rule_pct, data_source, source_system, data_location, source_process, business_domain, stakeholder_group, transform_level, last_complete_profile_run_id, dq_score_profiling, dq_score_testing) FROM stdin;
0ea85e17-acbe-47fe-8394-9970725ad37d	DEFAULT	1	default	demo	\N	%	tmp%	%id	%_sk	N	30	15000	0	N	95	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: target_data_lookups; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.target_data_lookups (id, test_id, test_type, sql_flavor, lookup_type, lookup_query, error_type) FROM stdin;
1001	1004	Alpha_Trunc	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", LEN("{COLUMN_NAME}") as current_max_length, {THRESHOLD_VALUE} as previous_max_length FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT MAX(LEN("{COLUMN_NAME}")) as max_length FROM {TARGET_SCHEMA}.{TABLE_NAME}) a WHERE LEN("{COLUMN_NAME}") = a.max_length AND a.max_length < {THRESHOLD_VALUE} LIMIT 500;	Test Results
1002	1005	Avg_Shift	redshift	\N	SELECT AVG("{COLUMN_NAME}" :: FLOAT) AS current_average FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1003	1006	Condition_Flag	redshift	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {CUSTOM_QUERY} LIMIT 500;	Test Results
1004	1007	Constant	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" <> {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1005	1009	Daily_Record_Ct	redshift	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT MIN("{COLUMN_NAME}") :: DATE AS all_dates FROM {TARGET_SCHEMA}.{TABLE_NAME} UNION ALL SELECT DATEADD(DAY, 1, d.all_dates) :: DATE AS all_dates FROM daterange d WHERE d.all_dates < (SELECT MAX("{COLUMN_NAME}") :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS (  SELECT DISTINCT "{COLUMN_NAME}" :: DATE AS period, COUNT(1) AS period_count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" :: DATE ) SELECT d.all_dates AS missing_period, MAX(b.period) AS prior_available_date, (SELECT period_count FROM existing_periods WHERE period = MAX(b.period) ) AS prior_available_date_count, MIN(c.period) AS next_available_date, (SELECT period_count FROM existing_periods WHERE period = MIN(c.period) ) AS next_available_date_count FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates ORDER BY d.all_dates LIMIT 500;	Test Results
1006	1011	Dec_Trunc	redshift	\N	SELECT DISTINCT DECIMAL_SCALE("{COLUMN_NAME}" :: SUPER) AS decimal_scale, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DECIMAL_SCALE("{COLUMN_NAME}" :: SUPER) LIMIT 500;	Test Results
1007	1012	Distinct_Date_Ct	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Test Results
1008	1013	Distinct_Value_Ct	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Test Results
1009	1014	Email_Format	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" !~ '^[A-Za-z0-9._''%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1010	1015	Future_Date	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE GREATEST(0, SIGN("{COLUMN_NAME}"::DATE - '{TEST_DATE}'::DATE)) > {THRESHOLD_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1011	1016	Future_Date_1Y	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE GREATEST(0, SIGN("{COLUMN_NAME}"::DATE - ('{TEST_DATE}'::DATE + 365))) > {THRESHOLD_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1012	1017	Incr_Avg_Shift	redshift	\N	SELECT AVG("{COLUMN_NAME}" :: FLOAT) AS current_average, SUM("{COLUMN_NAME}" ::FLOAT) AS current_sum, NULLIF(COUNT("{COLUMN_NAME}" )::FLOAT, 0) as current_value_count FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1013	1018	LOV_All	redshift	\N	SELECT LISTAGG(DISTINCT "{COLUMN_NAME}", '|') WITHIN GROUP (ORDER BY "{COLUMN_NAME}") FROM {TARGET_SCHEMA}.{TABLE_NAME} HAVING LISTAGG(DISTINCT "{COLUMN_NAME}", '|') WITHIN GROUP (ORDER BY "{COLUMN_NAME}") <> '{THRESHOLD_VALUE}' LIMIT 500;	Test Results
1014	1019	LOV_Match	redshift	\N	SELECT DISTINCT NULLIF("{COLUMN_NAME}", '') AS "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT IN {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1015	1020	Min_Date	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}",  COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: DATE < '{BASELINE_VALUE}' :: DATE GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1016	1021	Min_Val	redshift	\N	SELECT DISTINCT  "{COLUMN_NAME}", (ABS("{COLUMN_NAME}") - ABS({BASELINE_VALUE})) AS difference_from_baseline FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" < {BASELINE_VALUE} LIMIT 500;	Test Results
1017	1022	Missing_Pct	redshift	\N	SELECT TOP 10 * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL OR "{COLUMN_NAME}" :: VARCHAR(255) = '' ;	Test Results
1018	1023	Monthly_Rec_Ct	redshift	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT DATE_TRUNC('month', MIN("{COLUMN_NAME}")) :: DATE AS all_dates FROM {TARGET_SCHEMA}.{TABLE_NAME} UNION ALL SELECT DATEADD(MONTH, 1, d.all_dates) :: DATE AS all_dates FROM daterange d WHERE d.all_dates < (SELECT DATE_TRUNC('month', MAX("{COLUMN_NAME}")) :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS ( SELECT DISTINCT DATE_TRUNC('month',"{COLUMN_NAME}") :: DATE AS period, COUNT(1) AS period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DATE_TRUNC('month',"{COLUMN_NAME}") :: DATE ) SELECT d.all_dates as missing_period, MAX(b.period) AS prior_available_month, (SELECT period_count FROM existing_periods WHERE period = MAX(b.period) ) AS prior_available_month_count, MIN(c.period) AS next_available_month, (SELECT period_count FROM existing_periods WHERE period = MIN(c.period) ) AS next_available_month_count FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND  d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates ORDER BY d.all_dates;	Test Results
1019	1024	Outlier_Pct_Above	redshift	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: FLOAT > ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1020	1025	Outlier_Pct_Below	redshift	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: FLOAT < ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1021	1026	Pattern_Match	redshift	\N	SELECT DISTINCT  "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT SIMILAR TO '{BASELINE_VALUE}' GROUP BY "{COLUMN_NAME}";	Test Results
1022	1028	Recency	redshift	\N	SELECT DISTINCT col AS latest_date_available, '{TEST_DATE}' :: DATE as test_run_date FROM (SELECT MAX("{COLUMN_NAME}") AS col FROM {TARGET_SCHEMA}.{TABLE_NAME}) WHERE DATEDIFF('D', col, '{TEST_DATE}'::DATE) > {THRESHOLD_VALUE};	Test Results
1023	1030	Required	redshift	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL LIMIT 500;	Test Results
1024	1031	Row_Ct	redshift	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, ABS(ROUND(100 * (current_count - {THRESHOLD_VALUE}) :: FLOAT / {THRESHOLD_VALUE} :: FLOAT,2)) AS row_count_pct_decrease FROM cte WHERE current_count < {THRESHOLD_VALUE};	Test Results
1025	1032	Row_Ct_Pct	redshift	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, {BASELINE_CT} AS baseline_count, ABS(ROUND(100 * (current_count - {BASELINE_CT}) :: FLOAT / {BASELINE_CT} :: FLOAT,2)) AS row_count_pct_difference FROM cte;	Test Results
1026	1033	Street_Addr_Pattern	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" !~ '^[0-9]{1,5}[a-zA-Z]?\\\\s\\\\w{1,5}\\\\.?\\\\s?\\\\w*\\\\s?\\\\w*\\\\s[a-zA-Z]{1,6}\\\\.?\\\\s?[0-9]{0,5}[A-Z]{0,1}$' GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1027	1036	US_State	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE  NULLIF("{COLUMN_NAME}", '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1028	1034	Unique	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*) > 1 ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1029	1035	Unique_Pct	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1030	1037	Weekly_Rec_Ct	redshift	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT DATE_TRUNC('week',MIN("{COLUMN_NAME}")) :: DATE AS all_dates FROM {TARGET_SCHEMA}.{TABLE_NAME} UNION ALL SELECT (d.all_dates + INTERVAL '1 week' ) :: DATE AS all_dates FROM daterange d WHERE d.all_dates < (SELECT DATE_TRUNC('week', MAX("{COLUMN_NAME}")) :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ),  existing_periods AS ( SELECT DISTINCT DATE_TRUNC('week',"{COLUMN_NAME}") :: DATE AS period, COUNT(1) as period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DATE_TRUNC('week',"{COLUMN_NAME}") :: DATE ) SELECT d.all_dates as missing_period, MAX(b.period) AS prior_available_week, (SELECT period_count FROM existing_periods WHERE period = MAX(b.period) ) AS prior_available_week_count, MIN(c.period) AS next_available_week, (SELECT period_count FROM existing_periods WHERE period = MIN(c.period) ) AS next_available_week_count FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND  d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates ORDER BY d.all_dates;	Test Results
1031	1040	Variability_Increase	redshift	\N	SELECT STDDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1032	1041	Variability_Decrease	redshift	\N	SELECT STDDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1033	1001	Suggested_Type	redshift	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Profile Anomaly
1034	1002	Non_Standard_Blanks	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1 WHEN LOWER("{COLUMN_NAME}") SIMILAR TO '(^.{2,}|-{2,}|0{2,}|9{2,}|x{2,}|z{2,}$)' THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END = 1  GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1035	1003	Invalid_Zip_USA	redshift	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" LIMIT 500;	Profile Anomaly
1036	1004	Multiple_Types_Minor	redshift	\N	SELECT DISTINCT column_name, table_name,  CASE WHEN data_type = 'timestamp without time zone' THEN 'timestamp' WHEN data_type = 'character varying'     THEN 'varchar(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'character' THEN 'char(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'numeric' THEN 'numeric(' || CAST(numeric_precision AS VARCHAR) || ',' ||  CAST(numeric_scale AS VARCHAR) || ')' ELSE data_type END AS data_type FROM information_schema.columns WHERE table_schema = '{TARGET_SCHEMA}'   AND column_name = '{COLUMN_NAME}' ORDER BY data_type, table_name;	Profile Anomaly
1037	1005	Multiple_Types_Major	redshift	\N	SELECT DISTINCT column_name, table_name,  CASE WHEN data_type = 'timestamp without time zone' THEN 'timestamp' WHEN data_type = 'character varying'     THEN 'varchar(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'character' THEN 'char(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'numeric' THEN 'numeric(' || CAST(numeric_precision AS VARCHAR) || ',' ||  CAST(numeric_scale AS VARCHAR) || ')' ELSE data_type END AS data_type FROM information_schema.columns WHERE table_schema = '{TARGET_SCHEMA}'   AND column_name = '{COLUMN_NAME}' ORDER BY data_type, table_name;	Profile Anomaly
1038	1006	No_Values	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1057	1025	Delimited_Data_Embedded	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" ~ '^([^,|\\t]{1,20}[,|\\t]){2,}[^,|\\t]{0,20}([,|\\t]{0,1}[^,|\\t]{0,20})*$' AND "{COLUMN_NAME}" !~ '\\\\s(and|but|or|yet)\\\\s' GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Profile Anomaly
1058	1001	Suggested_Type	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC LIMIT 20;	Profile Anomaly
1059	1002	Non_Standard_Blanks	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1 WHEN LOWER("{COLUMN_NAME}") SIMILAR TO '(^.{2,}|-{2,}|0{2,}|9{2,}|x{2,}|z{2,}$)' THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown')  THEN 1  WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1039	1007	Column_Pattern_Mismatch	redshift	\N	SELECT A.*  FROM (  SELECT TOP 5 DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count   FROM {TARGET_SCHEMA}.{TABLE_NAME},       (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 4)) AS top_pattern) b   WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a'),'[A-Z]', 'A'),'[0-9]', 'N') = b.top_pattern   GROUP BY b.top_pattern, "{COLUMN_NAME}"   ORDER BY count DESC       ) A  UNION ALL  SELECT B.*  FROM (  SELECT TOP 5 DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME},      (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 6)) AS top_pattern) b  WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a'),'[A-Z]', 'A'),'[0-9]', 'N') = b.top_pattern  GROUP BY b.top_pattern, "{COLUMN_NAME}"  ORDER BY count DESC       ) B  UNION ALL  SELECT C.*  FROM (  SELECT TOP 5 DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME},      (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 8)) AS top_pattern) b  WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a'),'[A-Z]', 'A'),'[0-9]', 'N') = b.top_pattern  GROUP BY b.top_pattern, "{COLUMN_NAME}"  ORDER BY count DESC       ) C  UNION ALL  SELECT D.*  FROM (  SELECT TOP 5 DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME},      (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 10)) AS top_pattern) b  WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a'),'[A-Z]', 'A'),'[0-9]', 'N') = b.top_pattern  GROUP BY b.top_pattern, "{COLUMN_NAME}"  ORDER BY count DESC  ) D  ORDER BY top_pattern DESC, count DESC;	Profile Anomaly
1040	1008	Table_Pattern_Mismatch	redshift	\N	SELECT column_name, table_name, data_type FROM information_schema.columns WHERE table_schema = '{TARGET_SCHEMA}'   AND column_name = '{COLUMN_NAME}' ORDER BY data_type;	Profile Anomaly
1041	1009	Leading_Spaces	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" BETWEEN ' !' AND '!' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1042	1010	Quoted_Values	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" ILIKE '"%"' OR "{COLUMN_NAME}" ILIKE '''%''' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1043	1011	Char_Column_Number_Values	redshift	\N	SELECT A.* FROM (  SELECT TOP 10 DISTINCT 'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS A UNION ALL SELECT B.* FROM  ( SELECT TOP 10 DISTINCT 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1044	1012	Char_Column_Date_Values	redshift	\N	SELECT A.* FROM (  SELECT TOP 10 DISTINCT 'Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC ) AS A UNION ALL SELECT B.* FROM  ( SELECT TOP 10 DISTINCT 'Non-Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1045	1013	Small Missing Value Ct	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1 WHEN LOWER("{COLUMN_NAME}") SIMILAR TO '(^.{2,}|-{2,}|0{2,}|9{2,}|x{2,}|z{2,}$)' THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown')           THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1046	1014	Small Divergent Value Ct	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1047	1015	Boolean_Value_Mismatch	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1048	1016	Potential_Duplicates	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*)> 1 ORDER BY COUNT(*) DESC LIMIT 500;	Profile Anomaly
1049	1017	Standardized_Value_Matches	redshift	\N	WITH CTE AS ( SELECT DISTINCT UPPER(TRANSLATE("{COLUMN_NAME}", ' '',.-', '')) as possible_standard_value,                 COUNT(DISTINCT "{COLUMN_NAME}") FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY UPPER(TRANSLATE("{COLUMN_NAME}", ' '',.-', '')) HAVING COUNT(DISTINCT "{COLUMN_NAME}") > 1 ) SELECT DISTINCT a."{COLUMN_NAME}", possible_standard_value, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte b WHERE UPPER(TRANSLATE(a."{COLUMN_NAME}", ' '',.-', '')) = b.possible_standard_value GROUP BY a."{COLUMN_NAME}", possible_standard_value ORDER BY possible_standard_value ASC, count DESC LIMIT 500;	Profile Anomaly
1050	1018	Unlikely_Date_Values	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", '{PROFILE_RUN_DATE}' :: DATE AS profile_run_date, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a WHERE ("{COLUMN_NAME}" < '1900-01-01'::DATE) OR ("{COLUMN_NAME}" > '{PROFILE_RUN_DATE}' :: DATE + INTERVAL '30 year' ) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1051	1019	Recency_One_Year	redshift	\N	created_in_ui	Profile Anomaly
1052	1020	Recency_Six_Months	redshift	\N	created_in_ui	Profile Anomaly
1053	1021	Unexpected US States	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1054	1022	Unexpected Emails	redshift	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1055	1023	Small_Numeric_Value_Ct	redshift	\N	SELECT A.* FROM (  SELECT TOP 10 DISTINCT 'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS A UNION ALL SELECT B.* FROM  ( SELECT TOP 10 DISTINCT 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1056	1024	Invalid_Zip3_USA	redshift	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') <> '999' GROUP BY "{COLUMN_NAME}" ORDER BY count DESC, "{COLUMN_NAME}" LIMIT 500;	Profile Anomaly
1060	1003	Invalid_Zip_USA	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" LIMIT 500;	Profile Anomaly
1061	1004	Multiple_Types_Minor	postgresql	\N	SELECT DISTINCT column_name, columns.table_name, CASE WHEN data_type = 'timestamp without time zone' THEN 'timestamp' WHEN data_type = 'character varying' THEN 'varchar(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'character'  THEN 'char(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'numeric' THEN 'numeric(' || CAST(numeric_precision AS VARCHAR) || ',' ||  CAST(numeric_scale AS VARCHAR) || ')' ELSE data_type END AS data_type FROM information_schema.columns  JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}'  AND columns.column_name = '{COLUMN_NAME}' AND UPPER(tables.table_type) = 'BASE TABLE' ORDER BY data_type, table_name;	Profile Anomaly
1062	1005	Multiple_Types_Major	postgresql	\N	SELECT DISTINCT column_name, columns.table_name, CASE WHEN data_type = 'timestamp without time zone' THEN 'timestamp' WHEN data_type = 'character varying' THEN 'varchar(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'character'  THEN 'char(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'numeric' THEN 'numeric(' || CAST(numeric_precision AS VARCHAR) || ',' ||  CAST(numeric_scale AS VARCHAR) || ')' ELSE data_type END AS data_type FROM information_schema.columns  JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}'  AND columns.column_name = '{COLUMN_NAME}' AND UPPER(tables.table_type) = 'BASE TABLE' ORDER BY data_type, table_name;	Profile Anomaly
1063	1006	No_Values	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1064	1007	Column_Pattern_Mismatch	postgresql	\N	SELECT A.* FROM (  SELECT DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 4)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a', 'g'), '[A-Z]', 'A', 'g'), '[0-9]', 'N', 'g') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC LIMIT 5 ) A UNION ALL SELECT B.* FROM (  SELECT DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 6)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a', 'g'), '[A-Z]', 'A', 'g'), '[0-9]', 'N', 'g') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC LIMIT 5 ) B UNION ALL SELECT C.* FROM (  SELECT DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 8)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a', 'g'), '[A-Z]', 'A', 'g'), '[0-9]', 'N', 'g') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC LIMIT 5 ) C UNION ALL SELECT D.* FROM (  SELECT DISTINCT b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 10)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}", '[a-z]', 'a', 'g'), '[A-Z]', 'A', 'g'), '[0-9]', 'N', 'g') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC LIMIT 5) D ORDER BY top_pattern DESC, count DESC;	Profile Anomaly
1065	1008	Table_Pattern_Mismatch	postgresql	\N	SELECT column_name, columns.table_name FROM information_schema.columns JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND UPPER(tables.table_type) = 'BASE TABLE' ORDER BY columns.table_name;	Profile Anomaly
1066	1009	Leading_Spaces	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" BETWEEN ' !' AND '!' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1067	1010	Quoted_Values	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" ILIKE '"%"' OR "{COLUMN_NAME}" ILIKE '''%''' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1068	1011	Char_Column_Number_Values	postgresql	\N	SELECT A.* FROM (  SELECT DISTINCT 'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC LIMIT 10 ) AS A UNION ALL SELECT B.* FROM  ( SELECT DISTINCT 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC LIMIT 10 )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1069	1012	Char_Column_Date_Values	postgresql	\N	SELECT A.* FROM (  SELECT  DISTINCT 'Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC LIMIT 10) AS A UNION ALL SELECT B.* FROM  ( SELECT DISTINCT 'Non-Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC LIMIT 10)  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1070	1013	Small Missing Value Ct	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}  WHERE (CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1  WHEN LOWER("{COLUMN_NAME}") SIMILAR TO '(^.{2,}|-{2,}|0{2,}|9{2,}|x{2,}|z{2,}$)' THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown')  THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1  WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1071	1014	Small Divergent Value Ct	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1072	1015	Boolean_Value_Mismatch	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1073	1016	Potential_Duplicates	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*)> 1 ORDER BY COUNT(*) DESC LIMIT 500;	Profile Anomaly
1074	1017	Standardized_Value_Matches	postgresql	\N	WITH CTE AS ( SELECT DISTINCT UPPER(TRANSLATE("{COLUMN_NAME}", ' '',.-', '')) as possible_standard_value, COUNT(DISTINCT "{COLUMN_NAME}") FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY UPPER(TRANSLATE("{COLUMN_NAME}", ' '',.-', '')) HAVING COUNT(DISTINCT "{COLUMN_NAME}") > 1 ) SELECT DISTINCT a."{COLUMN_NAME}", possible_standard_value, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte b WHERE UPPER(TRANSLATE(a."{COLUMN_NAME}", ' '',.-', '')) = b.possible_standard_value GROUP BY a."{COLUMN_NAME}", possible_standard_value ORDER BY possible_standard_value ASC, count DESC LIMIT 500;	Profile Anomaly
1075	1018	Unlikely_Date_Values	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", '{PROFILE_RUN_DATE}' :: DATE AS profile_run_date, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a WHERE ("{COLUMN_NAME}" < '1900-01-01'::DATE) OR ("{COLUMN_NAME}" > '{PROFILE_RUN_DATE}' :: DATE  + INTERVAL '30 year' ) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1076	1019	Recency_One_Year	postgresql	\N	created_in_ui	Profile Anomaly
1077	1020	Recency_Six_Months	postgresql	\N	created_in_ui	Profile Anomaly
1078	1021	Unexpected US States	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1079	1022	Unexpected Emails	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1080	1023	Small_Numeric_Value_Ct	postgresql	\N	SELECT A.* FROM (  SELECT DISTINCT 'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC LIMIT 10 ) AS A UNION ALL SELECT B.* FROM  ( SELECT DISTINCT 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}"  ORDER BY count DESC LIMIT 10 )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1081	1024	Invalid_Zip3_USA	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') <> '999' GROUP BY "{COLUMN_NAME}" ORDER BY count DESC, "{COLUMN_NAME}" LIMIT 500;	Profile Anomaly
1082	1025	Delimited_Data_Embedded	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" ~ '^([^,|\\t]{1,20}[,|\\t]){2,}[^,|\\t]{0,20}([,|\\t]{0,1}[^,|\\t]{0,20})*$' AND "{COLUMN_NAME}" !~ '\\s(and|but|or|yet)\\s' GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Profile Anomaly
1083	1004	Alpha_Trunc	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", LENGTH("{COLUMN_NAME}") as current_max_length,  {THRESHOLD_VALUE} as previous_max_length  FROM {TARGET_SCHEMA}.{TABLE_NAME},  (SELECT MAX(LENGTH("{COLUMN_NAME}")) as max_length  FROM {TARGET_SCHEMA}.{TABLE_NAME}) a  WHERE LENGTH("{COLUMN_NAME}") = a.max_length AND a.max_length < {THRESHOLD_VALUE} LIMIT 500;	Test Results
1084	1005	Avg_Shift	postgresql	\N	SELECT AVG("{COLUMN_NAME}" :: FLOAT) AS current_average FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1085	1006	Condition_Flag	postgresql	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {CUSTOM_QUERY} LIMIT 500;	Test Results
1086	1007	Constant	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" <> {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1087	1009	Daily_Record_Ct	postgresql	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT MIN("{COLUMN_NAME}") :: DATE AS all_dates FROM {TARGET_SCHEMA}.{TABLE_NAME} UNION ALL SELECT (d.all_dates :: DATE + INTERVAL '1 day') :: DATE AS all_dates FROM daterange d WHERE d.all_dates < (SELECT MAX("{COLUMN_NAME}") :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS ( SELECT DISTINCT "{COLUMN_NAME}" :: DATE AS period, COUNT(1) AS period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" :: DATE ) SELECT d.all_dates AS missing_period, MAX(b.period) AS prior_available_date, (SELECT period_count FROM existing_periods WHERE period = MAX(b.period) ) AS prior_available_date_count, MIN(c.period) AS next_available_date, (SELECT period_count FROM existing_periods WHERE period = MIN(c.period) ) AS next_available_date_count FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates LIMIT 500;	Test Results
1088	1011	Dec_Trunc	postgresql	\N	SELECT DISTINCT LENGTH(SPLIT_PART("{COLUMN_NAME}" :: TEXT, '.', 2)) AS decimal_scale, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY decimal_scale LIMIT 500;	Test Results
1089	1012	Distinct_Date_Ct	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Test Results
1090	1013	Distinct_Value_Ct	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Test Results
1091	1014	Email_Format	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1092	1015	Future_Date	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE GREATEST(0, SIGN("{COLUMN_NAME}"::DATE - '{TEST_DATE}'::DATE)) > {THRESHOLD_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1093	1016	Future_Date_1Y	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE GREATEST(0, SIGN("{COLUMN_NAME}"::DATE - ('{TEST_DATE}'::DATE + 365))) > {THRESHOLD_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1094	1017	Incr_Avg_Shift	postgresql	\N	SELECT AVG("{COLUMN_NAME}" :: FLOAT) AS current_average, SUM("{COLUMN_NAME}" ::FLOAT) AS current_sum, NULLIF(COUNT("{COLUMN_NAME}" )::FLOAT, 0) as current_value_count FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1095	1018	LOV_All	postgresql	\N	SELECT STRING_AGG(DISTINCT "{COLUMN_NAME}", '|' ORDER BY "{COLUMN_NAME}" ASC) FROM {TARGET_SCHEMA}.{TABLE_NAME} HAVING STRING_AGG(DISTINCT "{COLUMN_NAME}", '|' ORDER BY "{COLUMN_NAME}" ASC) <> '{THRESHOLD_VALUE}' LIMIT 500;	Test Results
1096	1019	LOV_Match	postgresql	\N	SELECT DISTINCT NULLIF("{COLUMN_NAME}", '') AS "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT IN {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1097	1020	Min_Date	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}",  COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: DATE < '{BASELINE_VALUE}' :: DATE GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1098	1021	Min_Val	postgresql	\N	SELECT DISTINCT  "{COLUMN_NAME}", (ABS("{COLUMN_NAME}") - ABS({BASELINE_VALUE})) AS difference_from_baseline FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" < {BASELINE_VALUE} LIMIT 500;	Test Results
1099	1022	Missing_Pct	postgresql	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL OR "{COLUMN_NAME}" :: VARCHAR(255) = '' LIMIT 10;	Test Results
1100	1023	Monthly_Rec_Ct	postgresql	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT DATE_TRUNC('month', MIN("{COLUMN_NAME}")) :: DATE AS all_dates  FROM {TARGET_SCHEMA}.{TABLE_NAME}  UNION ALL  SELECT (d.all_dates :: DATE + INTERVAL '1 month') :: DATE AS all_dates  FROM daterange d  WHERE d.all_dates < (SELECT DATE_TRUNC('month', MAX("{COLUMN_NAME}")) :: DATE  FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS ( SELECT DISTINCT DATE_TRUNC('month',"{COLUMN_NAME}") :: DATE AS period, COUNT(1) AS period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DATE_TRUNC('month',"{COLUMN_NAME}") :: DATE ) SELECT d.all_dates as missing_period, MAX(b.period) AS prior_available_month, (SELECT period_count FROM existing_periods WHERE period = MAX(b.period) ) AS prior_available_month_count, MIN(c.period) AS next_available_month, (SELECT period_count FROM existing_periods WHERE period = MIN(c.period) ) AS next_available_month_count FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND  d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates ORDER BY d.all_dates;	Test Results
1101	1024	Outlier_Pct_Above	postgresql	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: FLOAT > ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1102	1025	Outlier_Pct_Below	postgresql	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: FLOAT < ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1103	1026	Pattern_Match	postgresql	\N	SELECT DISTINCT  "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT SIMILAR TO '{BASELINE_VALUE}' GROUP BY "{COLUMN_NAME}";	Test Results
1104	1028	Recency	postgresql	\N	SELECT DISTINCT col AS latest_date_available, '{TEST_DATE}' :: DATE as test_run_date FROM (SELECT MAX("{COLUMN_NAME}") AS col FROM {TARGET_SCHEMA}.{TABLE_NAME}) a WHERE {{DKFN_DATEDIFF_DAY;;col;;'{TEST_DATE}'::DATE}} > {THRESHOLD_VALUE};	Test Results
1105	1030	Required	postgresql	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL LIMIT 500;	Test Results
1106	1031	Row_Ct	postgresql	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, ABS(ROUND(100 * (current_count - {THRESHOLD_VALUE}) :: NUMERIC / {THRESHOLD_VALUE} :: NUMERIC,2)) AS row_count_pct_decrease FROM cte WHERE current_count < {THRESHOLD_VALUE};	Test Results
1107	1032	Row_Ct_Pct	postgresql	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, {BASELINE_CT} AS baseline_count, ABS(ROUND(100 * (current_count - {BASELINE_CT}) :: NUMERIC / {BASELINE_CT} :: NUMERIC,2)) AS row_count_pct_difference FROM cte;	Test Results
1108	1033	Street_Addr_Pattern	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" !~ '^[0-9]{1,5}[a-zA-Z]?\\s\\w{1,5}\\.?\\s?\\w*\\s?\\w*\\s[a-zA-Z]{1,6}\\.?\\s?[0-9]{0,5}[A-Z]{0,1}$' GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1109	1036	US_State	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE  NULLIF("{COLUMN_NAME}", '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1110	1034	Unique	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*) > 1 ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1111	1035	Unique_Pct	postgresql	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1112	1037	Weekly_Rec_Ct	postgresql	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT DATE_TRUNC('week', MIN("{COLUMN_NAME}")) :: DATE AS all_dates FROM {TARGET_SCHEMA}.{TABLE_NAME} UNION ALL SELECT (d.all_dates + INTERVAL '1 week' ) :: DATE AS all_dates FROM daterange d WHERE d.all_dates < (SELECT DATE_TRUNC('week' , MAX("{COLUMN_NAME}")) :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS (SELECT DISTINCT DATE_TRUNC('week', "{COLUMN_NAME}") :: DATE AS period, COUNT(1) as period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DATE_TRUNC('week', "{COLUMN_NAME}") :: DATE) SELECT d.all_dates as missing_period, MAX(b.period) AS prior_available_week, (SELECT period_count FROM existing_periods WHERE period = MAX(b.period) ) AS prior_available_week_count, MIN(c.period) AS next_available_week, (SELECT period_count FROM existing_periods WHERE period = MIN(c.period) ) AS next_available_week_count FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates ORDER BY d.all_dates;	Test Results
1113	1040	Variability_Increase	postgresql	\N	SELECT STDDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1114	1041	Variability_Decrease	postgresql	\N	SELECT STDDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1115	1001	Suggested_Type	mssql	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Profile Anomaly
1127	1013	Small Missing Value Ct	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1 WHEN LEN("{COLUMN_NAME}") > 1 AND ( LOWER("{COLUMN_NAME}") LIKE '%..%' OR  LOWER("{COLUMN_NAME}") LIKE '%--%' OR (LEN(REPLACE("{COLUMN_NAME}", '0', ''))= 0 ) OR (LEN(REPLACE("{COLUMN_NAME}", '9', ''))= 0 ) OR (LEN(REPLACE(LOWER("{COLUMN_NAME}"), 'x', ''))= 0 ) OR (LEN(REPLACE(LOWER("{COLUMN_NAME}"), 'z', ''))= 0 ) )  THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown')  THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1116	1002	Non_Standard_Blanks	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CASE WHEN "{COLUMN_NAME}" IN ('.', '?') OR "{COLUMN_NAME}" LIKE ' ' THEN 1 WHEN LEN("{COLUMN_NAME}") > 1 AND ( LOWER("{COLUMN_NAME}") LIKE '%..%' OR  LOWER("{COLUMN_NAME}") LIKE '%--%'  OR (LEN(REPLACE("{COLUMN_NAME}", '0', ''))= 0 )  OR (LEN(REPLACE("{COLUMN_NAME}", '9', ''))= 0 )  OR (LEN(REPLACE(LOWER("{COLUMN_NAME}"), 'x', ''))= 0 )  OR (LEN(REPLACE(LOWER("{COLUMN_NAME}"), 'z', ''))= 0 )   )  THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1117	1003	Invalid_Zip_USA	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1118	1004	Multiple_Types_Minor	mssql	\N	SELECT TOP 500 column_name, columns.table_name, CASE WHEN data_type = 'datetime' THEN 'datetime' WHEN data_type = 'datetime2' THEN 'datetime' WHEN data_type = 'varchar' THEN 'varchar(' + CAST(character_maximum_length AS VARCHAR) + ')' WHEN data_type = 'char' THEN 'char(' + CAST(character_maximum_length AS VARCHAR) + ')' WHEN data_type = 'numeric' THEN 'numeric(' + CAST(numeric_precision AS VARCHAR) + ',' + CAST(numeric_scale AS VARCHAR) + ')' ELSE data_type END AS data_type FROM information_schema.columns JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND tables.table_type = 'BASE TABLE' ORDER BY data_type, table_name;	Profile Anomaly
1119	1005	Multiple_Types_Major	mssql	\N	SELECT TOP 500 column_name, columns.table_name, CASE WHEN data_type = 'datetime' THEN 'datetime' WHEN data_type = 'datetime2' THEN 'datetime' WHEN data_type = 'varchar' THEN 'varchar(' + CAST(character_maximum_length AS VARCHAR) + ')' WHEN data_type = 'char' THEN 'char(' + CAST(character_maximum_length AS VARCHAR) + ')' WHEN data_type = 'numeric' THEN 'numeric(' + CAST(numeric_precision AS VARCHAR) + ',' + CAST(numeric_scale AS VARCHAR) + ')' ELSE data_type END AS data_type FROM information_schema.columns JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND tables.table_type = 'BASE TABLE' ORDER BY data_type, table_name;	Profile Anomaly
1120	1006	No_Values	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1121	1007	Column_Pattern_Mismatch	mssql	\N	WITH cte AS ( SELECT TRIM(value) AS top_pattern, ROW_NUMBER() OVER (ORDER BY  CHARINDEX('| '+  TRIM(value) + ' |',  '| ' + '{DETAIL_EXPRESSION}' + ' |' ) ASC) as row_num FROM STRING_SPLIT('{DETAIL_EXPRESSION}', '|') ) SELECT DISTINCT TOP 5 c.top_pattern, a."{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte c WHERE c.row_num = 4 AND TRANSLATE(a."{COLUMN_NAME}" COLLATE Latin1_General_BIN,   'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',   'aaaaaaaaaaaaaaaaaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAAANNNNNNNNNN') = c.top_pattern GROUP BY  c.top_pattern, a."{COLUMN_NAME}" UNION ALL SELECT DISTINCT TOP 5 c.top_pattern, a."{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte c WHERE c.row_num = 6 AND TRANSLATE(a."{COLUMN_NAME}" COLLATE Latin1_General_BIN,   'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',   'aaaaaaaaaaaaaaaaaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAAANNNNNNNNNN') = c.top_pattern GROUP BY  c.top_pattern, a."{COLUMN_NAME}" UNION ALL SELECT DISTINCT TOP 5 c.top_pattern, a."{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte c WHERE c.row_num = 8 AND TRANSLATE(a."{COLUMN_NAME}" COLLATE Latin1_General_BIN,   'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',   'aaaaaaaaaaaaaaaaaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAAANNNNNNNNNN') = c.top_pattern GROUP BY  c.top_pattern, a."{COLUMN_NAME}" UNION ALL SELECT DISTINCT TOP 5 c.top_pattern, a."{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte c WHERE c.row_num = 10 AND TRANSLATE(a."{COLUMN_NAME}" COLLATE Latin1_General_BIN,   'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',   'aaaaaaaaaaaaaaaaaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAAANNNNNNNNNN') = c.top_pattern GROUP BY  c.top_pattern, a."{COLUMN_NAME}" ORDER BY top_pattern DESC, count DESC;	Profile Anomaly
1122	1008	Table_Pattern_Mismatch	mssql	\N	SELECT TOP 500 column_name, columns.table_name FROM information_schema.columns JOIN information_schema.tables  ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND UPPER(tables.table_type) = 'BASE TABLE' ORDER BY table_name;	Profile Anomaly
1123	1009	Leading_Spaces	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" BETWEEN ' !' AND '!' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1124	1010	Quoted_Values	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" LIKE '"%"' OR "{COLUMN_NAME}" LIKE '''%''' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1125	1011	Char_Column_Number_Values	mssql	\N	SELECT A.* FROM (  SELECT DISTINCT TOP 10 'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC ) AS A UNION ALL SELECT B.* FROM  ( SELECT DISTINCT TOP 10 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1126	1012	Char_Column_Date_Values	mssql	\N	SELECT A.* FROM (  SELECT  DISTINCT TOP 10 'Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS A UNION ALL SELECT B.* FROM  ( SELECT DISTINCT TOP 10  'Non-Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1128	1014	Small Divergent Value Ct	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1129	1015	Boolean_Value_Mismatch	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1130	1016	Potential_Duplicates	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*)> 1 ORDER BY COUNT(*) DESC;	Profile Anomaly
1131	1017	Standardized_Value_Matches	mssql	\N	WITH CTE AS ( SELECT DISTINCT TOP 500 UPPER(REPLACE(TRANSLATE("{COLUMN_NAME}",' '''',.-',REPLICATE(' ', LEN(' '''',.-'))),' ','')) as possible_standard_value, COUNT(DISTINCT "{COLUMN_NAME}") as distinct_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY UPPER(REPLACE(TRANSLATE("{COLUMN_NAME}",' '''',.-',REPLICATE(' ', LEN(' '''',.-'))),' ','')) HAVING COUNT(DISTINCT "{COLUMN_NAME}") > 1 ) SELECT DISTINCT a."{COLUMN_NAME}", possible_standard_value, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte b WHERE UPPER(REPLACE(TRANSLATE("{COLUMN_NAME}",' '''',.-',REPLICATE(' ', LEN(' '''',.-'))),' ','')) = b.possible_standard_value GROUP BY a."{COLUMN_NAME}", possible_standard_value ORDER BY possible_standard_value ASC, count DESC;	Profile Anomaly
1132	1018	Unlikely_Date_Values	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", CAST( '{PROFILE_RUN_DATE}' AS DATE) AS profile_run_date, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a WHERE ("{COLUMN_NAME}" < CAST('1900-01-01' AS DATE) )    OR ("{COLUMN_NAME}" > DATEADD(YEAR, 30, CAST('{PROFILE_RUN_DATE}' AS DATE ))) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Profile Anomaly
1133	1019	Recency_One_Year	mssql	\N	created_in_ui	Profile Anomaly
1134	1020	Recency_Six_Months	mssql	\N	created_in_ui	Profile Anomaly
1135	1021	Unexpected US States	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Profile Anomaly
1136	1022	Unexpected Emails	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Profile Anomaly
1137	1023	Small_Numeric_Value_Ct	mssql	\N	SELECT A.* FROM (  SELECT DISTINCT TOP 10 'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC  ) AS A UNION ALL SELECT B.* FROM  ( SELECT DISTINCT TOP 10 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC )  AS B ORDER BY data_type, count DESC;	Profile Anomaly
1138	1024	Invalid_Zip3_USA	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') <> '999' GROUP BY "{COLUMN_NAME}" ORDER BY count DESC, "{COLUMN_NAME}";	Profile Anomaly
1139	1025	Delimited_Data_Embedded	mssql	\N	SELECT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE ( "{COLUMN_NAME}" LIKE '%,%,%,%' OR "{COLUMN_NAME}" LIKE '%|%|%|%' OR "{COLUMN_NAME}" LIKE '%^%^%^%'  OR "{COLUMN_NAME}" LIKE '%' + CHAR(9) + '%' + CHAR(9) + '%' + CHAR(9) + '%' ) AND NOT ( "{COLUMN_NAME}" LIKE '% and %' OR "{COLUMN_NAME}" LIKE '% but %' OR "{COLUMN_NAME}" LIKE '% or %'  OR "{COLUMN_NAME}" LIKE '% yet %' ) AND ISNULL(CAST(LEN("{COLUMN_NAME}") - LEN(REPLACE("{COLUMN_NAME}", ',', '')) as FLOAT)   / CAST(NULLIF(LEN("{COLUMN_NAME}") - LEN(REPLACE("{COLUMN_NAME}", ' ', '')), 0) as FLOAT), 1) > 0.6 GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1140	1004	Alpha_Trunc	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", LEN("{COLUMN_NAME}") as current_max_length,  {THRESHOLD_VALUE} as previous_max_length FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT MAX(LEN("{COLUMN_NAME}")) as max_length FROM {TARGET_SCHEMA}.{TABLE_NAME}) a WHERE LEN("{COLUMN_NAME}") = a.max_length AND a.max_length < {THRESHOLD_VALUE} ;	Test Results
1141	1005	Avg_Shift	mssql	\N	SELECT AVG(CAST("{COLUMN_NAME}" AS FLOAT)) AS current_average FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1142	1006	Condition_Flag	mssql	\N	SELECT TOP 500 * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {CUSTOM_QUERY};	Test Results
1143	1007	Constant	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" <> {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}";	Test Results
1144	1009	Daily_Record_Ct	mssql	\N	WITH\n  Pass0 as (select 1 as C union all select 1), --2 rows\n  Pass1 as (select 1 as C from Pass0 as A, Pass0 as B),--4 rows\n  Pass2 as (select 1 as C from Pass1 as A, Pass1 as B),--16 rows\n  Pass3 as (select 1 as C from Pass2 as A, Pass2 as B),--256 rows\n  Pass4 as (select 1 as C from Pass3 as A, Pass3 as B),--65536 rows\n  All_Nums as (select row_number() over(order by C) as Number from Pass4),\n  tally as (SELECT Number FROM All_Nums WHERE Number <= 45000),\n\n  date_range as (SELECT CAST(DATEADD(DAY, DATEDIFF(DAY, 0, MIN("{COLUMN_NAME}")), 0) AS DATE) AS min_period,\n                        CAST(DATEADD(DAY, DATEDIFF(DAY, 0, MAX("{COLUMN_NAME}")), 0) AS DATE) AS max_period,\n                        DATEDIFF(DAY,\n                                 CAST(DATEADD(DAY, DATEDIFF(DAY, 0, MIN("{COLUMN_NAME}")), 0) AS DATE),\n                                 CAST(DATEADD(DAY, DATEDIFF(DAY, 0, MAX("{COLUMN_NAME}")), 0) AS DATE) ) + 1 as period_ct\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME} ),\n  check_periods as ( SELECT d.min_period, d.max_period, t.number,\n                            DATEADD(DAY, -(t.number - 1), d.max_period) AS check_period\n                       FROM date_range d\n                     INNER JOIN tally t\n                        ON (d.period_ct >= t.number) ),\n  data_by_period as (SELECT CAST(DATEADD(DAY, DATEDIFF(DAY, 0, "{COLUMN_NAME}"), 0) AS DATE) as data_period, COUNT(*) as record_ct\n                       FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                     GROUP BY CAST(DATEADD(DAY, DATEDIFF(DAY, 0, "{COLUMN_NAME}"), 0) AS DATE) ),\n  data_by_prd_with_prior_next as (SELECT check_period,\n                                         RANK() OVER (ORDER BY check_period DESC) as ranked,\n                                         ISNULL(d.record_ct, 0) as record_ct,\n                                         ISNULL(LAG(d.record_ct) OVER (ORDER BY check_period), 0) as last_record_ct,\n                                         ISNULL(LEAD(d.record_ct) OVER (ORDER BY check_period), 0) as next_record_ct\n                                    FROM check_periods c\n                                  LEFT JOIN data_by_period d\n                                    ON (c.check_period = d.data_period) )\nSELECT check_period, record_ct,\n       CASE\n         WHEN record_ct = 0 THEN 'MISSING'\n         ELSE 'Present'\n       END as status\n  FROM data_by_prd_with_prior_next\n WHERE record_ct = 0\n    OR last_record_ct = 0\n    OR next_record_ct = 0\nORDER BY check_period DESC;	Test Results
1145	1011	Dec_Trunc	mssql	\N	WITH CTE AS ( SELECT LEN(SUBSTRING(CAST(ABS("{COLUMN_NAME}") % 1 AS VARCHAR) , 3, LEN("{COLUMN_NAME}"))) AS decimal_scale FROM {TARGET_SCHEMA}.{TABLE_NAME} ) SELECT DISTINCT TOP 500 decimal_scale,COUNT(*) AS count FROM cte GROUP BY decimal_scale ORDER BY COUNT(*) DESC; 	Test Results
1146	1012	Distinct_Date_Ct	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1147	1013	Distinct_Value_Ct	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1148	1014	Email_Format	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" NOT LIKE '%[_a-zA-Z0-9.-]%@%[a-zA-Z0-9.-]%.[a-zA-Z][a-zA-Z]%' GROUP BY "{COLUMN_NAME}";	Test Results
1149	1015	Future_Date	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CAST("{COLUMN_NAME}" AS DATE) >= CONVERT(DATE, '{TEST_DATE}') GROUP BY "{COLUMN_NAME}";	Test Results
1150	1016	Future_Date_1Y	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CAST("{COLUMN_NAME}" AS DATE) >= DATEADD(DAY, 365, CONVERT(DATE, '{TEST_DATE}')) GROUP BY "{COLUMN_NAME}";	Test Results
1151	1017	Incr_Avg_Shift	mssql	\N	SELECT AVG(CAST("{COLUMN_NAME}" AS FLOAT)) AS current_average, SUM(CAST("{COLUMN_NAME}" AS FLOAT)) AS current_sum, NULLIF(CAST(COUNT("{COLUMN_NAME}") AS FLOAT), 0) as current_value_count FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1152	1018	LOV_All	mssql	\N	WITH CTE AS  (SELECT DISTINCT "{COLUMN_NAME}" FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT STRING_AGG( "{COLUMN_NAME}", '|' ) WITHIN GROUP (ORDER BY "{COLUMN_NAME}" ASC) FROM CTE HAVING STRING_AGG("{COLUMN_NAME}", '|') WITHIN GROUP (ORDER BY "{COLUMN_NAME}" ASC) <> '{THRESHOLD_VALUE}';	Test Results
1153	1019	LOV_Match	mssql	\N	SELECT DISTINCT TOP 500 NULLIF("{COLUMN_NAME}", '') AS "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT IN {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" ;	Test Results
1154	1020	Min_Date	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CAST("{COLUMN_NAME}" AS DATE) < CAST('{BASELINE_VALUE}' AS DATE) GROUP BY "{COLUMN_NAME}";	Test Results
1155	1021	Min_Val	mssql	\N	SELECT DISTINCT TOP 500  "{COLUMN_NAME}", (ABS("{COLUMN_NAME}") - ABS({BASELINE_VALUE})) AS difference_from_baseline FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" < {BASELINE_VALUE};	Test Results
1156	1022	Missing_Pct	mssql	\N	SELECT TOP 10 * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL OR CAST("{COLUMN_NAME}" AS VARCHAR(255)) = '';	Test Results
1157	1023	Monthly_Rec_Ct	mssql	\N	WITH\n  Pass0 as (select 1 as C union all select 1), --2 rows\n  Pass1 as (select 1 as C from Pass0 as A, Pass0 as B),--4 rows\n  Pass2 as (select 1 as C from Pass1 as A, Pass1 as B),--16 rows\n  Pass3 as (select 1 as C from Pass2 as A, Pass2 as B),--256 rows\n  Pass4 as (select 1 as C from Pass3 as A, Pass3 as B),--65536 rows\n  All_Nums as (select row_number() over(order by C) as Number from Pass4),\n  tally as (SELECT Number FROM All_Nums WHERE Number <= 45000),\n\n  date_range as (SELECT CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, MIN("{COLUMN_NAME}")), 0) AS DATE) AS min_period,\n                        CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, MAX("{COLUMN_NAME}")), 0) AS DATE) AS max_period,\n                        DATEDIFF(MONTH,\n                                 CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, MIN("{COLUMN_NAME}")), 0) AS DATE),\n                                 CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, MAX("{COLUMN_NAME}")), 0) AS DATE) ) + 1 as period_ct\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME} ),\n  check_periods as ( SELECT d.min_period, d.max_period, t.number,\n                            DATEADD(MONTH, -(t.number - 1), d.max_period) AS check_period\n                       FROM date_range d\n                     INNER JOIN tally t\n                        ON (d.period_ct >= t.number) ),\n  data_by_period as (SELECT CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, "{COLUMN_NAME}"), 0) AS DATE) as data_period, COUNT(*) as record_ct\n                       FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                     GROUP BY CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, "{COLUMN_NAME}"), 0) AS DATE) ),\n  data_by_prd_with_prior_next as (SELECT check_period,\n                                         RANK() OVER (ORDER BY check_period DESC) as ranked,\n                                         ISNULL(d.record_ct, 0) as record_ct,\n                                         ISNULL(LAG(d.record_ct) OVER (ORDER BY check_period), 0) as last_record_ct,\n                                         ISNULL(LEAD(d.record_ct) OVER (ORDER BY check_period), 0) as next_record_ct\n                                    FROM check_periods c\n                                  LEFT JOIN data_by_period d\n                                    ON (c.check_period = d.data_period) )\nSELECT check_period, record_ct,\n       CASE\n         WHEN record_ct = 0 THEN 'MISSING'\n         ELSE 'Present'\n       END as status\n  FROM data_by_prd_with_prior_next\n WHERE record_ct = 0\n    OR last_record_ct = 0\n    OR next_record_ct = 0\nORDER BY check_period DESC;	Test Results
1158	1024	Outlier_Pct_Above	mssql	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CAST("{COLUMN_NAME}" AS FLOAT) > ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1159	1025	Outlier_Pct_Below	mssql	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CAST("{COLUMN_NAME}" AS FLOAT)  < ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1160	1026	Pattern_Match	mssql	\N	SELECT DISTINCT  "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT LIKE '{BASELINE_VALUE}' GROUP BY "{COLUMN_NAME}";	Test Results
1161	1028	Recency	mssql	\N	SELECT DISTINCT col AS latest_date_available, CAST('{TEST_DATE}' AS DATE) AS test_run_date FROM (SELECT MAX("{COLUMN_NAME}") AS col FROM {TARGET_SCHEMA}.{TABLE_NAME}) a WHERE DATEDIFF(day, col, CAST('{TEST_DATE}' AS DATE)) > {THRESHOLD_VALUE};	Test Results
1162	1030	Required	mssql	\N	SELECT TOP 500 * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL;	Test Results
1163	1031	Row_Ct	mssql	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, ABS(ROUND(CAST(100 * (current_count - {THRESHOLD_VALUE}) AS NUMERIC) / CAST({THRESHOLD_VALUE} AS NUMERIC) ,2)) AS row_count_pct_decrease FROM cte WHERE current_count < {THRESHOLD_VALUE};	Test Results
1164	1032	Row_Ct_Pct	mssql	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, {BASELINE_CT} AS baseline_count, ABS(ROUND(CAST(100 * (current_count - {BASELINE_CT}) AS NUMERIC) / CAST({BASELINE_CT} AS NUMERIC) ,2)) AS row_count_pct_difference FROM cte;	Test Results
1165	1033	Street_Addr_Pattern	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE UPPER("{COLUMN_NAME}") NOT LIKE '[1-9]% [A-Z]% %' AND CHARINDEX(' ', "{COLUMN_NAME}") NOT BETWEEN 2 AND 6 GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Test Results
1166	1036	US_State	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') GROUP BY "{COLUMN_NAME}";	Test Results
1167	1034	Unique	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*) > 1 ORDER BY COUNT(*) DESC;	Test Results
1168	1035	Unique_Pct	mssql	\N	SELECT DISTINCT TOP 500 "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Test Results
1169	1037	Weekly_Rec_Ct	mssql	\N	WITH\n  Pass0 as (select 1 as C union all select 1), --2 rows\n  Pass1 as (select 1 as C from Pass0 as A, Pass0 as B),--4 rows\n  Pass2 as (select 1 as C from Pass1 as A, Pass1 as B),--16 rows\n  Pass3 as (select 1 as C from Pass2 as A, Pass2 as B),--256 rows\n  Pass4 as (select 1 as C from Pass3 as A, Pass3 as B),--65536 rows\n  All_Nums as (select row_number() over(order by C) as Number from Pass4),\n  tally as (SELECT Number FROM All_Nums WHERE Number <= 45000),\n\n  date_range as (SELECT CAST(DATEADD(WEEK, DATEDIFF(WEEK, 0, MIN("{COLUMN_NAME}")), 0) AS DATE) AS min_period,\n                        CAST(DATEADD(WEEK, DATEDIFF(WEEK, 0, MAX("{COLUMN_NAME}")), 0) AS DATE) AS max_period,\n                        DATEDIFF(WEEK,\n                                 CAST(DATEADD(WEEK, DATEDIFF(WEEK, 0, MIN("{COLUMN_NAME}")), 0) AS DATE),\n                                 CAST(DATEADD(WEEK, DATEDIFF(WEEK, 0, MAX("{COLUMN_NAME}")), 0) AS DATE) ) + 1 as period_ct\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME} ),\n  check_periods as ( SELECT d.min_period, d.max_period, t.number,\n                            DATEADD(WEEK, -(t.number - 1), d.max_period) AS check_period\n                       FROM date_range d\n                     INNER JOIN tally t\n                        ON (d.period_ct >= t.number) ),\n  data_by_period as (SELECT CAST(DATEADD(WEEK, DATEDIFF(WEEK, 0, "{COLUMN_NAME}"), 0) AS DATE) as data_period, COUNT(*) as record_ct\n                       FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                     GROUP BY CAST(DATEADD(WEEK, DATEDIFF(WEEK, 0, "{COLUMN_NAME}"), 0) AS DATE) ),\n  data_by_prd_with_prior_next as (SELECT check_period,\n                                         RANK() OVER (ORDER BY check_period DESC) as ranked,\n                                         ISNULL(d.record_ct, 0) as record_ct,\n                                         ISNULL(LAG(d.record_ct) OVER (ORDER BY check_period), 0) as last_record_ct,\n                                         ISNULL(LEAD(d.record_ct) OVER (ORDER BY check_period), 0) as next_record_ct\n                                    FROM check_periods c\n                                  LEFT JOIN data_by_period d\n                                    ON (c.check_period = d.data_period) )\nSELECT check_period, record_ct,\n       CASE\n         WHEN record_ct = 0 THEN 'MISSING'\n         ELSE 'Present'\n       END as status\n  FROM data_by_prd_with_prior_next\n WHERE record_ct = 0\n    OR last_record_ct = 0\n    OR next_record_ct = 0\nORDER BY check_period DESC;	Test Results
1170	1040	Variability_Increase	mssql	\N	SELECT STDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1171	1041	Variability_Decrease	mssql	\N	SELECT STDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1172	1001	Suggested_Type	snowflake	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Profile Anomaly
1173	1002	Non_Standard_Blanks	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1 WHEN LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP '-{2,}' OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP '0{2,}' OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP '9{2,}'         OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP 'x{2,}' OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP 'z{2,}' THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown')           THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1174	1003	Invalid_Zip_USA	snowflake	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" LIMIT 500;	Profile Anomaly
1175	1004	Multiple_Types_Minor	snowflake	\N	SELECT DISTINCT column_name, columns.table_name, CASE WHEN data_type ILIKE 'timestamp%' THEN lower(data_type) WHEN data_type ILIKE 'date' THEN lower(data_type) WHEN data_type ILIKE 'boolean' THEN 'boolean' WHEN data_type = 'TEXT' THEN 'varchar(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type ILIKE 'char%' THEN 'char(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'NUMBER' AND numeric_precision = 38 AND numeric_scale = 0 THEN 'bigint' WHEN data_type ILIKE 'num%' THEN 'numeric(' || CAST(numeric_precision AS VARCHAR) || ',' || CAST(numeric_scale AS VARCHAR) || ')' ELSE data_type END AS data_type FROM information_schema.columns JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND tables.table_type = 'BASE TABLE' ORDER BY data_type, table_name;	Profile Anomaly
1176	1005	Multiple_Types_Major	snowflake	\N	SELECT DISTINCT column_name, columns.table_name, CASE WHEN data_type ILIKE 'timestamp%' THEN lower(data_type) WHEN data_type ILIKE 'date' THEN lower(data_type) WHEN data_type ILIKE 'boolean' THEN 'boolean' WHEN data_type = 'TEXT' THEN 'varchar(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type ILIKE 'char%' THEN 'char(' || CAST(character_maximum_length AS VARCHAR) || ')' WHEN data_type = 'NUMBER' AND numeric_precision = 38 AND numeric_scale = 0 THEN 'bigint' WHEN data_type ILIKE 'num%' THEN 'numeric(' || CAST(numeric_precision AS VARCHAR) || ',' || CAST(numeric_scale AS VARCHAR) || ')' ELSE data_type END AS data_type FROM information_schema.columns JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND tables.table_type = 'BASE TABLE' ORDER BY data_type, table_name;	Profile Anomaly
1177	1006	No_Values	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1178	1007	Column_Pattern_Mismatch	snowflake	\N	SELECT A.* FROM (SELECT DISTINCT TOP 5 b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 4)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}"::VARCHAR, '[a-z]', 'a'), '[A-Z]', 'A'), '[0-9]', 'N') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC) A UNION ALL SELECT B.* FROM (SELECT DISTINCT TOP 5 b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 6)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}"::VARCHAR, '[a-z]', 'a'), '[A-Z]', 'A'), '[0-9]', 'N') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC) B UNION ALL SELECT C.* FROM (SELECT DISTINCT TOP 5 b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 8)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}"::VARCHAR, '[a-z]', 'a'), '[A-Z]', 'A'), '[0-9]', 'N') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC) C UNION ALL SELECT D.* FROM (SELECT DISTINCT TOP 5 b.top_pattern, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT trim(split_part('{DETAIL_EXPRESSION}', '|', 10)) AS top_pattern) b WHERE REGEXP_REPLACE(REGEXP_REPLACE( REGEXP_REPLACE( "{COLUMN_NAME}"::VARCHAR, '[a-z]', 'a'), '[A-Z]', 'A'), '[0-9]', 'N') = b.top_pattern GROUP BY b.top_pattern, "{COLUMN_NAME}" ORDER BY count DESC) D ORDER BY top_pattern DESC, count DESC;	Profile Anomaly
1179	1008	Table_Pattern_Mismatch	snowflake	\N	SELECT DISTINCT column_name, columns.table_name FROM information_schema.columns JOIN information_schema.tables ON columns.table_name = tables.table_name AND columns.table_schema = tables.table_schema WHERE columns.table_schema = '{TARGET_SCHEMA}' AND columns.column_name = '{COLUMN_NAME}' AND UPPER(tables.table_type) = 'BASE TABLE' ORDER BY table_name; 	Profile Anomaly
1180	1009	Leading_Spaces	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" BETWEEN ' !' AND '!' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1181	1010	Quoted_Values	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" ILIKE '"%"' OR "{COLUMN_NAME}" ILIKE '''%''' THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1182	1011	Char_Column_Number_Values	snowflake	\N	SELECT A.* FROM (SELECT DISTINCT TOP 10  'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS A UNION ALL SELECT B.* FROM (SELECT DISTINCT TOP 10 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS B ORDER BY data_type, count DESC;	Profile Anomaly
1183	1012	Char_Column_Date_Values	snowflake	\N	SELECT A.* FROM (SELECT DISTINCT TOP 10 'Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS A UNION ALL SELECT B.* FROM (SELECT DISTINCT TOP 10 'Non-Date' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_DATE;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS B ORDER BY data_type, count DESC;	Profile Anomaly
1184	1013	Small Missing Value Ct	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE (CASE WHEN "{COLUMN_NAME}" IN ('.', '?', ' ') THEN 1 WHEN LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP '-{2,}' OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP '0{2,}' OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP '9{2,}'     OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP 'x{2,}' OR LOWER("{COLUMN_NAME}"::VARCHAR) REGEXP 'z{2,}' THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('blank','error','missing','tbd', 'n/a','#na','none','null','unknown')           THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('(blank)','(error)','(missing)','(tbd)', '(n/a)','(#na)','(none)','(null)','(unknown)') THEN 1 WHEN LOWER("{COLUMN_NAME}") IN ('[blank]','[error]','[missing]','[tbd]', '[n/a]','[#na]','[none]','[null]','[unknown]') THEN 1 WHEN "{COLUMN_NAME}" = '' THEN 1 WHEN "{COLUMN_NAME}" IS NULL THEN 1 ELSE 0 END) = 1 GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1185	1014	Small Divergent Value Ct	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1186	1015	Boolean_Value_Mismatch	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC;	Profile Anomaly
1187	1016	Potential_Duplicates	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*)> 1 ORDER BY COUNT(*) DESC LIMIT 500;	Profile Anomaly
1188	1017	Standardized_Value_Matches	snowflake	\N	WITH CTE AS ( SELECT DISTINCT UPPER(TRANSLATE("{COLUMN_NAME}", ' '',.-', '')) as possible_standard_value, COUNT(DISTINCT "{COLUMN_NAME}") FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY UPPER(TRANSLATE("{COLUMN_NAME}", ' '',.-', '')) HAVING COUNT(DISTINCT "{COLUMN_NAME}") > 1 ) SELECT DISTINCT a."{COLUMN_NAME}", possible_standard_value, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} a, cte b WHERE UPPER(TRANSLATE(a."{COLUMN_NAME}", ' '',.-', '')) = b.possible_standard_value GROUP BY a."{COLUMN_NAME}", possible_standard_value ORDER BY possible_standard_value ASC, count DESC LIMIT 500;	Profile Anomaly
1189	1018	Unlikely_Date_Values	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", '{PROFILE_RUN_DATE}' :: DATE AS profile_run_date, COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} a WHERE ("{COLUMN_NAME}" < '1900-01-01'::DATE) OR ("{COLUMN_NAME}" > '{PROFILE_RUN_DATE}' :: DATE + INTERVAL '30 year' ) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1190	1019	Recency_One_Year	snowflake	\N	created_in_ui	Profile Anomaly
1191	1020	Recency_Six_Months	snowflake	\N	created_in_ui	Profile Anomaly
1192	1021	Unexpected US States	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1193	1022	Unexpected Emails	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1194	1023	Small_Numeric_Value_Ct	snowflake	\N	SELECT A.* FROM (SELECT DISTINCT TOP 10  'Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} = 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS A UNION ALL SELECT B.* FROM (SELECT DISTINCT TOP 10 'Non-Numeric' as data_type, "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {{DKFN_IS_NUM;;"{COLUMN_NAME}"}} != 1 GROUP BY "{COLUMN_NAME}" ORDER BY count DESC) AS B ORDER BY data_type, count DESC;	Profile Anomaly
1195	1024	Invalid_Zip3_USA	snowflake	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') <> '999' GROUP BY "{COLUMN_NAME}" ORDER BY count DESC, "{COLUMN_NAME}" LIMIT 500;	Profile Anomaly
1196	1025	Delimited_Data_Embedded	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE REGEXP_LIKE("{COLUMN_NAME}"::VARCHAR, '^([^,|\\t]{1,20}[,|\\t]){2,}[^,|\\t]{0,20}([,|\\t]{0,1}[^,|\\t]{0,20})*$') AND NOT REGEXP_LIKE("{COLUMN_NAME}"::VARCHAR, '.*\\\\s(and|but|or|yet)\\\\s.*') GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Profile Anomaly
1197	1004	Alpha_Trunc	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}" , LEN("{COLUMN_NAME}") as current_max_length, {THRESHOLD_VALUE} as previous_max_length FROM {TARGET_SCHEMA}.{TABLE_NAME}, (SELECT MAX(LEN("{COLUMN_NAME}")) as max_length FROM {TARGET_SCHEMA}.{TABLE_NAME}) a WHERE LEN("{COLUMN_NAME}") = a.max_length AND a.max_length < {THRESHOLD_VALUE} LIMIT 500;	Test Results
1198	1005	Avg_Shift	snowflake	\N	SELECT AVG("{COLUMN_NAME}" :: FLOAT) AS current_average FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1199	1006	Condition_Flag	snowflake	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE {CUSTOM_QUERY} LIMIT 500;	Test Results
1200	1007	Constant	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" <> {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1201	1009	Daily_Record_Ct	snowflake	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT MIN("{COLUMN_NAME}") :: DATE AS all_dates  FROM {TARGET_SCHEMA}.{TABLE_NAME}  UNION ALL  SELECT DATEADD(DAY, 1, d.all_dates) :: DATE AS all_dates  FROM daterange d  WHERE d.all_dates < (SELECT MAX("{COLUMN_NAME}") :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS ( SELECT DISTINCT "{COLUMN_NAME}" :: DATE AS period, COUNT(1) AS period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" :: DATE ) SELECT p.missing_period, p.prior_available_date, e.period_count as prior_available_date_count, p.next_available_date, f.period_count as next_available_date_count FROM (SELECT d.all_dates AS missing_period, MAX(b.period) AS prior_available_date, MIN(c.period) AS next_available_date FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL  AND d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates) p LEFT JOIN existing_periods e ON (p.prior_available_date = e.period) LEFT JOIN existing_periods f ON (p.next_available_date = f.period) ORDER BY p.missing_period LIMIT 500;	Test Results
1202	1011	Dec_Trunc	snowflake	\N	SELECT DISTINCT LENGTH(SPLIT_PART("{COLUMN_NAME}" :: TEXT, '.', 2)) AS decimal_scale, COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY decimal_scale LIMIT 500;	Test Results
1203	1012	Distinct_Date_Ct	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Test Results
1204	1013	Distinct_Value_Ct	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NOT NULL GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Test Results
1205	1014	Email_Format	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE REGEXP_LIKE("{COLUMN_NAME}"::VARCHAR, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Za-z]{2,}$') != 1 GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1206	1015	Future_Date	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE GREATEST(0, SIGN("{COLUMN_NAME}"::DATE - '{TEST_DATE}'::DATE)) > {THRESHOLD_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1207	1016	Future_Date_1Y	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE GREATEST(0, SIGN("{COLUMN_NAME}"::DATE - ('{TEST_DATE}'::DATE + 365))) > {THRESHOLD_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1208	1017	Incr_Avg_Shift	snowflake	\N	SELECT AVG("{COLUMN_NAME}" :: FLOAT) AS current_average, SUM("{COLUMN_NAME}" ::FLOAT) AS current_sum, NULLIF(COUNT("{COLUMN_NAME}" )::FLOAT, 0) as current_value_count FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1209	1018	LOV_All	snowflake	\N	SELECT LISTAGG(DISTINCT "{COLUMN_NAME}", '|') WITHIN GROUP (ORDER BY "{COLUMN_NAME}") FROM {TARGET_SCHEMA}.{TABLE_NAME} HAVING LISTAGG(DISTINCT "{COLUMN_NAME}", '|') WITHIN GROUP (ORDER BY "{COLUMN_NAME}") <> '{THRESHOLD_VALUE}' LIMIT 500;	Test Results
1210	1019	LOV_Match	snowflake	\N	SELECT DISTINCT NULLIF("{COLUMN_NAME}", '') AS "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE NULLIF("{COLUMN_NAME}", '') NOT IN {BASELINE_VALUE} GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1211	1020	Min_Date	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}",  COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: DATE < '{BASELINE_VALUE}' :: DATE GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1212	1021	Min_Val	snowflake	\N	SELECT DISTINCT  "{COLUMN_NAME}", (ABS("{COLUMN_NAME}") - ABS({BASELINE_VALUE})) AS difference_from_baseline FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" < {BASELINE_VALUE} LIMIT 500;	Test Results
1213	1022	Missing_Pct	snowflake	\N	SELECT TOP 10 * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL OR "{COLUMN_NAME}" :: VARCHAR(255) = '' ;	Test Results
1214	1023	Monthly_Rec_Ct	snowflake	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT DATE_TRUNC('month', MIN("{COLUMN_NAME}")) :: DATE AS all_dates  FROM {TARGET_SCHEMA}.{TABLE_NAME}  UNION ALL  SELECT DATEADD(MONTH, 1, d.all_dates) :: DATE AS all_dates  FROM daterange d  WHERE d.all_dates < (SELECT DATE_TRUNC('month', MAX("{COLUMN_NAME}")) :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS (SELECT DISTINCT DATE_TRUNC('month',"{COLUMN_NAME}") :: DATE AS period, COUNT(1) AS period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DATE_TRUNC('month',"{COLUMN_NAME}") :: DATE ) SELECT p.missing_period, p.prior_available_month, e.period_count as prior_available_month_count, p.next_available_month, f.period_count as next_available_month_count FROM (SELECT d.all_dates as missing_period, MAX(b.period) AS prior_available_month, MIN(c.period) AS next_available_month FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND  d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates) p LEFT JOIN existing_periods e ON (p.prior_available_month = e.period) LEFT JOIN existing_periods f ON (p.next_available_month = f.period) ORDER BY p.missing_period;	Test Results
1215	1024	Outlier_Pct_Above	snowflake	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: FLOAT > ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1216	1025	Outlier_Pct_Below	snowflake	\N	SELECT ({BASELINE_AVG} + (2*{BASELINE_SD})) AS outlier_threshold, "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" :: FLOAT < ({BASELINE_AVG} + (2*{BASELINE_SD})) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC;	Test Results
1217	1026	Pattern_Match	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE REGEXP_LIKE(NULLIF("{COLUMN_NAME}"::VARCHAR, ''),'{BASELINE_VALUE}') != 1 GROUP BY "{COLUMN_NAME}";	Test Results
1218	1028	Recency	snowflake	\N	SELECT DISTINCT col AS latest_date_available, '{TEST_DATE}' :: DATE as test_run_date FROM (SELECT MAX("{COLUMN_NAME}") AS col FROM {TARGET_SCHEMA}.{TABLE_NAME}) WHERE DATEDIFF('D', col, '{TEST_DATE}'::DATE) > {THRESHOLD_VALUE};	Test Results
1219	1030	Required	snowflake	\N	SELECT * FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" IS NULL LIMIT 500;	Test Results
1220	1031	Row_Ct	snowflake	\N	WITH CTE AS (SELECT COUNT(*) AS current_count  FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, ABS(ROUND(100 *(current_count - {THRESHOLD_VALUE}) :: FLOAT / {THRESHOLD_VALUE} :: FLOAT,2))  AS row_count_pct_decrease FROM cte WHERE current_count < {THRESHOLD_VALUE};	Test Results
1221	1032	Row_Ct_Pct	snowflake	\N	WITH CTE AS (SELECT COUNT(*) AS current_count FROM {TARGET_SCHEMA}.{TABLE_NAME}) SELECT current_count, {BASELINE_CT} AS baseline_count, ABS(ROUND(100 * (current_count - {BASELINE_CT}) :: FLOAT / {BASELINE_CT} :: FLOAT,2)) AS row_count_pct_difference FROM cte;	Test Results
1222	1033	Street_Addr_Pattern	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE REGEXP_LIKE("{COLUMN_NAME}"::VARCHAR, '^[0-9]{1,5}[a-zA-Z]?\\\\s\\\\w{1,5}\\\\.?\\\\s?\\\\w*\\\\s?\\\\w*\\\\s[a-zA-Z]{1,6}\\\\.?\\\\s?[0-9]{0,5}[A-Z]{0,1}$') != 1 GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1223	1036	US_State	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE  NULLIF("{COLUMN_NAME}", '') NOT IN ('AL','AK','AS','AZ','AR','CA','CO','CT','DE','DC','FM','FL','GA','GU','HI','ID','IL','IN','IA','KS','KY','LA','ME','MH','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','MP','OH','OK','OR','PW','PA','PR','RI','SC','SD','TN','TX','UT','VT','VI','VA','WA','WV','WI','WY','AE','AP','AA') GROUP BY "{COLUMN_NAME}" LIMIT 500;	Test Results
1224	1034	Unique	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" HAVING COUNT(*) > 1 ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1225	1035	Unique_Pct	snowflake	\N	SELECT DISTINCT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY COUNT(*) DESC LIMIT 500;	Test Results
1226	1037	Weekly_Rec_Ct	snowflake	\N	WITH RECURSIVE daterange(all_dates) AS (SELECT DATE_TRUNC('week',MIN("{COLUMN_NAME}")) :: DATE AS all_dates  FROM {TARGET_SCHEMA}.{TABLE_NAME}  UNION ALL  SELECT (d.all_dates + INTERVAL '1 week' ) :: DATE AS all_dates  FROM daterange d  WHERE d.all_dates < (SELECT DATE_TRUNC('week', MAX("{COLUMN_NAME}")) :: DATE FROM {TARGET_SCHEMA}.{TABLE_NAME}) ), existing_periods AS ( SELECT DISTINCT DATE_TRUNC('week',"{COLUMN_NAME}") :: DATE AS period, COUNT(1) as period_count FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY DATE_TRUNC('week',"{COLUMN_NAME}") :: DATE ) SELECT p.missing_period, p.prior_available_week, e.period_count as prior_available_week_count, p.next_available_week, f.period_count as next_available_week_count FROM( SELECT d.all_dates as missing_period, MAX(b.period) AS prior_available_week, MIN(c.period) AS next_available_week FROM daterange d LEFT JOIN existing_periods a ON d.all_dates = a.period LEFT JOIN existing_periods b ON b.period < d.all_dates LEFT JOIN existing_periods c ON c.period > d.all_dates WHERE a.period IS NULL AND  d.all_dates BETWEEN b.period AND c.period GROUP BY d.all_dates ) p LEFT JOIN existing_periods e ON (p.prior_available_week = e.period) LEFT JOIN existing_periods f ON (p.next_available_week = f.period) ORDER BY p.missing_period;	Test Results
1227	1040	Variability_Increase	snowflake	\N	SELECT STDDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1228	1041	Variability_Decrease	snowflake	\N	SELECT STDDEV(CAST("{COLUMN_NAME}" AS FLOAT)) as current_standard_deviation FROM {TARGET_SCHEMA}.{TABLE_NAME};	Test Results
1229	1027	Variant_Coded_Values	redshift	\N	WITH val_array AS (SELECT 1 as valkey, SPLIT_TO_ARRAY(SUBSTRING ('{DETAIL_EXPRESSION}', STRPOS('{DETAIL_EXPRESSION}', ':') + 2), '|') vals), val_list AS ( SELECT valkey, val::VARCHAR FROM val_array v, v.vals val ) SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} t INNER JOIN val_list v ON (LOWER("{COLUMN_NAME}") = v.val) GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}";	Profile Anomaly
1230	1027	Variant_Coded_Values	snowflake	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE lower("{COLUMN_NAME}") IN (SELECT trim(value) FROM TABLE (FLATTEN(INPUT => SPLIT(SUBSTRING('{DETAIL_EXPRESSION}', POSITION(':', '{DETAIL_EXPRESSION}') + 2), '|'))) ) GROUP BY "{COLUMN_NAME}";	Profile Anomaly
1231	1027	Variant_Coded_Values	mssql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE LOWER("{COLUMN_NAME}") IN (SELECT trim(value) FROM STRING_SPLIT(SUBSTRING('{DETAIL_EXPRESSION}', CHARINDEX(':', '{DETAIL_EXPRESSION}') + 2, 999), '|')) GROUP BY "{COLUMN_NAME}";	Profile Anomaly
1232	1027	Variant_Coded_Values	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE LOWER("{COLUMN_NAME}") = ANY(STRING_TO_ARRAY(SUBSTRING('{DETAIL_EXPRESSION}',  STRPOS('{DETAIL_EXPRESSION}', ':') + 2), '|')) GROUP BY "{COLUMN_NAME}";	Profile Anomaly
1233	1043	Valid_Characters	redshift	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" ~ '[[:cntrl:]]' OR "{COLUMN_NAME}" LIKE ' %' OR "{COLUMN_NAME}" LIKE '''%''' OR "{COLUMN_NAME}" LIKE '"%"' GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1234	1043	Valid_Characters	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE "{COLUMN_NAME}" ~ '[[:cntrl:]]' OR "{COLUMN_NAME}" LIKE ' %' OR "{COLUMN_NAME}" LIKE '''%''' OR "{COLUMN_NAME}" LIKE '"%"' GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC  LIMIT 20;	Test Results
1235	1043	Valid_Characters	mssql	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE PATINDEX('%[' + CHAR(1) + '-' + CHAR(8) + CHAR(11) + CHAR(12) + CHAR(14) + '-' + CHAR(31) + ']%', "{COLUMN_NAME}") > 0 OR "{COLUMN_NAME}" LIKE ' %' OR "{COLUMN_NAME}" LIKE '''%''' OR column_name LIKE '"%"' GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1236	1043	Valid_Characters	snowflake	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE REGEXP_LIKE("{COLUMN_NAME}", '.*[[:cntrl:]].*') OR "{COLUMN_NAME}"::VARCHAR LIKE ' %' OR "{COLUMN_NAME}"::VARCHAR LIKE '''%''' OR "{COLUMN_NAME}"::VARCHAR LIKE '"%"' GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1237	1044	Valid_US_Zip	redshift	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1238	1044	Valid_US_Zip	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC  LIMIT 20;	Test Results
1239	1044	Valid_US_Zip	mssql	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1240	1044	Valid_US_Zip	snowflake	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1241	1045	Valid_US_Zip3	redshift	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') <> '999' GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1242	1045	Valid_US_Zip3	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') <> '' GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC LIMIT 20;	Test Results
1243	1045	Valid_US_Zip3	mssql	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1244	1045	Valid_US_Zip3	snowflake	\N	SELECT TOP 20 "{COLUMN_NAME}", COUNT(*) AS record_ct FROM {TARGET_SCHEMA}.{TABLE_NAME} WHERE TRANSLATE("{COLUMN_NAME}",'012345678','999999999') NOT IN ('99999', '999999999', '99999-9999') GROUP BY "{COLUMN_NAME}" ORDER BY record_ct DESC;	Test Results
1245	1500	Aggregate_Balance	redshift	\N	SELECT *\n  FROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) AS total, SUM(MATCH_TOTAL) AS MATCH_TOTAL\n           FROM\n               ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} AS total, NULL AS match_total\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                  WHERE {SUBSET_CONDITION}\n                 GROUP BY {GROUPBY_NAMES}\n                 {HAVING_CONDITION}\n                   UNION ALL\n                 SELECT {MATCH_GROUPBY_NAMES}, NULL AS total, {MATCH_COLUMN_NAMES} AS match_total\n                   FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                  WHERE {MATCH_SUBSET_CONDITION}\n                 GROUP BY {MATCH_GROUPBY_NAMES}\n                 {MATCH_HAVING_CONDITION} ) a\n        GROUP BY {GROUPBY_NAMES} ) s\n WHERE total <> match_total OR (total IS NOT NULL AND match_total IS NULL) OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1246	1500	Aggregate_Balance	snowflake	\N	SELECT *\n  FROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) AS total, SUM(MATCH_TOTAL) AS MATCH_TOTAL\n           FROM\n               ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} AS total, NULL AS match_total\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                  WHERE {SUBSET_CONDITION}\n                 GROUP BY {GROUPBY_NAMES}\n                 {HAVING_CONDITION}\n                   UNION ALL\n                 SELECT {MATCH_GROUPBY_NAMES}, NULL AS total, {MATCH_COLUMN_NAMES} AS match_total\n                   FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                  WHERE {MATCH_SUBSET_CONDITION}\n                 GROUP BY {MATCH_GROUPBY_NAMES}\n                 {MATCH_HAVING_CONDITION} ) a\n        GROUP BY {GROUPBY_NAMES} ) s\n WHERE total <> match_total OR (total IS NOT NULL AND match_total IS NULL) OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1247	1500	Aggregate_Balance	mssql	\N	SELECT *\n  FROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) AS total, SUM(MATCH_TOTAL) AS MATCH_TOTAL\n           FROM\n               ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} AS total, NULL AS match_total\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                  WHERE {SUBSET_CONDITION}\n                 GROUP BY {GROUPBY_NAMES}\n                 {HAVING_CONDITION}\n                   UNION ALL\n                 SELECT {MATCH_GROUPBY_NAMES}, NULL AS total, {MATCH_COLUMN_NAMES} AS match_total\n                   FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                  WHERE {MATCH_SUBSET_CONDITION}\n                 GROUP BY {MATCH_GROUPBY_NAMES}\n                 {MATCH_HAVING_CONDITION} ) a\n        GROUP BY {GROUPBY_NAMES} ) s\n WHERE total <> match_total OR (total IS NOT NULL AND match_total IS NULL) OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1248	1500	Aggregate_Balance	postgresql	\N	SELECT *\n  FROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) AS total, SUM(MATCH_TOTAL) AS MATCH_TOTAL\n           FROM\n               ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} AS total, NULL AS match_total\n                   FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                  WHERE {SUBSET_CONDITION}\n                 GROUP BY {GROUPBY_NAMES}\n                 {HAVING_CONDITION}\n                   UNION ALL\n                 SELECT {MATCH_GROUPBY_NAMES}, NULL AS total, {MATCH_COLUMN_NAMES} AS match_total\n                   FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                  WHERE {MATCH_SUBSET_CONDITION}\n                 GROUP BY {MATCH_GROUPBY_NAMES}\n                 {MATCH_HAVING_CONDITION} ) a\n        GROUP BY {GROUPBY_NAMES} ) s\n WHERE total <> match_total OR (total IS NOT NULL AND match_total IS NULL) OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1249	1501	Aggregate_Minimum	redshift	\N	SELECT *\nFROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) as total, SUM(MATCH_TOTAL) as MATCH_TOTAL\n         FROM\n              ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} as total, NULL as match_total\n                  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                 WHERE {SUBSET_CONDITION}\n                GROUP BY {GROUPBY_NAMES}\n                {HAVING_CONDITION}\n               UNION ALL\n                SELECT {MATCH_GROUPBY_NAMES}, NULL as total, {MATCH_COLUMN_NAMES} as match_total\n                  FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                 WHERE {MATCH_SUBSET_CONDITION}\n                GROUP BY {MATCH_GROUPBY_NAMES}\n                {MATCH_HAVING_CONDITION} ) a\n         GROUP BY {GROUPBY_NAMES} ) s\n WHERE total < match_total OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1250	1501	Aggregate_Minimum	snowflake	\N	SELECT *\nFROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) as total, SUM(MATCH_TOTAL) as MATCH_TOTAL\n         FROM\n              ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} as total, NULL as match_total\n                  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                 WHERE {SUBSET_CONDITION}\n                GROUP BY {GROUPBY_NAMES}\n                {HAVING_CONDITION}\n               UNION ALL\n                SELECT {MATCH_GROUPBY_NAMES}, NULL as total, {MATCH_COLUMN_NAMES} as match_total\n                  FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                 WHERE {MATCH_SUBSET_CONDITION}\n                GROUP BY {MATCH_GROUPBY_NAMES}\n                {MATCH_HAVING_CONDITION} ) a\n         GROUP BY {GROUPBY_NAMES} ) s\n WHERE total < match_total OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1251	1501	Aggregate_Minimum	mssql	\N	SELECT *\nFROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) as total, SUM(MATCH_TOTAL) as MATCH_TOTAL\n         FROM\n              ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} as total, NULL as match_total\n                  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                 WHERE {SUBSET_CONDITION}\n                GROUP BY {GROUPBY_NAMES}\n                {HAVING_CONDITION}\n               UNION ALL\n                SELECT {MATCH_GROUPBY_NAMES}, NULL as total, {MATCH_COLUMN_NAMES} as match_total\n                  FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                 WHERE {MATCH_SUBSET_CONDITION}\n                GROUP BY {MATCH_GROUPBY_NAMES}\n                {MATCH_HAVING_CONDITION} ) a\n         GROUP BY {GROUPBY_NAMES} ) s\n WHERE total < match_total OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1252	1501	Aggregate_Minimum	postgresql	\N	SELECT *\nFROM ( SELECT {GROUPBY_NAMES}, SUM(TOTAL) as total, SUM(MATCH_TOTAL) as MATCH_TOTAL\n         FROM\n              ( SELECT {GROUPBY_NAMES}, {COLUMN_NAME_NO_QUOTES} as total, NULL as match_total\n                  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n                 WHERE {SUBSET_CONDITION}\n                GROUP BY {GROUPBY_NAMES}\n                {HAVING_CONDITION}\n               UNION ALL\n                SELECT {MATCH_GROUPBY_NAMES}, NULL as total, {MATCH_COLUMN_NAMES} as match_total\n                  FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n                 WHERE {MATCH_SUBSET_CONDITION}\n                GROUP BY {MATCH_GROUPBY_NAMES}\n                {MATCH_HAVING_CONDITION} ) a\n         GROUP BY {GROUPBY_NAMES} ) s\n WHERE total < match_total OR (total IS NULL AND match_total IS NOT NULL)\nORDER BY {GROUPBY_NAMES};	Test Results
1253	1502	Combo_Match	redshift	\N	SELECT *\n  FROM ( SELECT {COLUMN_NAME_NO_QUOTES}\n           FROM {TARGET_SCHEMA}.{TABLE_NAME}\n           WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES}\n         {HAVING_CONDITION}\n          EXCEPT\n         SELECT {MATCH_GROUPBY_NAMES}\n           FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n          WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES}\n         {MATCH_HAVING_CONDITION}\n       ) test\nORDER BY {COLUMN_NAME_NO_QUOTES};	Test Results
1254	1502	Combo_Match	snowflake	\N	SELECT *\n  FROM ( SELECT {COLUMN_NAME_NO_QUOTES}\n           FROM {TARGET_SCHEMA}.{TABLE_NAME}\n           WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES}\n         {HAVING_CONDITION}\n          EXCEPT\n         SELECT {MATCH_GROUPBY_NAMES}\n           FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n          WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES}\n         {MATCH_HAVING_CONDITION}\n       ) test\nORDER BY {COLUMN_NAME_NO_QUOTES};	Test Results
1255	1502	Combo_Match	mssql	\N	SELECT *\n  FROM ( SELECT {COLUMN_NAME_NO_QUOTES}\n           FROM {TARGET_SCHEMA}.{TABLE_NAME}\n           WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES}\n         {HAVING_CONDITION}\n          EXCEPT\n         SELECT {MATCH_GROUPBY_NAMES}\n           FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n          WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES}\n         {MATCH_HAVING_CONDITION}\n       ) test\nORDER BY {COLUMN_NAME_NO_QUOTES};	Test Results
1256	1502	Combo_Match	postgresql	\N	SELECT *\n  FROM ( SELECT {COLUMN_NAME_NO_QUOTES}\n           FROM {TARGET_SCHEMA}.{TABLE_NAME}\n           WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES}\n         {HAVING_CONDITION}\n          EXCEPT\n         SELECT {MATCH_GROUPBY_NAMES}\n           FROM {MATCH_SCHEMA_NAME}.{MATCH_TABLE_NAME}\n          WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES}\n         {MATCH_HAVING_CONDITION}\n       ) test\nORDER BY {COLUMN_NAME_NO_QUOTES};	Test Results
1257	1503	Distribution_Shift	redshift	\N	WITH latest_ver\n   AS ( SELECT {CONCAT_COLUMNS} as category,\n               COUNT(*)::FLOAT / SUM(COUNT(*)) OVER ()::FLOAT AS pct_of_total\n          FROM {TARGET_SCHEMA}.{TABLE_NAME} v1\n         WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES} ),\nolder_ver\n   AS ( SELECT {CONCAT_MATCH_GROUPBY} as category,\n               COUNT(*)::FLOAT / SUM(COUNT(*)) OVER ()::FLOAT AS pct_of_total\n          FROM {MATCH_SCHEMA_NAME}.{TABLE_NAME} v2\n         WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES} )\nSELECT COALESCE(l.category, o.category) AS category,\n       o.pct_of_total AS old_pct,\n       l.pct_of_total AS new_pct\n  FROM latest_ver l\nFULL JOIN older_ver o\n  ON (l.category = o.category)\nORDER BY COALESCE(l.category, o.category)	Test Results
1258	1503	Distribution_Shift	snowflake	\N	WITH latest_ver\n   AS ( SELECT {CONCAT_COLUMNS} as category,\n               COUNT(*)::FLOAT / SUM(COUNT(*)) OVER ()::FLOAT AS pct_of_total\n          FROM {TARGET_SCHEMA}.{TABLE_NAME} v1\n         WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES} ),\nolder_ver\n   AS ( SELECT {CONCAT_MATCH_GROUPBY} as category,\n               COUNT(*)::FLOAT / SUM(COUNT(*)) OVER ()::FLOAT AS pct_of_total\n          FROM {MATCH_SCHEMA_NAME}.{TABLE_NAME} v2\n         WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES} )\nSELECT COALESCE(l.category, o.category) AS category,\n       o.pct_of_total AS old_pct,\n       l.pct_of_total AS new_pct\n  FROM latest_ver l\nFULL JOIN older_ver o\n  ON (l.category = o.category)\nORDER BY COALESCE(l.category, o.category)	Test Results
1259	1503	Distribution_Shift	mssql	\N	WITH latest_ver\n   AS ( SELECT {CONCAT_COLUMNS} as category,\n               CAST(COUNT(*) as FLOAT) / CAST(SUM(COUNT(*)) OVER () as FLOAT) AS pct_of_total\n          FROM {TARGET_SCHEMA}.{TABLE_NAME} v1\n         WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES} ),\nolder_ver\n   AS ( SELECT {CONCAT_MATCH_GROUPBY} as category,\n               CAST(COUNT(*) as FLOAT) / CAST(SUM(COUNT(*)) OVER () as FLOAT) AS pct_of_total\n          FROM {MATCH_SCHEMA_NAME}.{TABLE_NAME} v2\n         WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES} )\nSELECT COALESCE(l.category, o.category) AS category,\n       o.pct_of_total AS old_pct,\n       l.pct_of_total AS new_pct\n  FROM latest_ver l\nFULL JOIN older_ver o\n  ON (l.category = o.category)\nORDER BY COALESCE(l.category, o.category)	Test Results
1260	1503	Distribution_Shift	postgresql	\N	WITH latest_ver\n   AS ( SELECT {CONCAT_COLUMNS} as category,\n               COUNT(*)::FLOAT / SUM(COUNT(*)) OVER ()::FLOAT AS pct_of_total\n          FROM {TARGET_SCHEMA}.{TABLE_NAME} v1\n         WHERE {SUBSET_CONDITION}\n         GROUP BY {COLUMN_NAME_NO_QUOTES} ),\nolder_ver\n   AS ( SELECT {CONCAT_MATCH_GROUPBY} as category,\n               COUNT(*)::FLOAT / SUM(COUNT(*)) OVER ()::FLOAT AS pct_of_total\n          FROM {MATCH_SCHEMA_NAME}.{TABLE_NAME} v2\n         WHERE {MATCH_SUBSET_CONDITION}\n         GROUP BY {MATCH_GROUPBY_NAMES} )\nSELECT COALESCE(l.category, o.category) AS category,\n       o.pct_of_total AS old_pct,\n       l.pct_of_total AS new_pct\n  FROM latest_ver l\nFULL JOIN older_ver o\n  ON (l.category = o.category)\nORDER BY COALESCE(l.category, o.category)	Test Results
1261	1508	Timeframe_Combo_Gain	redshift	\N	SELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n   AND {WINDOW_DATE_COLUMN} < (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nGROUP BY {COLUMN_NAME_NO_QUOTES}\n EXCEPT\nSELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nGROUP BY {COLUMN_NAME_NO_QUOTES}	Test Results
1262	1508	Timeframe_Combo_Gain	snowflake	\N	SELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n   AND {WINDOW_DATE_COLUMN} < (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nGROUP BY {COLUMN_NAME_NO_QUOTES}\n EXCEPT\nSELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nGROUP BY {COLUMN_NAME_NO_QUOTES}	Test Results
1263	1508	Timeframe_Combo_Gain	mssql	\N	SELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= DATEADD("day",  - 2 * {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\n   AND {WINDOW_DATE_COLUMN} <  DATEADD("day", - {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\nGROUP BY {COLUMN_NAME_NO_QUOTES}\n EXCEPT\nSELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= DATEADD("day", - {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\nGROUP BY {COLUMN_NAME_NO_QUOTES}	Test Results
1264	1508	Timeframe_Combo_Gain	postgresql	\N	SELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n   AND {WINDOW_DATE_COLUMN} < (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nGROUP BY {COLUMN_NAME_NO_QUOTES}\n EXCEPT\nSELECT {COLUMN_NAME_NO_QUOTES}\n  FROM {TARGET_SCHEMA}.{TABLE_NAME}\n WHERE {SUBSET_CONDITION}\n   AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nGROUP BY {COLUMN_NAME_NO_QUOTES}	Test Results
1265	1509	Timeframe_Combo_Match	redshift	\N	        (\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nEXCEPT\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n  AND {WINDOW_DATE_COLUMN} <  (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n)\nUNION ALL\n(\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n  AND {WINDOW_DATE_COLUMN} < (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n    EXCEPT\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n)	Test Results
1266	1509	Timeframe_Combo_Match	snowflake	\N	        (\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nEXCEPT\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n  AND {WINDOW_DATE_COLUMN} <  (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n)\nUNION ALL\n(\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n  AND {WINDOW_DATE_COLUMN} < (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n    EXCEPT\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n)	Test Results
1267	1509	Timeframe_Combo_Match	mssql	\N	        (\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= DATEADD("day", - {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\nEXCEPT\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= DATEADD("day",  - 2 * {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\n  AND {WINDOW_DATE_COLUMN} <  DATEADD("day", - {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\n)\nUNION ALL\n(\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= DATEADD("day",  - 2 * {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\n  AND {WINDOW_DATE_COLUMN} < DATEADD("day", - {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\n    EXCEPT\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= DATEADD("day", - {WINDOW_DAYS}, (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}))\n)	Test Results
1268	1509	Timeframe_Combo_Match	postgresql	\N	        (\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\nEXCEPT\nSELECT 'Prior Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n  AND {WINDOW_DATE_COLUMN} <  (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n)\nUNION ALL\n(\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - 2 * {WINDOW_DAYS}\n  AND {WINDOW_DATE_COLUMN} < (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n    EXCEPT\nSELECT 'Latest Timeframe' as missing_from, {COLUMN_NAME}\nFROM {TARGET_SCHEMA}.{TABLE_NAME}\nWHERE {SUBSET_CONDITION}\n  AND {WINDOW_DATE_COLUMN} >= (SELECT MAX({WINDOW_DATE_COLUMN}) FROM {TARGET_SCHEMA}.{TABLE_NAME}) - {WINDOW_DAYS}\n)	Test Results
1269	1100	Potential_PII	redshift	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1270	1100	Potential_PII	snowflake	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1271	1100	Potential_PII	mssql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
1272	1100	Potential_PII	postgresql	\N	SELECT "{COLUMN_NAME}", COUNT(*) AS count  FROM {TARGET_SCHEMA}.{TABLE_NAME} GROUP BY "{COLUMN_NAME}" ORDER BY "{COLUMN_NAME}" DESC LIMIT 500;	Profile Anomaly
\.


--
-- Data for Name: test_definitions; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.test_definitions (id, cat_test_id, table_groups_id, profile_run_id, test_type, test_suite_id, test_description, test_action, schema_name, table_name, column_name, skip_errors, baseline_ct, baseline_unique_ct, baseline_value, baseline_value_ct, threshold_value, baseline_sum, baseline_avg, baseline_sd, subset_condition, groupby_names, having_condition, window_date_column, window_days, match_schema_name, match_table_name, match_column_names, match_subset_condition, match_groupby_names, match_having_condition, test_mode, custom_query, test_active, test_definition_status, severity, watch_level, check_result, lock_refresh, last_auto_gen_date, profiling_as_of_date, last_manual_update, export_to_observability) FROM stdin;
\.


--
-- Data for Name: test_results; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.test_results (id, result_id, test_type, test_suite_id, test_definition_id, auto_gen, test_time, starttime, endtime, schema_name, table_name, column_names, skip_errors, input_parameters, result_code, severity, result_status, result_message, result_measure, threshold_value, result_error_data, test_action, disposition, subset_condition, result_query, test_description, test_run_id, table_groups_id, dq_prevalence, dq_record_ct, observability_status) FROM stdin;
\.


--
-- Data for Name: test_runs; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.test_runs (id, test_suite_id, test_starttime, test_endtime, status, log_message, duration, test_ct, passed_ct, failed_ct, warning_ct, error_ct, table_ct, column_ct, column_failed_ct, column_warning_ct, dq_affected_data_points, dq_total_data_points, dq_score_test_run, process_id) FROM stdin;
\.


--
-- Data for Name: test_suites; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.test_suites (id, project_code, test_suite, connection_id, table_groups_id, test_suite_description, test_action, severity, export_to_observability, test_suite_schema, component_key, component_type, component_name, last_complete_test_run_id, dq_score_exclude) FROM stdin;
1f89b7da-3512-40af-88a6-a530116ccfed	DEFAULT	default-suite-1	1	0ea85e17-acbe-47fe-8394-9970725ad37d	default-suite-1 Test Suite	\N	\N	Y	\N	\N	dataset	\N	\N	f
\.


--
-- Data for Name: test_templates; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.test_templates (id, test_type, sql_flavor, template_name) FROM stdin;
2001	Combo_Match	redshift	ex_data_match_generic.sql
2002	Aggregate_Minimum	redshift	ex_aggregate_match_no_drops_generic.sql
2003	Distribution_Shift	redshift	ex_relative_entropy_generic.sql
2004	CUSTOM	redshift	ex_custom_query_generic.sql
2006	Aggregate_Balance	redshift	ex_aggregate_match_same_generic.sql
2007	Timeframe_Combo_Gain	redshift	ex_window_match_no_drops_generic.sql
2008	Timeframe_Combo_Match	redshift	ex_window_match_same_generic.sql
2009	Aggregate_Increase	redshift	ex_aggregate_match_num_incr_generic.sql
2101	Combo_Match	snowflake	ex_data_match_generic.sql
2102	Aggregate_Minimum	snowflake	ex_aggregate_match_no_drops_generic.sql
2103	Distribution_Shift	snowflake	ex_relative_entropy_generic.sql
2104	CUSTOM	snowflake	ex_custom_query_generic.sql
2106	Aggregate_Balance	snowflake	ex_aggregate_match_same_generic.sql
2107	Timeframe_Combo_Gain	snowflake	ex_window_match_no_drops_generic.sql
2108	Timeframe_Combo_Match	snowflake	ex_window_match_same_generic.sql
2109	Aggregate_Increase	snowflake	ex_aggregate_match_num_incr_generic.sql
2201	Combo_Match	mssql	ex_data_match_generic.sql
2202	Aggregate_Minimum	mssql	ex_aggregate_match_no_drops_generic.sql
2203	Distribution_Shift	mssql	ex_relative_entropy_mssql.sql
2204	CUSTOM	mssql	ex_custom_query_generic.sql
2206	Aggregate_Balance	mssql	ex_aggregate_match_same_generic.sql
2207	Timeframe_Combo_Gain	mssql	ex_window_match_no_drops_generic.sql
2208	Timeframe_Combo_Match	mssql	ex_window_match_same_generic.sql
2209	Aggregate_Increase	mssql	ex_aggregate_match_num_incr_generic.sql
2301	Combo_Match	postgresql	ex_data_match_generic.sql
2302	Aggregate_Minimum	postgresql	ex_aggregate_match_no_drops_generic.sql
2303	Distribution_Shift	postgresql	ex_relative_entropy_generic.sql
2304	CUSTOM	postgresql	ex_custom_query_generic.sql
2306	Aggregate_Balance	postgresql	ex_aggregate_match_same_generic.sql
2307	Timeframe_Combo_Gain	postgresql	ex_window_match_no_drops_postgresql.sql
2308	Timeframe_Combo_Match	postgresql	ex_window_match_same_postgresql.sql
2309	Aggregate_Increase	postgresql	ex_aggregate_match_num_incr_generic.sql
\.


--
-- Data for Name: test_types; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.test_types (id, test_type, test_name_short, test_name_long, test_description, except_message, measure_uom, measure_uom_description, selection_criteria, dq_score_prevalence_formula, dq_score_risk_factor, column_name_prompt, column_name_help, default_parm_columns, default_parm_values, default_parm_prompts, default_parm_help, default_severity, run_type, test_scope, dq_dimension, health_dimension, threshold_description, usage_notes, active) FROM stdin;
1004	Alpha_Trunc	Alpha Truncation	Maximum character count consistent	Tests that the maximum count of characters in a column value has not dropped vs. baseline data	Maximum length of values has dropped from prior expected length.	Values over max	\N	general_type ='A' AND max_length > 0 AND ( (min_length = avg_length AND max_length = avg_length) OR (numeric_ct <> value_ct ) ) AND functional_table_type NOT LIKE  '%window%' /*  The conditions below are to eliminate overlap with : LOV_Match (excluded selection criteria for this test_type),  Pattern_Match (excluded selection criteria for this test_type), Constant (excluded functional_data_type Constant and Boolean) */ AND ( (distinct_value_ct NOT BETWEEN 2 AND 10  AND functional_data_type NOT IN ( 'Constant', 'Boolean') ) AND NOT ( fn_charcount(top_patterns, E' \\| ' ) = 1   AND fn_charcount(top_patterns, E' \\| ' ) IS NOT NULL AND REPLACE(SPLIT_PART(top_patterns, '|' , 2), 'N' , '' ) > ''))	{VALUE_CT}::FLOAT * (FN_NORMAL_CDF(({MAX_LENGTH}::FLOAT - {AVG_LENGTH}::FLOAT) / ({MAX_LENGTH}::FLOAT / 3)) - FN_NORMAL_CDF(({RESULT_MEASURE}::FLOAT - {AVG_LENGTH}::FLOAT) / ({MAX_LENGTH}::FLOAT / 3)) ) /{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	max_length	Maximum String Length at Baseline	\N	Fail	CAT	column	Validity	Schema Drift	Maximum length expected	Alpha Truncation tests that the longest text value in a column hasn't become shorter than the longest value at baseline. This could indicate a problem in a cumulative dataset, where prior values should still exist unchanged. A failure here would suggest that some process changed data that you would still expect to be present and matching its value when the column was profiled. This test would not be appropriate for an incremental or windowed dataset.	Y
1005	Avg_Shift	Average Shift	Column mean is consistent with reference	Tests for statistically-significant shift in mean value for column from average calculated at baseline.	Standardized difference between averages is over the selected threshold level.	Difference Measure	Cohen's D Difference (0.20 small, 0.5 mod, 0.8 large, 1.2 very large, 2.0 huge)	general_type='N' AND distinct_value_ct > 10 AND functional_data_type ilike 'Measure%' AND column_name NOT ilike '%latitude%' AND column_name NOT ilike '%longitude%'	LEAST({RESULT_MEASURE}, 1.0)	0.75	\N	\N	baseline_value_ct,baseline_avg,baseline_sd,threshold_value	value_ct,avg_value,stdev_value,0.5::VARCHAR	Value Ct at Baseline,Mean at Baseline,Std Deviation at Baseline,Threshold Difference Measure 	\N	Warning	CAT	column	Consistency	Data Drift	Standardized Difference Measure	Average Shift tests that the average of a numeric column has not significantly changed since baseline, when profiling was done. A significant shift may indicate errors in processing, differences in source data, or valid changes that may nevertheless impact assumptions in downstream data products. The test uses Cohen's D, a statistical technique to identify significant shifts in a value. Cohen's D measures the difference between the two averages, reporting results on a standardized scale, which can be interpreted via a rule-of-thumb from small to huge. Depending on your data, some difference may be expected, so it's reasonable to adjust the threshold value that triggers test failure. This test works well for measures, or even for identifiers if you expect them to increment consistently. You may want to periodically adjust the expected threshold, or even the expected average value if you expect shifting over time. Consider this test along with Variability Increase. If variability rises too, process or measurement flaws could be at work. If variability remains consistent, the issue is more likely to be with the source data itself.  	Y
1007	Constant	Constant Match	All column values match constant value	Tests that all values in the column match the constant value identified in baseline data	A constant value is expected for this column.	Mismatched values	\N	TEMPLATE	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	baseline_value,threshold_value	\N	Constant Value at Baseline,Threshold Error Count	The single, unchanging value of the column, per baseline|The number of errors that are acceptable before test fails.	Fail	CAT	column	Validity	Schema Drift	Count of records with unexpected values	Constant Match tests that a single value determined to be a constant in baseline profiling is still the only value for the column that appears in subsequent versions of the dataset. Sometimes new data or business knowledge may reveal that the value is not a constant at all, even though only one value was present at profiling. In this case, you will want to disable this test. Alternatively, you can use the Value Match test to provide a limited number of valid values for the column.	Y
1009	Daily_Record_Ct	Daily Records	All dates present within date range	Tests for presence of every calendar date within min/max date range, per baseline data	Not every date value between min and max dates is present, unlike at baseline.	Missing dates	\N	general_type= 'D' AND date_days_present > 21 AND date_days_present - (DATEDIFF('day', '1800-01-05'::DATE, max_date) - DATEDIFF('day', '1800-01-05'::DATE, min_date) + 1) = 0 AND future_date_ct::FLOAT / NULLIF(value_ct, 0) <= 0.75	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT*{PRO_RECORD_CT}::FLOAT/{DATE_DAYS_PRESENT}::FLOAT/{RECORD_CT}::FLOAT	0.75	\N	\N	threshold_value	0	Threshold Missing Calendar Days	\N	Warning	CAT	column	Completeness	Volume	Missing calendar days within min/max range	Daily Records tests that at least one record is present for every day within the minimum and maximum date range for the column. The test is relevant for transactional data, where you would expect at least one transaction to be recorded each day. A failure here would suggest missing records for the number of days identified without data. You can adjust the threshold to accept a number of days that you know legitimately have no records. 	Y
1011	Dec_Trunc	Decimal Truncation	Sum of fractional values at or above reference	Tests for decimal truncation by confirming that the sum of fractional values in data is no less than the sum at baseline	The sum of fractional values is under baseline, which may indicate decimal truncation	Fractional sum	The sum of all decimal values from all data for this column	fractional_sum IS NOT NULL AND functional_table_type LIKE'%cumulative%'	1	1.0	\N	\N	threshold_value	ROUND(fractional_sum, 0)	Sum of Fractional Values at Baseline	\N	Fail	CAT	column	Validity	Schema Drift	Minimum expected sum of all fractional values	Decimal Truncation tests that the fractional (decimal) part of a numeric column has not been truncated since Baseline.  This works by summing all the fractional values after the decimal point and confirming that the total is at least equal to the fractional total at baseline.  This could indicate a problem in a cumulative dataset, where prior values should still exist unchanged. A failure here would suggest that some process changed data that you would still expect to be present and matching its value when the column was profiled. This test would not be appropriate for an incremental or windowed dataset.	Y
1012	Distinct_Date_Ct	Date Count	Count of distinct dates at or above reference	Tests that the count of distinct dates referenced in the column has not dropped vs. baseline data	Drop in count of unique dates recorded in column.	Unique dates	Count of unique dates in transactional date column	general_type='D' and date_days_present IS NOT NULL AND functional_table_type NOT LIKE  '%window%'	(({RECORD_CT}-{PRO_RECORD_CT})::FLOAT*{DISTINCT_VALUE_CT}::FLOAT/{PRO_RECORD_CT}::FLOAT)/{PRO_RECORD_CT}::FLOAT	1.0	\N	\N	baseline_value,threshold_value	date_days_present,date_days_present	Distinct Date Count at Baseline,Min Expected Date Count	\N	Fail	CAT	column	Timeliness	Recency	Minimum distinct date count expected	Date Count tests that the count of distinct dates present in the column has not dropped since baseline. The test is relevant for cumulative datasets, where old records are retained. A failure here would indicate missing records, which could be caused by a processing error or changed upstream data sources.	Y
1013	Distinct_Value_Ct	Value Count	Count of distinct values has not dropped	Tests that the count of unique values in the column has not changed from baseline.	Count of unique values in column has changed from baseline.	Unique Values	\N	distinct_value_ct between 2 and 10 AND value_ct > 0 AND NOT (coalesce(top_freq_values,'') > '' AND distinct_value_ct BETWEEN 2 and 10) AND NOT (lower(functional_data_type) LIKE '%sequence%' OR lower(functional_data_type) LIKE '%measurement%' OR functional_data_type LIKE '%date%' OR general_type = 'D')	ABS({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT*{PRO_RECORD_CT}::FLOAT/{DISTINCT_VALUE_CT}::FLOAT	1.0	\N	\N	baseline_value_ct,threshold_value	distinct_value_ct,distinct_value_ct	Distinct Value Count at Baseline,Min Expected Value Count	\N	Fail	CAT	column	Validity	Schema Drift	Expected distinct value count	Value Count tests that the  count of unique values present in the column has not dropped since baseline. The test is relevant for cumulative datasets, where old records are retained, or for any dataset where you would expect a set number of distinct values should be present. A failure here would indicate missing records or a change in categories or value assignment.	Y
1014	Email_Format	Email Format	Email is correctly formatted	Tests that non-blank, non-empty email addresses match the standard format	Invalid email address formats found.	Invalid emails	Number of emails that do not match standard format	std_pattern_match='EMAIL'	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Maximum Invalid Email Count	\N	Fail	CAT	column	Validity	Schema Drift	Expected count of invalid email addresses	\N	Y
1015	Future_Date	Past Dates	Latest date is prior to test run date	Tests that the maximum date referenced in the column is no greater than the test date, consistent with baseline data	Future date found when absent in baseline data.	Future dates	\N	general_type='D'AND future_date_ct = 0	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Maximum Future Date Count	\N	Fail	CAT	column	Timeliness	Recency	Expected count of future dates	\N	Y
1016	Future_Date_1Y	Future Year	Future dates within year of test run date	Tests that the maximum date referenced in the column is no greater than one year beyond the test date, consistent with baseline data	Future date beyond one-year found when absent in baseline.	Future dates post 1 year	\N	general_type='D'AND future_date_ct > 0 AND max_date <='{AS_OF_DATE}'::DATE + INTERVAL'365 DAYS'	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Maximum Post 1-Year Future Date Count	\N	Fail	CAT	column	Timeliness	Recency	Expected count of future dates beyond one year	Future Year looks for date values in the column that extend beyond one year after the test date. This would be appropriate for transactional dates where you would expect to find dates in the  near future, but not beyond one year ahead.  Errors could indicate invalid entries or possibly dummy dates representing blank values.	Y
1017	Incr_Avg_Shift	New Shift	New record mean is consistent with reference	Tests for statistically-significant shift in mean of new values for column compared to average calculated at baseline.	Significant shift in average of new values vs. baseline avg	Z-score of mean shift	Absolute Z-score (number of SD's outside mean) of prior avg - incremental avg	general_type='N' AND distinct_value_ct > 10 AND functional_data_type ilike 'Measure%' AND column_name NOT ilike '%latitude%' AND column_name NOT ilike '%longitude%'	{RECORD_CT}::FLOAT*(1-FN_NORMAL_CDF({RESULT_MEASURE}::FLOAT))/{RECORD_CT}::FLOAT	0.75	\N	\N	baseline_value_ct,baseline_sum,baseline_avg,baseline_sd,threshold_value	value_ct,(avg_value * value_ct)::FLOAT,avg_value,stdev_value,2	Value Count at Baseline,Sum at Baseline,Mean Value at Baseline,Std Deviation at Baseline,Threshold Max Z-Score	\N	Warning	CAT	column	Accuracy	Data Drift	Maximum Z-Score (number of SD's beyond mean) expected	This is a more sensitive test than Average Shift, because it calculates an incremental difference in the average of new values compared to the average of values at baseline. This is appropriate for a cumulative dataset only, because it calculates the average of new entries based on the assumption that the count and average of records present at baseline are still present at the time of the test. This test compares the mean of new values with the standard deviation of the baseline average to calculate a Z-score.  If the new mean falls outside the Z-score threshold, a shift is detected. Potential Z-score thresholds may range from 0 to 3, depending on the sensitivity you prefer.  A failed test could indicate a quality issue or a legitimate shift in new data that should be noted and assessed by business users. Consider this test along with Variability Increase. If variability rises too, process, methodology or measurement flaws could be at issue. If variability remains consistent, the problem is more likely to be with the source data itself.	Y
1018	LOV_All	Value Match All	List of expected values all present in column	Tests that all values match a pipe-delimited list of expected values and that all expected values are present	Column values found don't exactly match the expected list of values	Values found	\N	\N	1	1.0	\N	\N	threshold_value	\N	List of Expected Values	\N	Fail	CAT	column	Validity	Schema Drift	List of values expected, in form ('Val1','Val2)	This is a more restrictive form of Value Match, testing that all values in the dataset match the list provided, and also that all values present in the list appear at least once in the dataset. This would be appropriate for tables where all category values in the column are represented at least once.	Y
1019	LOV_Match	Value Match	All column values present in expected list	Tests that all values in the column match the list-of-values identified in baseline data.	Values not matching expected List-of-Values from baseline.	Non-matching records	\N	top_freq_values > '' AND distinct_value_ct BETWEEN 2 and 10 AND NOT (functional_data_type LIKE '%date%' OR  lower(datatype_suggestion) LIKE '%date%' OR general_type = 'D' OR lower(column_name) IN ('file_name', 'filename'))	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	baseline_value,threshold_value	'(' || SUBSTRING( CASE WHEN SPLIT_PART(top_freq_values, '|' , 2) > '' THEN ',''' || TRIM( REPLACE ( SPLIT_PART(top_freq_values, '|' , 2), '''' , '''''' ) ) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 4) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 4), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 6) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 6), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 8) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 8), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 10) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 10), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 12) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 12), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 14) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 14), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 16) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 16), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 18) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 18), '''' , '''''' )) || '''' ELSE '' END || CASE WHEN SPLIT_PART(top_freq_values, '|' , 20) > '' THEN ',''' || TRIM(REPLACE(SPLIT_PART(top_freq_values, '|' , 20), '''' , '''''' )) || '''' ELSE '' END, 2, 999) || ')',0	List of Expected Values,Threshold Error Count	\N	Fail	CAT	column	Validity	Schema Drift	List of values expected, in form ('Val1','Val2)	This tests that all values in the column match the hard-coded list provided. This is relevant when the list of allowable values is small and not expected to change often. Even if new values might occasionally be added, this test is useful for downstream data products to provide warning that assumptions and logic may need to change.	Y
1020	Min_Date	Minimum Date	All dates on or after set minimum	Tests that the earliest date referenced in the column is no earlier than baseline data	The earliest date value found is before the earliest value at baseline.	Dates prior to limit	\N	general_type='D'and min_date IS NOT NULL AND distinct_value_ct > 1	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	baseline_value,threshold_value	min_date,0	Minimum Date at Baseline,Threshold Error Count	\N	Fail	CAT	column	Validity	Schema Drift	Expected count of dates prior to minimum	This test is appropriate for a cumulative dataset only, because it assumes all prior values are still present. It's appropriate where new records are added with more recent dates, but old dates dates do not change.	Y
1021	Min_Val	Minimum Value	All values at or above set minimum	Tests that the minimum value present in the column is no lower than the minimum value in baseline data	Minimum column value less than baseline.	Values under limit	\N	general_type='N'and min_value IS NOT NULL AND (distinct_value_ct >= 2 OR (distinct_value_ct=2 and min_value<>0 and max_value<>1))	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	baseline_value,threshold_value	min_value,0	Minimum Value at Baseline,Threshold Error Count	\N	Fail	CAT	column	Validity	Schema Drift	Expected count of values under limit	This test is appropriate for a cumulative dataset only, assuming all prior values are still present. It is also appropriate for any measure that has an absolute, definable minimum value, or a heuristic that makes senes for valid data.	Y
1022	Missing_Pct	Percent Missing	Consistent ratio of missing values	Tests for statistically-significant shift in percentage of missing values in column vs. baseline data	Significant shift in percent of missing values vs. baseline.	Difference measure	Cohen's H Difference (0.20 small, 0.5 mod, 0.8 large, 1.2 very large, 2.0 huge)	record_ct <> value_ct	LEAST({RESULT_MEASURE}, 1.0)	0.75	\N	\N	baseline_ct,baseline_value_ct,threshold_value	record_ct,value_ct,2::VARCHAR(10)	Baseline Record Count,Baseline Value Count,Standardized Difference Measure	\N	Warning	CAT	column	Completeness	Data Drift	Expected maximum Cohen's H Difference	This test uses Cohen's H, a statistical test to identify a significant difference between two ratios.  Results are reported on a standardized scale, which can be interpreted via a rule-of-thumb from small to huge.  An uptick in missing data may indicate a collection issue at the source.  A larger change may indicate a processing failure. A drop in missing data may also be significant, if it affects assumptions built into analytic products downstream. You can refine the expected threshold value as you view legitimate results of the measure over time.	Y
1023	Monthly_Rec_Ct	Monthly Records	At least one date per month present within date range	Tests for presence of at least one date per calendar month within min/max date range, per baseline data	At least one date per month expected in min/max date range.	Missing months	Calendar months without date values present	general_type= 'D' AND date_days_present > 1 AND date_months_present > 2 AND date_months_present - (datediff( 'MON' , min_date, max_date) + 1) = 0 AND future_date_ct::FLOAT / NULLIF(value_ct, 0) <= 0.75	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT*{PRO_RECORD_CT}::FLOAT/{DATE_MONTHS_PRESENT}::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Threshold Count of Months without Dates	\N	Fail	CAT	column	Completeness	Volume	Expected maximum count of calendar months without dates present	Monthly Records tests that at least one record is present for every calendar month within the minimum and maximum date range for the column. The test is relevant for transactional data, where you would expect at least one transaction to be recorded each month. A failure here would suggest missing records for the number of months identified without data. You can adjust the threshold to accept a number of month that you know legitimately have no records.	Y
1024	Outlier_Pct_Above	Outliers Above	Consistent outlier counts over 2 SD above mean	Tests that percent of outliers over 2 SD above Mean doesn't exceed threshold	Percent of outliers exceeding 2 SD above the mean is greater than expected threshold.	Pct records over limit	\N	general_type = 'N' AND functional_data_type ilike 'Measure%' AND column_name NOT ilike '%latitude%' AND column_name NOT ilike '%longitude%' AND value_ct <> distinct_value_ct AND distinct_value_ct > 10 AND stdev_value > 0 AND avg_value IS NOT NULL AND NOT (distinct_value_ct = max_value - min_value + 1 AND distinct_value_ct > 2)	GREATEST(0, {RESULT_MEASURE}::FLOAT-{THRESHOLD_VALUE}::FLOAT)	0.75	\N	\N	baseline_avg,baseline_sd,threshold_value	avg_value,stdev_value,0.05	Baseline Mean, Baseline Std Deviation, Pct Records over 2 SD	\N	Warning	CAT	column	Accuracy	Data Drift	Expected maximum pct records over upper 2 SD limit	This test counts the number of data points that may be considered as outliers, determined by whether their value exceeds 2 standard deviations above the mean at baseline.  Assuming a normal distribution, a small percentage (defaulted to 5%) of outliers is expected. The actual number may vary for different distributions. The expected threshold reflects the maximum percentage of outliers you expect to see.  This test uses the baseline mean rather than the mean for the latest dataset to capture systemic shift as well as individual outliers. 	Y
1025	Outlier_Pct_Below	Outliers Below	Consistent outlier counts under 2 SD below mean	Tests that percent of outliers over 2 SD below Mean doesn't exceed threshold	Percent of outliers exceeding 2 SD below the mean is greater than expected threshold.	Pct records under limit	\N	general_type = 'N' AND functional_data_type ilike 'Measure%' AND column_name NOT ilike '%latitude%' AND column_name NOT ilike '%longitude%' AND value_ct <> distinct_value_ct AND distinct_value_ct > 10 AND stdev_value > 0 AND avg_value IS NOT NULL AND NOT (distinct_value_ct = max_value - min_value + 1 AND distinct_value_ct > 2)	GREATEST(0, {RESULT_MEASURE}::FLOAT-{THRESHOLD_VALUE}::FLOAT)	0.75	\N	\N	baseline_avg,baseline_sd,threshold_value	avg_value,stdev_value,0.05	Baseline Mean, Baseline Std Deviation, Pct Records over 2 SD	\N	Warning	CAT	column	Accuracy	Data Drift	Expected maximum pct records over lower 2 SD limit	This test counts the number of data points that may be considered as outliers, determined by whether their value exceeds 2 standard deviations below the mean at baseline.  Assuming a normal distribution, a small percentage (defaulted to 5%) of outliers is expected. The actual number may vary for different distributions. The expected threshold reflects the maximum percentage of outliers you expect to see.  This test uses the baseline mean rather than the mean for the latest dataset to capture systemic shift as well as individual outliers. 	Y
1026	Pattern_Match	Pattern Match	Column values match alpha-numeric pattern	Tests that all values in the column match the same alpha-numeric pattern identified in baseline data	Alpha values do not match consistent pattern in baseline.	Pattern Mismatches	\N	fn_charcount(top_patterns, E' \\| ' ) = 1 AND REPLACE(SPLIT_PART(top_patterns, '|' , 2), 'N' , '' ) > '' AND distinct_value_ct > 10	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	baseline_value,threshold_value	TRIM(REPLACE(REPLACE(REPLACE(REGEXP_REPLACE(SPLIT_PART(top_patterns, ' | ', 2), '([*+\\-%_])', '[\\1]', 'g'), 'A', '[A-Z]'), 'N', '[0-9]'), 'a', '[a-z]')),0	Pattern at Baseline,Threshold Error Count	\N	Fail	CAT	column	Validity	Schema Drift	Expected count of pattern mismatches	This test is appropriate for character fields that are expected to appear in a consistent format. It uses pattern matching syntax as appropriate for your database:  REGEX matching if available, otherwise LIKE expressions. The expected threshold is the number of records that fail to match the defined pattern.	Y
1028	Recency	Recency	Latest date within expected range of test date	Tests that the latest date in column is within a set number of days of the test date	Most recent date value not within expected days of test date.	Days before test	Number of days that most recent date precedes the date of test	general_type= 'D' AND max_date <= run_date AND NOT column_name IN ( 'filedate' , 'file_date' ) AND NOT functional_data_type IN ('Future Date', 'Schedule Date') AND DATEDIFF( 'DAY' , max_date, run_date) <= 62	(ABS({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT*{PRO_RECORD_CT}::FLOAT/(1.0+DATEDIFF('DAY', '{MIN_DATE}', '{MAX_DATE}'))::FLOAT)/{RECORD_CT}::FLOAT	0.75	\N	\N	threshold_value	CASE WHEN DATEDIFF( 'DAY' , max_date, run_date) <= 3 THEN DATEDIFF('DAY', max_date, run_date) + 3 WHEN DATEDIFF('DAY', max_date, run_date) <= 7 then DATEDIFF('DAY', max_date, run_date) + 7 WHEN DATEDIFF( 'DAY' , max_date, run_date) <= 31 THEN CEILING( DATEDIFF( 'DAY' , max_date, run_date)::FLOAT / 7.0) * 7 WHEN DATEDIFF( 'DAY' , max_date, run_date) > 31 THEN CEILING( DATEDIFF( 'DAY' , max_date, run_date)::FLOAT / 30.0) * 30 END	Threshold Maximum Days before Test	\N	Warning	CAT	column	Timeliness	Recency	Expected maximum count of days preceding test date	This test evaluates recency based on the latest referenced dates in the column.  The test is appropriate for transactional dates and timestamps.  The test can be especially valuable because timely data deliveries themselves may not assure that the most recent data is present. You can adjust the expected threshold to the maximum number of days that you expect the data to age before the dataset is refreshed.  	Y
1030	Required	Required Entry	Required non-null value present	Tests that a non-null value is present in each record for the column, consistent with baseline data	Every record for this column is expected to be filled, but some are missing.	Missing values	\N	record_ct = value_ct	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Threshold Missing Value Count	\N	Fail	CAT	column	Completeness	Schema Drift	Expected count of missing values	\N	Y
1033	Street_Addr_Pattern	Street Address	Enough street address entries match defined pattern	Tests for percent of records matching standard street address pattern.	Percent of values matching standard street address format is under expected threshold.	Percent matches	Percent of records that match street address pattern	(std_pattern_match='STREET_ADDR') AND (avg_length <> round(avg_length)) AND (avg_embedded_spaces BETWEEN 2 AND 6) AND (avg_length < 35)	({VALUE_CT}::FLOAT * ({RESULT_MEASURE}::FLOAT - {THRESHOLD_VALUE}::FLOAT)/100.0)/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	75	Threshold Pct that Match Address Pattern	\N	Fail	CAT	column	Validity	Schema Drift	Expected percent of records that match standard street address pattern	The street address pattern used in this test should match the vast majority of USA addresses.  You can adjust the threshold percent of matches based on the results you are getting -- you may well want to tighten it to make the test more sensitive to invalid entries.	Y
1034	Unique	Unique Values	Each column value is unique	Tests that no values for the column are repeated in multiple records.	Column values should be unique per row.	Duplicate values	Count of non-unique values	record_ct > 500 and record_ct = distinct_value_ct and value_ct > 0	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Threshold Duplicate Value Count	\N	Fail	CAT	column	Uniqueness	Schema Drift	Expected count of duplicate values	This test is ideal when the database itself does not enforce a primary key constraint on the table. It serves as an independent check on uniqueness.  If's also useful when there are a small number of exceptions to uniqueness, which can be reflected in the expected threshold count of duplicates.	Y
1035	Unique_Pct	Percent Unique	Consistent ratio of unique values	Tests for statistically-significant shift in percentage of unique values vs. baseline data.	Significant shift in percent of unique values vs. baseline.	Difference measure	Cohen's H Difference (0.20 small, 0.5 mod, 0.8 large, 1.2 very large, 2.0 huge)	distinct_value_ct > 10	LEAST({RESULT_MEASURE}, 1.0)	0.75	\N	\N	baseline_value_ct,baseline_unique_ct,threshold_value	value_ct,distinct_value_ct,0.5	Value Count at Baseline,Distinct Value Count at Baseline,Standardized Difference Measure (0 to 1)	\N	Warning	CAT	column	Uniqueness	Data Drift	Expected maximum Cohen's H Difference	You can think of this as a test of similarity that measures whether the percentage of unique values is consistent with the percentage at baseline.  A significant change might indicate duplication or a telling shift in cardinality between entities. The test uses Cohen's H, a statistical test to identify a significant difference between two ratios.  Results are reported on a standardized scale, which can be interpreted via a rule-of-thumb from small to huge.  You can refine the expected threshold value as you view legitimate results of the measure over time.	Y
1036	US_State	US State	Column value is two-letter US state code	Tests that the recorded column value is a valid US state.	Column Value is not a valid US state.	Not US States	Values that doo not match 2-character US state abbreviations.	general_type= 'A' AND column_name ILIKE '%state%' AND distinct_value_ct < 70 AND max_length = 2	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Threshold Count not Matching State Abbreviations	\N	Fail	CAT	column	Validity	Schema Drift	Expected count of values that are not US state abbreviations	This test validates entries against a fixed list of two-character US state codes and related Armed Forces codes.	Y
1037	Weekly_Rec_Ct	Weekly Records	At least one date per week present within date range	Tests for presence of at least one date per calendar week within min/max date range, per baseline data	At least one date per week expected in min/max date range.	Missing weeks	Calendar weeks without date values present	general_type= 'D' AND date_days_present > 1 AND date_weeks_present > 3 AND date_weeks_present - (DATEDIFF('week', '1800-01-05'::DATE, max_date) - DATEDIFF('week', '1800-01-05'::DATE, min_date) + 1) = 0 AND future_date_ct::FLOAT / NULLIF(value_ct, 0) <= 0.75	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT*{PRO_RECORD_CT}::FLOAT/{DATE_WEEKS_PRESENT}::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value	0	Threshold Weeks without Dates	\N	Fail	CAT	column	Completeness	Volume	Expected maximum count of calendar weeks without dates present	Weekly Records tests that at least one record is present for every calendar week within the minimum and maximum date range for the column. The test is relevant for transactional data, where you would expect at least one transaction to be recorded each week. A failure here would suggest missing records for the number of weeks identified without data. You can adjust the threshold to accept a number of weeks that you know legitimately have no records.	Y
1040	Variability_Increase	Variability Increase	Variability has increased above threshold	Tests that the spread or dispersion of column values has increased significantly over baseline, indicating a drop in stability of the measure.	The Standard Deviation of the measure has increased beyond the defined threshold. This could signal a change in a process or a data quality issue.	Pct SD shift	Percent of baseline Standard Deviation	general_type = 'N' AND functional_data_type ilike 'Measure%' AND column_name NOT ilike '%latitude%' AND column_name NOT ilike '%longitude%' AND value_ct <> distinct_value_ct AND distinct_value_ct > 10 AND stdev_value > 0 AND avg_value IS NOT NULL AND NOT (distinct_value_ct = max_value - min_value + 1 AND distinct_value_ct > 2)	1	0.75	\N	\N	baseline_sd,threshold_value	stdev_value,120	Std Deviation at Baseline,Expected Maximum Percent	\N	Warning	CAT	column	Accuracy	Data Drift	Expected maximum pct of baseline Standard Deviation (SD)	This test looks for percent shifts in standard deviation as a measure of the stability of a measure over time.  A significant change could indicate that new values are erroneous, or that the cohort being evaluated is significantly different from baseline.  An increase in particular could mark new problems in measurement,  a more heterogeneous cohort, or that significant outliers have been introduced. Consider this test along with Average Shift and New Shift.  If the average shifts as well, there may be a fundamental shift in the dataset or process used to collect the data point.  This might suggest a data shift that should be noted and assessed by business users. If the average does not shift, this may point to a data quality or data collection problem. 	Y
1041	Variability_Decrease	Variability Decrease	Variability has decreased below threshold	Tests that the spread or dispersion of column values has decreased significantly over baseline, indicating a shift in stability of the measure. This could signal a change in a process or a data quality issue.	The Standard Deviation of the measure has decreased below the defined threshold. This could signal a change in a process or a data quality issue.	Pct SD shift	Percent of baseline Standard Deviation	general_type = 'N' AND functional_data_type ilike 'Measure%' AND column_name NOT ilike '%latitude%' AND column_name NOT ilike '%longitude%' AND value_ct <> distinct_value_ct AND distinct_value_ct > 10 AND stdev_value > 0 AND avg_value IS NOT NULL AND NOT (distinct_value_ct = max_value - min_value + 1 AND distinct_value_ct > 2)	1	0.75	\N	\N	baseline_sd,threshold_value	stdev_value, 80	Std Deviation at Baseline,Expected Minimum Percent	\N	Warning	CAT	column	Accuracy	Data Drift	Expected minimum pct of baseline Standard Deviation (SD)	This test looks for percent shifts in standard deviation as a measure of the stability of a measure over time.  A significant change could indicate that new values are erroneous, or that the cohort being evaluated is significantly different from baseline.  A decrease in particular could indicate an improved process, better precision in measurement, the elimination of outliers, or a more homogeneous cohort. 	Y
1042	Valid_Month	Valid Month	Valid calendar month in expected format	Tests for the presence of a valid representation of a calendar month consistent with the format at baseline.	Column values are not a valid representation of a calendar month consistent with the format at baseline.	Invalid months	\N	functional_data_type = 'Period Month'	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	\N	\N	threshold_value,baseline_value	0,CASE WHEN max_length > 3 AND initcap(min_text) = min_text THEN '''January'',''February'',''March'',''April'',''May'',''June'',''July'',''August'',''September'',''October'',''November'',''December''' WHEN max_length > 3 AND upper(min_text) = min_text THEN '''JANUARY'',''FEBRUARY'',''MARCH'',''APRIL'',''MAY'',''JUNE'',''JULY'',''AUGUST'',''SEPTEMBER'',''OCTOBER'',''NOVEMBER'',''DECEMBER''' WHEN max_length > 3 AND lower(min_text) = min_text THEN '''january'',''february'',''march'',''april'',''may'',''june'',''july'',''august'',''september'',''october'',''november'',''december''' WHEN max_length = 3 AND initcap(min_text) = min_text THEN '''Jan'',''Feb'',''Mar'',''Apr'',''May'',''Jun'',''Jul'',''Aug'',''Sep'',''Oct'',''Nov'',''Dec''' WHEN max_length = 3 AND upper(min_text) = min_text THEN '''JAN'',''FEB'',''MAR'',''APR'',''MAY'',''JUN'',''JUL'',''AUG'',''SEP'',''OCT'',''NOV'',''DEC''' WHEN max_length = 3 AND lower(min_text) = min_text THEN '''jan'',''feb'',''mar'',''apr'',''may'',''jun'',''jul'',''aug'',''sep'',''oct'',''nov'',''dec''' WHEN max_length = 2 AND min_text = '01' THEN '''01'',''02'',''03'',''04'',''05'',''06'',''07'',''08'',''09'',''10'',''11'',''12''' WHEN max_length = 2 AND min_text = '1' THEN '''1'',''2'',''3'',''4'',''5'',''6'',''7'',''8'',''9'',''10'',''11'',''12''' WHEN min_value = 1 THEN '1,2,3,4,5,6,7,8,9,10,11,12' ELSE 'NULL' END	Threshold Invalid Months,Valid Month List	The acceptable number of records with invalid months present.|List of valid month values for this field, in quotes if field is numeric, separated by commas.	Fail	CAT	column	Validity	Schema Drift	Expected count of invalid months	\N	N
1043	Valid_Characters	Valid Characters	Column contains no invalid characters	Tests for the presence of non-printing characters, leading spaces, or surrounding quotes.	Invalid characters, such as non-printing characters, leading spaces, or surrounding quotes, were found.	Invalid records	Expected count of values with invalid characters	general_type = 'A'	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	0.75	\N	\N	threshold_value	0	\N	The acceptable number of records with invalid character values present.	Warning	CAT	column	Validity	Schema Drift	Threshold Invalid Value Count	This test looks for the presence of non-printing ASCII characters that are considered non-standard in basic text processing. It also identifies leading spaces and values enclosed in quotes. Values that fail this test may be artifacts of data conversion, or just more difficult to process or analyze downstream.	N
1044	Valid_US_Zip	Valid US Zip	Valid USA Postal Codes	Tests that postal codes match the 5 or 9 digit standard US format	Invalid US Zip Code formats found.	Invalid Zip Codes	Expected count of values with invalid Zip Codes	functional_data_type = 'Zip'	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	0.75	\N	\N	threshold_value	0	\N	\N	Warning	CAT	column	Validity	Schema Drift	Threshold Invalid Value Count	\N	Y
1045	Valid_US_Zip3	Valid US Zip-3  	Valid USA Zip-3 Prefix	Tests that postal codes match the 3 digit format of a regional prefix.	Invalid 3-digit US Zip Code regional prefix formats found.	Invalid Zip-3 Prefix	Expected count of values with invalid Zip-3 Prefix Codes	functional_data_type = 'Zip3'	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	0.75	\N	\N	threshold_value	0	\N	\N	Warning	CAT	column	Validity	Schema Drift	Threshold Invalid Zip3 Count	This test looks for the presence of values that fail to match the three-digit numeric code expected for US Zip Code regional prefixes. These prefixes are often used to roll up Zip Code data to a regional level, and may be critical to anonymize detailed data and protect PID. Depending on your needs and regulatory requirements, longer zip codes could place PID at risk.	Y
1006	Condition_Flag	Custom Condition	Column values match pre-defined condition	Tests that each record in the table matches a pre-defined, custom condition	Value(s) found not matching defined condition.	Values Failing	\N	\N	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	Test Focus	Specify a brief descriptor of the focus of this test that is unique within this Test Suite for the Table and Test Type. This distinguishes this test from others of the same type on the same table. Example: `Quantity Consistency` if you are testing that quantity ordered matches quantity shipped.	threshold_value,custom_query	\N	Threshold Error Count,Custom SQL Expression (TRUE on error)	The number of errors that are acceptable before test fails.|Expression should evaluate to TRUE to register an error or FALSE if no error. An expression can reference only columns in the selected table.	Fail	CAT	custom	Validity	Schema Drift	Count of records that don't meet test condition	Custom Condition is a business-rule test for a user-defined error condition based on the value of one or more columns. The condition is applied to each record within the table, and the count of records failing the condition is added up. If that count exceeds a threshold of errors, the test as a whole is failed. This test is ideal for error conditions that TestGen cannot automatically infer, and any condition that involves the values of more than one column in the same record. Performance of this test is fast, since it is performed together with other aggregate tests. Interpretation is based on the user-defined meaning of the test.	Y
1031	Row_Ct	Row Count	Number of rows is at or above threshold	Tests that the count of records has not decreased from the baseline count.	Row count less than baseline count.	Row count	\N	TEMPLATE	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{THRESHOLD_VALUE}::FLOAT	1.0	\N	\N	threshold_value	\N	Threshold Minimum Record Count	\N	Fail	CAT	table	Completeness	Volume	Expected minimum row count	Because this tests the row count against a constant minimum threshold, it's appropriate for any dataset, as long as the number of rows doesn't radically change from refresh to refresh.  But it's not responsive to change over time. You may want to adjust the threshold periodically if you are dealing with a cumulative dataset.	Y
1032	Row_Ct_Pct	Row Range	Number of rows within percent range of threshold	Tests that the count of records is within a percentage above or below the baseline count.	Row Count is outside of threshold percent of baseline count.	Percent of baseline	Row count percent above or below baseline	TEMPLATE	(100.0 - {RESULT_MEASURE}::FLOAT)/100.0	1.0	\N	\N	baseline_ct,threshold_value	\N	Baseline Record Count,Threshold Pct Above or Below Baseline	\N	Fail	CAT	table	Completeness	Volume	Expected percent window below or above baseline	This test is better than Row Count for an incremental or windowed dataset where you would expect the row count to range within a percentage of baseline.	Y
1008	CUSTOM	Custom Test	Custom-defined business rule	Custom SQL Query Test	Errors were detected according to test definition.	Errors found	Count of errors identified by query	\N	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	Test Focus	Specify a brief descriptor of the focus of this test that is unique within this Test Suite for the Table and Test Type. This distinguishes this test from others of the same type on the same table. Example: `Order Total Matches Detail` if you are testing that the total in one table matches the sum of lines in another.	custom_query	\N	Custom SQL Query Returning Error Records	Query should return records indicating one or more errors. The test passes if no records are returned. Results of the query will be shown when you click `Review Source Data` for a failed test, so be sure to include enough data in your results to follow-up. \\n\\nA query can refer to any tables in the database. You must hard-code the schema or use `{DATA_SCHEMA}` to represent the schema defined for the Table Group.	Fail	QUERY	custom	Accuracy	Data Drift	Expected count of errors found by custom query	This business-rule test is highly flexible, covering any error state that can be expressed by a SQL query against one or more tables in the database. In operation, the user-defined query is embedded within a parent query returning the count of error rows identified. Any row returned by the query is interpreted as a single error condition in the test. Note that this query is run independently of other tests, and that performance will be slower, depending in large part on the efficiency of the query you write. Interpretation is based on the user-defined meaning of the test. Your query might be written to return errors in individual rows identified by joining tables. Or it might return an error based on a multi-column aggregate condition returning a single row if an error is found. This query is run separately when you click `Review Source Data` from Test Results, so be sure to include enough data in your results to follow-up. Interpretation is based on the user-defined meaning of the test.	Y
1500	Aggregate_Balance	Aggregate Balance	Aggregate values per group match reference	Tests for exact match in aggregate values for each set of column values vs. reference dataset	Aggregate measure per set of column values does not exactly match reference dataset.	Mismatched measures	\N	\N	1	1.0	Aggregate Expression	Specify an aggregate column expression: one of `SUM([column_name])` or `COUNT([column_name])`	subset_condition,groupby_names,having_condition,match_schema_name,match_table_name,match_column_names,match_subset_condition,match_groupby_names,match_having_condition	\N	Record Subset Condition,Grouping Columns,Group Subset Condition,Matching Schema Name,Matching Table Name,Matching Aggregate Expression,Matching Record Subset Condition,Matching Grouping Columns,Matching Group Subset Condition	Condition defining a subset of records in main table, written like a condition within a SQL WHERE clause - OPTIONAL|Category columns in main table separated by commas (e.g. GROUP BY columns)|Condition defining a subset of aggregate records in main table (e.g. HAVING clause) - OPTIONAL|Schema location of matching table|Matching table name|Agregate column expression in matching table: one of `SUM([column_name])` or `COUNT([column_name])`|Condition defining a subset of records in matching table, written like a condition within a SQL WHERE clause - OPTIONAL|Category columns in matching table separated by commas (e.g. GROUP BY columns)|Condition defining a subset of aggregate records in matching table (e.g. HAVING clause) - OPTIONAL	Fail	QUERY	referential	Consistency	Data Drift	Expected count of group totals not matching aggregate value	This test compares sums or counts of a column rolled up to one or more category combinations across two different tables. Both tables must be accessible at the same time. It's ideal for confirming that two datasets exactly match -- that the sum of a measure or count of a value hasn't changed or shifted between categories. Use this test to compare a raw and processed version of the same dataset, or to confirm that an aggregated table exactly matches the detail table that it's built from. An error here means that one or more value combinations fail to match. New categories or combinations will cause failure.	Y
1501	Aggregate_Minimum	Aggregate Minimum	Aggregate values per group are at or above reference	Tests that aggregate values for each set of column values are at least the same as reference dataset	Aggregate measure per set of column values is not at least the same as reference dataset.	Mismatched measures	\N	\N	1	1.0	Aggregate Expression	Specify an aggregate column expression: one of `SUM([column_name])` or `COUNT([column_name])`	subset_condition,groupby_names,having_condition,match_schema_name,match_table_name,match_column_names,match_subset_condition,match_groupby_names,match_having_condition	\N	Record Subset Condition,Grouping Columns,Group Subset Condition,Matching Schema Name,Matching Table Name,Matching Aggregate Expression,Matching Record Subset Condition,Matching Grouping Columns,Matching Group Subset Condition	Condition defining a subset of records in main table, written like a condition within a SQL WHERE clause - OPTIONAL|Category columns in main table separated by commas (e.g. GROUP BY columns)|Condition defining a subset of aggregate records in main table (e.g. HAVING clause) - OPTIONAL|Schema location of reference table|Reference table name|Aggregate column expression in reference table (e.g. `SUM(sales)`)|Condition defining a subset of records in reference table, written like a condition within a SQL WHERE clause - OPTIONAL|Category columns in reference table separated by commas (e.g. GROUP BY columns)|Condition defining a subset of aggregate records in reference table (e.g. HAVING clause) - OPTIONAL	Fail	QUERY	referential	Accuracy	Data Drift	Expected count of group totals below aggregate value	This test compares sums or counts of a column rolled up to one or more category combinations, but requires a match or increase in the aggregate value, rather than an exact match, across two different tables. Both tables must be accessible at the same time. Use this to confirm that aggregate values have not dropped for any set of categories, even if some values may rise. This test is useful to compare an older and newer version of a cumulative dataset. An error here means that one or more values per category set fail to match or exceed the prior dataset. New categories or combinations are allowed (but can be restricted independently with a Combo_Match test). Both tables must be present to run this test.	Y
1502	Combo_Match	Reference Match	Column values or combinations found in reference	Tests for the presence of one or a set of column values in a reference table	Column value combinations are not found in reference table values.	Missing values	\N	\N	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	Categorical Column List	Specify one or more Categorical columns, separated by commas. \\n\\nDo not use continuous mesurements here. Do not use numeric values unless they represent discrete categories.	subset_condition,having_condition,match_schema_name,match_table_name,match_groupby_names,match_subset_condition,match_having_condition	\N	Record Subset Condition,Group Subset Condition,Reference Schema Name,Reference Table Name,Matching Columns,Matching Record Subset Condition,Matching Group Subset Condition	Condition defining a subset of records in main table to evaluate, written like a condition within a SQL WHERE clause - OPTIONAL|Condition based on aggregate expression used to exclude value combinations in source table, written like a condition within a SQL HAVING clause (e.g. `SUM(sales) < 100`) - OPTIONAL|Schema location of matching table|Matching table name|Column Names in reference table used to validate source table values (separated by commas)|Condition defining a subset of records in reference table to match against, written like a condition within a SQL WHERE clause - OPTIONAL|Condition based on aggregate expression used to exclude value combinations in reference table, written like a condition within a SQL HAVING clause (e.g. `SUM(sales) < 100`) - OPTIONAL	Fail	QUERY	referential	Validity	Schema Drift	Expected count of non-matching value combinations	This test verifies that values, or combinations of values, that are present in the main table are also found in a reference table. This is a useful test for referential integrity between fact and dimension tables. You can also use it to confirm the validity of a code or category, or of combinations of values that should only be found together within each record, such as product/size/color.  An error here means that one  or more category combinations in the main table are not found in the reference table. Both tables must be present to run this test.	Y
1503	Distribution_Shift	Distribution Shift	Probability distribution consistent with reference	Tests the closeness of match between two distributions of aggregate measures across combinations of column values, using Jensen-Shannon Divergence test	Divergence between two distributions exceeds specified threshold.	Divergence level (0-1)	Jensen-Shannon Divergence, from 0 (identical distributions), to 1.0 (max divergence)	\N	1	0.75	Categorical Column List	Specify one or more Categorical columns, separated by commas. Do not use continuous mesurements here. Do not use numeric values unless they represent discrete categories.	subset_condition,match_schema_name,match_table_name,match_groupby_names,match_subset_condition	\N	Record Subset Condition,Reference Schema Name,Reference Table Name,Matching Columns to Compare,Matching Record Subset Condition	Condition defining a subset of records in main table to evaluate, written like a condition within a SQL WHERE clause - OPTIONAL|Schema location of matching table|Matching table name|Column Names in reference table used to compare counts with source table values (separated by commas)|Condition defining a subset of records in reference table to match against, written like a condition within a SQL WHERE clause - OPTIONAL	Warning	QUERY	referential	Consistency	Data Drift	Expected maximum divergence level between 0 and 1	This test measures the similarity of two sets of counts per categories, by using their proportional counts as probability distributions.  Using Jensen-Shannon divergence, a measure of relative entropy or difference between two distributions, the test assigns a score ranging from 0, meaning that the distributions are identical, to 1, meaning that the distributions are completely unrelated. This test can be used to compare datasets that may not match exactly, but should have similar distributions.  For example, it is a useful sanity check for data from different sources that you would expect to have a consistent spread, such as shipment of building materials per state and construction projects by state. Scores can be compared over time even if the distributions are not identical -- a dataset can be expected to maintain a comparable divergence score with a reference dataset over time. Both tables must be present to run this test.	Y
1508	Timeframe_Combo_Gain	Timeframe No Drops	Latest timeframe has at least all value combinations from prior period	Tests that column values in most recent time-window include at least same as prior time window	Column values in most recent time-window don't include all values in prior window.	Mismatched values	\N	\N	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	Categorical Column List	Specify one or more Categorical columns, separated by commas. Make sure not to use continuous measurements here. Do not use numeric values unless they represent discrete categories.	window_date_column,window_days,subset_condition	\N	Date Column for Time Windows,Time Window in Days,Record Subset Condition	The date column used to define the time windows. This must be a DATE or DATETIME type.|Length in days of the time window. The test will compare the most recent period of days to the prior period of the same duration.|Condition defining a subset of records in main table to evaluate, written like a condition within a SQL WHERE clause - OPTIONAL	Fail	QUERY	referential	Consistency	Data Drift	Expected count of missing value combinations	This test checks a single transactional table to verify that categorical values or combinations that are present in the most recent time window you define include at least all those found in the prior time window of the same duration. Missing values in the latest time window will trigger the test to fail. New values are permitted. Use this test to confirm that codes or categories are not lost across successive time periods in a transactional table.	Y
1509	Timeframe_Combo_Match	Timeframe Match	Column value combinations from latest timeframe same as prior period	Tests for presence of same column values in most recent time-window vs. prior time window	Column values don't match in most recent time-windows.	Mismatched values	\N	\N	({RESULT_MEASURE}-{THRESHOLD_VALUE})::FLOAT/{RECORD_CT}::FLOAT	1.0	Categorical Column List	Specify one or more Categorical columns, separated by commas. Do not use continuous measurements here. Do not use numeric values unless they represent discrete categories.	window_date_column,window_days,subset_condition	\N	Date Column for Time Windows,Time Window in Days,Record Subset Condition	\N	Fail	QUERY	referential	Consistency	Data Drift	Expected count of non-matching value combinations	This test checks a single transactional table (such as a fact table) to verify that categorical values or combinations that are present in the most recent time window you define match those found in the prior time window of the same duration. New or missing values in the latest time window will trigger the test to fail. Use this test to confirm the consistency in the occurrence of codes or categories across successive time periods in a transactional table.	Y
1504	Aggregate_Pct_Above	Aggregate Pct Above	Aggregate values per group exceed reference	Tests that aggregate values for each set of column values exceed values for reference dataset	Aggregate measure per set of column values fails to exceed the reference dataset.	Mismatched measures	\N	\N	1	1.0	Aggregate Expression	Specify an aggregate column expression: one of `SUM([column_name])` or `COUNT([column_name])`	subset_condition,groupby_names,having_condition,match_column_names,match_schema_name,match_table_name,match_subset_condition,match_groupby_names,match_having_condition	\N	TODO Fill in default_parm_prompts match_schema_name,TODO Fill in default_parm_prompts match_table_name,TODO Fill in default_parm_prompts match_column_names,TODO Fill in default_parm_prompts match_subset_condition,TODO Fill in default_parm_prompts match_groupby_names,TODO Fill in default_parm_prompts match_having_condition,TODO Fill in default_parm_prompts subset_condition,TODO Fill in default_parm_prompts groupby_names,TODO Fill in default_parm_prompts having_condition	\N	Fail	QUERY	referential	Accuracy	Data Drift	Expected count of group totals with not exceeding aggregate measure	\N	N
1505	Aggregate_Pct_Within	Aggregate Pct Within	Aggregate values per group exceed reference	Tests that aggregate values for each set of column values exceed values for reference dataset	Aggregate measure per set of column values fails to exceed the reference dataset.	Mismatched measures	\N	\N	1	1.0	Aggregate Expression	Specify an aggregate column expression: one of `SUM([column_name])` or `COUNT([column_name])`	subset_condition,groupby_names,having_condition,match_column_names,match_schema_name,match_table_name,match_subset_condition,match_groupby_names,match_having_condition	\N	TODO Fill in default_parm_prompts match_schema_name,TODO Fill in default_parm_prompts match_table_name,TODO Fill in default_parm_prompts match_column_names,TODO Fill in default_parm_prompts match_subset_condition,TODO Fill in default_parm_prompts match_groupby_names,TODO Fill in default_parm_prompts match_having_condition,TODO Fill in default_parm_prompts subset_condition,TODO Fill in default_parm_prompts groupby_names,TODO Fill in default_parm_prompts having_condition	\N	Fail	QUERY	referential	Accuracy	Data Drift	Expected count of group totals with not exceeding aggregate measure	\N	N
1506	Aggregate_Increase	Aggregate Increase	Aggregate values per group exceed reference	Tests that aggregate values for each set of column values exceed values for reference dataset	Aggregate measure per set of column values fails to exceed the reference dataset.	Mismatched measures	\N	\N	1	1.0	Aggregate Expression	Specify an aggregate column expression: one of `SUM([column_name])` or `COUNT([column_name])`	subset_condition,groupby_names,having_condition,match_column_names,match_schema_name,match_table_name,match_subset_condition,match_groupby_names,match_having_condition	\N	TODO Fill in default_parm_prompts match_schema_name,TODO Fill in default_parm_prompts match_table_name,TODO Fill in default_parm_prompts match_column_names,TODO Fill in default_parm_prompts match_subset_condition,TODO Fill in default_parm_prompts match_groupby_names,TODO Fill in default_parm_prompts match_having_condition,TODO Fill in default_parm_prompts subset_condition,TODO Fill in default_parm_prompts groupby_names,TODO Fill in default_parm_prompts having_condition	\N	Fail	QUERY	referential	Accuracy	Data Drift	Expected count of group totals below reference value	\N	N
\.


--
-- Data for Name: tg_revision; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.tg_revision (component, revision) FROM stdin;
metadata_db	115
\.


--
-- Data for Name: variant_codings; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.variant_codings (value_type, check_values) FROM stdin;
measure	meter|m|metre
measure	centimeter|cm|centimetre
measure	millimeter|mm|millimetre
measure	kilometer|km|kilometre
measure	inches|inch|in|"
measure	foot|ft|feet|'
measure	yard|yd
measure	mile|mi|miles
measure	kilogram|kgs|kg
measure	gram|g
measure	milligram|mgs|mg
measure	pound|lb|lbs|pounds
measure	ounce|oz
measure	liter|l|litre|liters|litres
measure	milliliter|ml|millilitre
measure	cubic meter|m^3|m³|cubic metre
measure	cubic centimeter|cm^3|cm³|cubic centimetre
measure	gallon|gal|gallons
measure	quart|qt
measure	pint|pt
measure	cup|cups
measure	percent|pct|%
med_dose	fluid ounce|fl oz|fluid ounces
med_dose	tablet|tab|tabs
med_dose	capsule|cap|caps
med_dose	once daily|daily|qd
med_dose	twice daily|bid
med_dose	three times daily|tid
med_dose	four times daily|qid
med_dose	as needed|prn
med_dose	before meals|ac
med_dose	after meals|pc
med_dose	at bedtime|hs
med_dose	intravenous|iv
med_dose	subcutaneous|sc|sq
med_dose	intramuscular|im
med_dose	oral|po
med_dose	per rectum|pr
med_dose	drops|gtt|gtts
med_tx	treatment|trx|tx
med_tx	new patients|new patient|new pt|nrx
med_tx	patient|pat|pt|px
med_tx	prescription|rx
med_tx	hcp|md|dr
inv_uom	each|ea
inv_uom	piece|pc|pieces|pcs
inv_uom	set|sets
inv_uom	pack|pk|pks
inv_uom	box|bx|boxes
inv_uom	case|cases
inv_uom	bottle|btl|bottles|btls
inv_uom	dozen|dz
inv_uom	pair|pr|pairs
inv_uom	batch|lot|lots
inv_uom	bundle|bundles
inv_uom	units|unit|each|ea
inv_uom	carton|ctn|cartons
inv_uom	case|cs|ca
inv_uom	bag|bg|bags
status	positive|pos|p
status	negative|neg|n
status	complete|completed|comp|cmp|c
status	incomplete|incomp|inc|i
status	active|act|a
status	inactive|inact|in|ia|i
status	enabled|en
status	disabled|dis
status	open|opn|o
status	closed|cls|c
status	terminated|cancellation|cancelled|cancel|canc|cc
status	verified|confirmed|conf|cnf|cf
status	unconfirmed|unconf|ucf
status	not available|unavailable|n/a|na|unknown|unkn|unk|un
status	processed|proc|pr
status	unprocessed|unproc|upr
status	approved|accepted|accept|appr|ap
status	unapproved|unappr|uap
status	rejected|reject|rej|rj|declined
status	received|recv|rcvd|rcv
status	on hold|hold|held|paused|pause
status	not received|nrecv|nrc
status	shipped|dispatched|despatched|filled|sent|shp|s
status	not shipped|nshp|ns|unshipped
status	past due|overdue|late
status	true|yes|y
status	true|yes|t
status	false|no|n
status	false|no|f
status	pending|pend|pnd
status	in process|in progress|active
status	retain|keep
status	remove|drop|delete|del
status	low|lo|l
status	medium|moderate|med|m
status	high|hi|h
status	same|sm
status	average|mean|avg
status	decreased|decrease|decr|down|dn
status	increased|increase|incr|up
status	qualification|qual|q
status	qualified|qual|q
status	failed|fail|f
status	passed|pass|p|success
status	deferred|defer|delayed|delay
status	resolved|fixed|fx
crm	email|eml|em
crm	direct mail|mail|dm
crm	account|acct|act
crm	clinical|clinic|clin|c
crm	hospitals|hospital|hosp|hos
crm	private practice|practice|prac|clinical|clinic
crm	pharmacy|pharm|phar|rx
crm	community|comm|com
crm	academic|educational|ed
crm	government|govt|gov|gvt|federal|fed
demog	male|m
demog	female|f
demog	single|s
demog	married|m
demog	widowed|w
demog	separated|sep
demog	divorced|dvcd|div
demog	partnered|prt
demog	cohabiting|coh
demog	engaged|eng
demog	living|alive|lv
demog	deceased|dead|dec|dcd
demog	retired|ret|rt
demog	employed|emp
demog	unemployed|unemp
demog	student|stu|std|st
demog	child|ch
demog	adult|ad
demog	senior|sr
demog	veteran|vet
demog	homeowner|homeown
demog	renter|rnt
demog	urban|urb
demog	suburban|sub
demog	rural|rur
demog	cellular|cell|mobile|mob
chron	monday|mon|m
chron	tuesday|tue|tu
chron	wednesday|wed|w
chron	thursday|thu|th
chron	friday|fri|f
chron	saturday|sat|sa
chron	sunday|sun|su
chron	january|jan|01
chron	february|feb|02
chron	march|mar|03
chron	april|apr|04
chron	may|05
chron	june|jun|06
chron	july|jul|07
chron	august|aug|08
chron	september|sept|sep|09
chron	october|oct|10
chron	november|nov|11
chron	december|dec|12
chron	week-ending|week|wk|w
chron	month-ending|month-end|month|mo|m
chron	quarter|quarter-ending|quarter-end|qtr|q
chron	year|yr|fy|y
chron	year-to-date|ytd
currency	us dollars|dollars|usd|us|$
currency	euro|eur|€
currency	pound|pounds|gbp|£
currency	yen|jpy|¥
currency	yuan|cny|元
country	united states of america|united states|u.s.a.|u.s.|usa|us
country	united kingdom|great britain|england|britain|uk|gb|gbr
country	canada|ca|can
country	mexico|méxico|mx
country	australia|au|aus
country	germany|de|deu
country	france|fr|fra
country	italy|it|ita
country	japan|jp|jpn
country	china|cn|chn
country	india|in|ind
hr	full-time|ft
hr	part-time|pt
hr	contract|contractor
hr	temporary|temp|tmp
hr	intern|internship
hr	permanent|perm
hr	non-binary|nb
hr	active|employed|working
hr	inactive|unemployed|not working
hr	leave of absence|leave|loa
hr	maternity leave|mat leave|mat
hr	paternity leave|pat leave|pat
hr	sick leave|sick|illness
hr	vacation|vac|pto
hr	remote|work from home|home|wfh
hr	on-site|office based|wfo
hr	resigned|quit|left
hr	terminated|fired
hr	promotion|promoted
hr	transfer|transferred|xfer
hr	performance review|perf review|pr
hr	training|education|ed
hr	salary increase|increase|raise
hr	bonus|bon|incentive|incent
hr	employee referral|referral
hr	exit interview|exit
office	corporate|corp|co
office	headquarters|hq|head office
office	branch office|branch|local office
office	regional office|region office|regional hub|regionalregion
office	sales office|sales|field office
office	distribution center|distribution hub|distribution|dist
office	manufacturing plant|factory|manufacturing facility|manufacturing|mfg
office	research and development|r&d|innovation center
office	customer service center|customer support center|service center
office	logistics center|logistics|shipping center|shipping
office	data center|data hub|it center
office	administrative office|admin office|administration|admin
office	call center|contact center|customer call center
office	warehouse|storage facility|storage|fulfillment center|fulfillment
office	retail store|store|retail outlet|retail
office	outlet store|outlet|clearance center|clearance
office	training center|training facility|learning center
office	legal office|legal department|legal|compliance office|compliance
office	finance department|finance office|accounting|finance
office	human resources|hr
office	marketing department|marketing|mktg|sales and marketing|s&m
office	operations center|operations|ops center|ops
office	executive office|executive suite|c-suite
finance	fiscal year|fy
finance	forecast|fcast|fore|for
finance	actuals|actual|act
finance	estimated|estimates|estimate|est
finance	credit|cred|cr|c
finance	debit|deb|db|d
cust_service	new inquiry|ni|new question|nq|new ticket
cust_service	open ticket|ot|unresolved|ur
cust_service	pending review|pr|awaiting response|ar
cust_service	resolved|res|closed|cl
cust_service	escalated|esc|high priority|hp
cust_service	customer feedback|cf|feedback|fb
cust_service	complaint|comp|issue reported|ir
cust_service	refund request|rr|refund required|rf
cust_service	exchange request|er|exchange required|exr
cust_service	return initiated|ri|return started|rs
cust_service	follow-up required|follow-up needed|follow-up|follow up|f/u|fu
cust_service	customer satisfaction|csat|satisfaction level|sl
cust_service	service level agreement|sla|sla compliance|slac
cust_service	first response time|frt|initial response time|irt
cust_service	average handle time|aht|average resolution time|art
cust_service	customer retention|cr|retention rate|rr
cust_service	customer churn|churn rate|churn|ch
cust_service	net promoter score|nps|promoter score|ps
cust_service	case reopened|cr|reopened ticket|rt
cust_service	technical support|ts|tech help|th
cust_service	billing inquiry|bi|billing question|bq
cust_service	product inquiry|pi|product question|pq
cust_service	service feedback|sf|service review|sr
cust_service	live chat|instant messaging|im
cust_service	imessage|text message|text|sms
cust_service	email support|es|email inquiry|ei
cust_service	phone support|ps|call center|cc
cust_service	social media support|sms|social inquiry|social|si
cust_service	self-service|help center|ss
cust_service	knowledge base|kb|faq|frequently asked questions
cust_service	ticket closed without action|tcwa|closed no action|cna
pharma	phase 1|phase i
pharma	phase 2|phase ii
pharma	phase 3|phase iii|late phase
pharma	phase 4|phase iv|post-marketing surveillance
pharma	clinical trial|clinical study|research|trial
pharma	preclinical|pre-clinical|non-clinical studies
pharma	in vitro studies|ivs|laboratory studies|lab studies
pharma	in vivo studies|animal studies|animal model studies
pharma	regulatory submission|rs|submission to regulatory
pharma	regulatory approval|ra|approved by regulatory|approval|approved
pharma	marketed|commercialized|launched
pharma	under review|review by regulatory
pharma	rejected by regulatory|regulatory rejection|rejected
pharma	drug discovery|dd|early research
pharma	formulation development|fd|drug formulation
pharma	toxicology studies|tox studies|toxicological assessment|toxo
pharma	bioavailability study|ba study|absorption study
pharma	bioequivalence study|be study|equivalence study
pharma	pharmacokinetics|pk|pharmacokinetic studies
pharma	pharmacodynamics|pd|pharmacodynamic studies
pharma	clinical development plan|cdp|development strategy
pharma	investigational new drug|ind|ind application
pharma	new drug application|nda|drug registration
pharma	biologics license application|bla|biologics application
pharma	orphan drug designation|odd|orphan status|orphan drug
pharma	breakthrough therapy designation|btd|expedited development
pharma	fast track designation|ftd|accelerated review
pharma	priority review|pr|priority assessment
pharma	tentative approval|ta|conditional approval
pharma	off-label use|off-label|olu|unapproved use|unapproved
\.


--
-- Data for Name: working_agg_cat_results; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.working_agg_cat_results (test_run_id, schema_name, table_name, cat_sequence, measure_results, test_results) FROM stdin;
\.


--
-- Data for Name: working_agg_cat_tests; Type: TABLE DATA; Schema: testgen; Owner: admin
--

COPY testgen.working_agg_cat_tests (test_run_id, schema_name, table_name, cat_sequence, test_count, test_time, start_time, end_time, column_names, test_types, test_definition_ids, test_actions, test_descriptions, test_parms, test_measures, test_conditions) FROM stdin;
\.


--
-- Name: connections_connection_id_seq; Type: SEQUENCE SET; Schema: testgen; Owner: admin
--

SELECT pg_catalog.setval('testgen.connections_connection_id_seq', 1, true);


--
-- Name: profile_results_dk_id_seq; Type: SEQUENCE SET; Schema: testgen; Owner: admin
--

SELECT pg_catalog.setval('testgen.profile_results_dk_id_seq', 1, false);


--
-- Name: profile_results_dk_id_seq1; Type: SEQUENCE SET; Schema: testgen; Owner: admin
--

SELECT pg_catalog.setval('testgen.profile_results_dk_id_seq1', 1, false);


--
-- Name: test_definitions_cat_test_id_seq; Type: SEQUENCE SET; Schema: testgen; Owner: admin
--

SELECT pg_catalog.setval('testgen.test_definitions_cat_test_id_seq', 1, false);


--
-- Name: test_definitions_cat_test_id_seq1; Type: SEQUENCE SET; Schema: testgen; Owner: admin
--

SELECT pg_catalog.setval('testgen.test_definitions_cat_test_id_seq1', 1, false);


--
-- Name: test_results_result_id_seq; Type: SEQUENCE SET; Schema: testgen; Owner: admin
--

SELECT pg_catalog.setval('testgen.test_results_result_id_seq', 1, false);


--
-- Name: cat_test_conditions cat_test_conditions_test_type_sql_flavor_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.cat_test_conditions
    ADD CONSTRAINT cat_test_conditions_test_type_sql_flavor_pk PRIMARY KEY (test_type, sql_flavor);


--
-- Name: test_types cat_tests_test_type_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_types
    ADD CONSTRAINT cat_tests_test_type_pk PRIMARY KEY (test_type);


--
-- Name: connections connections_connection_id_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.connections
    ADD CONSTRAINT connections_connection_id_pk PRIMARY KEY (connection_id);


--
-- Name: generation_sets generation_sets_gen_set_test_type_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.generation_sets
    ADD CONSTRAINT generation_sets_gen_set_test_type_pk PRIMARY KEY (generation_set, test_type);


--
-- Name: profile_anomaly_results pk_anomaly_results_id; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.profile_anomaly_results
    ADD CONSTRAINT pk_anomaly_results_id PRIMARY KEY (id);


--
-- Name: profile_anomaly_types pk_anomaly_types_id; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.profile_anomaly_types
    ADD CONSTRAINT pk_anomaly_types_id PRIMARY KEY (id);


--
-- Name: profile_pair_rules pk_profile_pair_rules_id; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.profile_pair_rules
    ADD CONSTRAINT pk_profile_pair_rules_id PRIMARY KEY (id);


--
-- Name: profiling_runs pk_prun_id; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.profiling_runs
    ADD CONSTRAINT pk_prun_id PRIMARY KEY (id);


--
-- Name: profile_results profile_results_id_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.profile_results
    ADD CONSTRAINT profile_results_id_pk PRIMARY KEY (id);


--
-- Name: projects projects_project_code_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.projects
    ADD CONSTRAINT projects_project_code_pk PRIMARY KEY (project_code);


--
-- Name: test_definitions test_definitions_cat_test_id_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_definitions
    ADD CONSTRAINT test_definitions_cat_test_id_pk PRIMARY KEY (cat_test_id);


--
-- Name: test_runs test_runs_id_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_runs
    ADD CONSTRAINT test_runs_id_pk PRIMARY KEY (id);


--
-- Name: test_suites test_suites_id_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_suites
    ADD CONSTRAINT test_suites_id_pk PRIMARY KEY (id);


--
-- Name: test_templates test_templates_test_type_sql_flavor_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_templates
    ADD CONSTRAINT test_templates_test_type_sql_flavor_pk PRIMARY KEY (test_type, sql_flavor);


--
-- Name: tg_revision tg_revision_component_pk; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.tg_revision
    ADD CONSTRAINT tg_revision_component_pk PRIMARY KEY (component);


--
-- Name: auth_users unique_username; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.auth_users
    ADD CONSTRAINT unique_username UNIQUE (username);


--
-- Name: working_agg_cat_results working_agg_cat_results_tri_sn_tn_cs; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.working_agg_cat_results
    ADD CONSTRAINT working_agg_cat_results_tri_sn_tn_cs PRIMARY KEY (test_run_id, schema_name, table_name, cat_sequence);


--
-- Name: working_agg_cat_tests working_agg_cat_tests_trid_sn_tn_cs; Type: CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.working_agg_cat_tests
    ADD CONSTRAINT working_agg_cat_tests_trid_sn_tn_cs PRIMARY KEY (test_run_id, schema_name, table_name, cat_sequence);


--
-- Name: cix_tr_pc_ts; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX cix_tr_pc_ts ON testgen.test_results USING btree (test_suite_id) WHERE ((observability_status)::text = 'Queued'::text);


--
-- Name: ix_ares_anid; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_ares_anid ON testgen.profile_anomaly_results USING btree (anomaly_id);


--
-- Name: ix_ares_prun; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_ares_prun ON testgen.profile_anomaly_results USING btree (profile_run_id);


--
-- Name: ix_pr_pc_con; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_pr_pc_con ON testgen.profile_results USING btree (project_code, connection_id);


--
-- Name: ix_pr_prun; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_pr_prun ON testgen.profile_results USING btree (profile_run_id);


--
-- Name: ix_pro_pair_prun; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_pro_pair_prun ON testgen.profile_pair_rules USING btree (profile_run_id);


--
-- Name: ix_prun_pc_con; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_prun_pc_con ON testgen.profiling_runs USING btree (project_code, connection_id);


--
-- Name: ix_prun_tg; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_prun_tg ON testgen.profiling_runs USING btree (table_groups_id);


--
-- Name: ix_td_pc_stc_tst; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_td_pc_stc_tst ON testgen.test_definitions USING btree (test_suite_id, schema_name, table_name, column_name, test_type);


--
-- Name: ix_td_tg; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_td_tg ON testgen.test_definitions USING btree (table_groups_id);


--
-- Name: ix_td_ts_fk; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_td_ts_fk ON testgen.test_definitions USING btree (test_suite_id);


--
-- Name: ix_td_ts_tc; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_td_ts_tc ON testgen.test_definitions USING btree (test_suite_id, table_name, column_name, test_type);


--
-- Name: ix_tg_cid; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_tg_cid ON testgen.table_groups USING btree (connection_id);


--
-- Name: ix_tr_pc_sctc_tt; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_tr_pc_sctc_tt ON testgen.test_results USING btree (test_suite_id, schema_name, table_name, column_names, test_type);


--
-- Name: ix_tr_pc_ts; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_tr_pc_ts ON testgen.test_results USING btree (test_suite_id);


--
-- Name: ix_tr_trun; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_tr_trun ON testgen.test_results USING btree (test_run_id);


--
-- Name: ix_tr_ts_tctt; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_tr_ts_tctt ON testgen.test_results USING btree (test_suite_id, table_name, column_names, test_type);


--
-- Name: ix_tr_tt; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_tr_tt ON testgen.test_results USING btree (test_type);


--
-- Name: ix_trun_pc_ts_time; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_trun_pc_ts_time ON testgen.test_runs USING btree (test_suite_id, test_starttime);


--
-- Name: ix_trun_time; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_trun_time ON testgen.test_runs USING brin (test_starttime);


--
-- Name: ix_trun_ts_fk; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_trun_ts_fk ON testgen.test_runs USING btree (test_suite_id);


--
-- Name: ix_ts_con; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX ix_ts_con ON testgen.test_suites USING btree (connection_id);


--
-- Name: profile_results_tgid_sn_tn_cn; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX profile_results_tgid_sn_tn_cn ON testgen.profile_results USING btree (table_groups_id, schema_name, table_name, column_name);


--
-- Name: table_groups_name_unique; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX table_groups_name_unique ON testgen.table_groups USING btree (project_code, table_groups_name);


--
-- Name: uix_con_id; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_con_id ON testgen.connections USING btree (id);


--
-- Name: uix_pat_at; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_pat_at ON testgen.profile_anomaly_types USING btree (anomaly_type);


--
-- Name: uix_pr_tg_t_c_prun; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_pr_tg_t_c_prun ON testgen.profile_results USING btree (table_groups_id, table_name, column_name, profile_run_id);


--
-- Name: uix_td_id; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_td_id ON testgen.test_definitions USING btree (id);


--
-- Name: uix_tg_id; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_tg_id ON testgen.table_groups USING btree (id);


--
-- Name: uix_tr_id; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_tr_id ON testgen.test_results USING btree (id);


--
-- Name: uix_ts_id; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE UNIQUE INDEX uix_ts_id ON testgen.test_suites USING btree (id);


--
-- Name: working_agg_cat_tests_test_run_id_index; Type: INDEX; Schema: testgen; Owner: admin
--

CREATE INDEX working_agg_cat_tests_test_run_id_index ON testgen.working_agg_cat_tests USING btree (test_run_id);


--
-- Name: v_profiling_runs _RETURN; Type: RULE; Schema: testgen; Owner: admin
--

CREATE OR REPLACE VIEW testgen.v_profiling_runs AS
 SELECT r.id AS profiling_run_id,
    r.project_code,
    cc.connection_name,
    r.connection_id,
    r.table_groups_id,
    tg.table_groups_name,
    tg.table_group_schema AS schema_name,
    r.profiling_starttime AS start_time,
    to_char((r.profiling_endtime - r.profiling_starttime), 'HH24:MI:SS'::text) AS duration,
    r.status,
    r.log_message,
    r.table_ct,
    r.column_ct,
    r.anomaly_ct,
    r.anomaly_table_ct,
    r.anomaly_column_ct,
    r.process_id
   FROM ((testgen.profiling_runs r
     JOIN testgen.table_groups tg ON ((r.table_groups_id = tg.id)))
     JOIN testgen.connections cc ON ((r.connection_id = cc.connection_id)))
  GROUP BY r.id, r.project_code, cc.connection_name, r.connection_id, r.table_groups_id, tg.table_groups_name, tg.table_group_schema, r.profiling_starttime, r.profiling_endtime, r.status;


--
-- Name: cat_test_conditions cat_test_conditions_cat_tests_test_type_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.cat_test_conditions
    ADD CONSTRAINT cat_test_conditions_cat_tests_test_type_fk FOREIGN KEY (test_type) REFERENCES testgen.test_types(test_type);


--
-- Name: connections connections_projects_project_code_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.connections
    ADD CONSTRAINT connections_projects_project_code_fk FOREIGN KEY (project_code) REFERENCES testgen.projects(project_code);


--
-- Name: profile_results profile_results_connections_connection_id_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.profile_results
    ADD CONSTRAINT profile_results_connections_connection_id_fk FOREIGN KEY (connection_id) REFERENCES testgen.connections(connection_id);


--
-- Name: table_groups table_groups_connections_connection_id_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.table_groups
    ADD CONSTRAINT table_groups_connections_connection_id_fk FOREIGN KEY (connection_id) REFERENCES testgen.connections(connection_id);


--
-- Name: table_groups table_groups_projects_project_code_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.table_groups
    ADD CONSTRAINT table_groups_projects_project_code_fk FOREIGN KEY (project_code) REFERENCES testgen.projects(project_code);


--
-- Name: test_definitions test_definitions_test_suites_test_suite_id_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_definitions
    ADD CONSTRAINT test_definitions_test_suites_test_suite_id_fk FOREIGN KEY (test_suite_id) REFERENCES testgen.test_suites(id);


--
-- Name: test_results test_results_test_suites_project_code_test_suite_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_results
    ADD CONSTRAINT test_results_test_suites_project_code_test_suite_fk FOREIGN KEY (test_suite_id) REFERENCES testgen.test_suites(id);


--
-- Name: test_results test_results_test_types_test_type_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_results
    ADD CONSTRAINT test_results_test_types_test_type_fk FOREIGN KEY (test_type) REFERENCES testgen.test_types(test_type);


--
-- Name: test_runs test_runs_test_suites_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_runs
    ADD CONSTRAINT test_runs_test_suites_fk FOREIGN KEY (test_suite_id) REFERENCES testgen.test_suites(id);


--
-- Name: test_suites test_suites_connections_connection_id_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_suites
    ADD CONSTRAINT test_suites_connections_connection_id_fk FOREIGN KEY (connection_id) REFERENCES testgen.connections(connection_id);


--
-- Name: test_templates test_templates_test_types_test_type_fk; Type: FK CONSTRAINT; Schema: testgen; Owner: admin
--

ALTER TABLE ONLY testgen.test_templates
    ADD CONSTRAINT test_templates_test_types_test_type_fk FOREIGN KEY (test_type) REFERENCES testgen.test_types(test_type);


--
-- Name: SCHEMA testgen; Type: ACL; Schema: -; Owner: admin
--

GRANT USAGE ON SCHEMA testgen TO testgen_execute_role;
GRANT USAGE ON SCHEMA testgen TO testgen_report_role;


--
-- Name: FUNCTION datediff(difftype character varying, firstdate timestamp without time zone, seconddate timestamp without time zone); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.datediff(difftype character varying, firstdate timestamp without time zone, seconddate timestamp without time zone) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.datediff(difftype character varying, firstdate timestamp without time zone, seconddate timestamp without time zone) TO testgen_report_role;


--
-- Name: FUNCTION fn_charcount(instring character varying, searchstring character varying); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_charcount(instring character varying, searchstring character varying) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_charcount(instring character varying, searchstring character varying) TO testgen_report_role;


--
-- Name: FUNCTION fn_count_intersecting_items(list1 character varying, list2 character varying, separator character varying); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_count_intersecting_items(list1 character varying, list2 character varying, separator character varying) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_count_intersecting_items(list1 character varying, list2 character varying, separator character varying) TO testgen_report_role;


--
-- Name: FUNCTION fn_eval(expression text); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_eval(expression text) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_eval(expression text) TO testgen_report_role;


--
-- Name: FUNCTION fn_extract_distinct_items(list character varying, separator character varying); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_extract_distinct_items(list character varying, separator character varying) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_extract_distinct_items(list character varying, separator character varying) TO testgen_report_role;


--
-- Name: FUNCTION fn_extract_intersecting_items(list1 character varying, list2 character varying, separator character varying); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_extract_intersecting_items(list1 character varying, list2 character varying, separator character varying) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_extract_intersecting_items(list1 character varying, list2 character varying, separator character varying) TO testgen_report_role;


--
-- Name: FUNCTION fn_extract_top_values(input_string text); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_extract_top_values(input_string text) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_extract_top_values(input_string text) TO testgen_report_role;


--
-- Name: FUNCTION fn_format_csv_no_quotes(str_csv text); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_format_csv_no_quotes(str_csv text) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_format_csv_no_quotes(str_csv text) TO testgen_report_role;


--
-- Name: FUNCTION fn_format_csv_quotes(str_csv text); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_format_csv_quotes(str_csv text) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_format_csv_quotes(str_csv text) TO testgen_report_role;


--
-- Name: FUNCTION fn_normal_cdf(z_score double precision); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_normal_cdf(z_score double precision) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_normal_cdf(z_score double precision) TO testgen_report_role;


--
-- Name: FUNCTION fn_parsefreq(top_freq_values character varying, rowno integer, colno integer); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_parsefreq(top_freq_values character varying, rowno integer, colno integer) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_parsefreq(top_freq_values character varying, rowno integer, colno integer) TO testgen_report_role;


--
-- Name: FUNCTION fn_pct(numerator numeric, denominator numeric, decs integer); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_pct(numerator numeric, denominator numeric, decs integer) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_pct(numerator numeric, denominator numeric, decs integer) TO testgen_report_role;


--
-- Name: FUNCTION fn_prepcolumnname(value_to_check text); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_prepcolumnname(value_to_check text) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_prepcolumnname(value_to_check text) TO testgen_report_role;


--
-- Name: FUNCTION fn_quote_literal_escape(var_value character varying, sql_flavor character varying); Type: ACL; Schema: testgen; Owner: admin
--

GRANT ALL ON FUNCTION testgen.fn_quote_literal_escape(var_value character varying, sql_flavor character varying) TO testgen_execute_role;
GRANT ALL ON FUNCTION testgen.fn_quote_literal_escape(var_value character varying, sql_flavor character varying) TO testgen_report_role;


--
-- Name: TABLE auth_users; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.auth_users TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.auth_users TO testgen_report_role;


--
-- Name: TABLE cat_test_conditions; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.cat_test_conditions TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.cat_test_conditions TO testgen_report_role;


--
-- Name: TABLE connections; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.connections TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.connections TO testgen_report_role;


--
-- Name: SEQUENCE connections_connection_id_seq; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,USAGE ON SEQUENCE testgen.connections_connection_id_seq TO testgen_execute_role;
GRANT SELECT,USAGE ON SEQUENCE testgen.connections_connection_id_seq TO testgen_report_role;


--
-- Name: TABLE data_column_chars; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.data_column_chars TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.data_column_chars TO testgen_report_role;


--
-- Name: TABLE data_structure_log; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.data_structure_log TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.data_structure_log TO testgen_report_role;


--
-- Name: TABLE data_table_chars; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.data_table_chars TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.data_table_chars TO testgen_report_role;


--
-- Name: TABLE functional_test_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.functional_test_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.functional_test_results TO testgen_report_role;


--
-- Name: TABLE generation_sets; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.generation_sets TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.generation_sets TO testgen_report_role;


--
-- Name: TABLE profile_anomaly_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.profile_anomaly_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.profile_anomaly_results TO testgen_report_role;


--
-- Name: TABLE profile_anomaly_types; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.profile_anomaly_types TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.profile_anomaly_types TO testgen_report_role;


--
-- Name: TABLE profile_pair_rules; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.profile_pair_rules TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.profile_pair_rules TO testgen_report_role;


--
-- Name: TABLE profile_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.profile_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.profile_results TO testgen_report_role;


--
-- Name: SEQUENCE profile_results_dk_id_seq; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,USAGE ON SEQUENCE testgen.profile_results_dk_id_seq TO testgen_execute_role;
GRANT SELECT,USAGE ON SEQUENCE testgen.profile_results_dk_id_seq TO testgen_report_role;


--
-- Name: SEQUENCE profile_results_dk_id_seq1; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,USAGE ON SEQUENCE testgen.profile_results_dk_id_seq1 TO testgen_execute_role;
GRANT SELECT,USAGE ON SEQUENCE testgen.profile_results_dk_id_seq1 TO testgen_report_role;


--
-- Name: TABLE profiling_runs; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.profiling_runs TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.profiling_runs TO testgen_report_role;


--
-- Name: TABLE projects; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.projects TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.projects TO testgen_report_role;


--
-- Name: TABLE stg_functional_table_updates; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.stg_functional_table_updates TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.stg_functional_table_updates TO testgen_report_role;


--
-- Name: TABLE stg_secondary_profile_updates; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.stg_secondary_profile_updates TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.stg_secondary_profile_updates TO testgen_report_role;


--
-- Name: TABLE table_groups; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.table_groups TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.table_groups TO testgen_report_role;


--
-- Name: TABLE target_data_lookups; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.target_data_lookups TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.target_data_lookups TO testgen_report_role;


--
-- Name: TABLE test_definitions; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.test_definitions TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.test_definitions TO testgen_report_role;


--
-- Name: SEQUENCE test_definitions_cat_test_id_seq; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,USAGE ON SEQUENCE testgen.test_definitions_cat_test_id_seq TO testgen_execute_role;
GRANT SELECT,USAGE ON SEQUENCE testgen.test_definitions_cat_test_id_seq TO testgen_report_role;


--
-- Name: SEQUENCE test_definitions_cat_test_id_seq1; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,USAGE ON SEQUENCE testgen.test_definitions_cat_test_id_seq1 TO testgen_execute_role;
GRANT SELECT,USAGE ON SEQUENCE testgen.test_definitions_cat_test_id_seq1 TO testgen_report_role;


--
-- Name: TABLE test_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.test_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.test_results TO testgen_report_role;


--
-- Name: SEQUENCE test_results_result_id_seq; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,USAGE ON SEQUENCE testgen.test_results_result_id_seq TO testgen_execute_role;
GRANT SELECT,USAGE ON SEQUENCE testgen.test_results_result_id_seq TO testgen_report_role;


--
-- Name: TABLE test_runs; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.test_runs TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.test_runs TO testgen_report_role;


--
-- Name: TABLE test_suites; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.test_suites TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.test_suites TO testgen_report_role;


--
-- Name: TABLE test_templates; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.test_templates TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.test_templates TO testgen_report_role;


--
-- Name: TABLE test_types; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.test_types TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.test_types TO testgen_report_role;


--
-- Name: TABLE tg_revision; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.tg_revision TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.tg_revision TO testgen_report_role;


--
-- Name: TABLE v_inactive_anomalies; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_inactive_anomalies TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_inactive_anomalies TO testgen_report_role;


--
-- Name: TABLE v_latest_profile_anomalies; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_latest_profile_anomalies TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_latest_profile_anomalies TO testgen_report_role;


--
-- Name: TABLE v_latest_profile_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_latest_profile_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_latest_profile_results TO testgen_report_role;


--
-- Name: TABLE v_profiling_runs; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_profiling_runs TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_profiling_runs TO testgen_report_role;


--
-- Name: TABLE v_queued_observability_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_queued_observability_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_queued_observability_results TO testgen_report_role;


--
-- Name: TABLE v_test_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_test_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_test_results TO testgen_report_role;


--
-- Name: TABLE v_test_runs; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.v_test_runs TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.v_test_runs TO testgen_report_role;


--
-- Name: TABLE variant_codings; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT ON TABLE testgen.variant_codings TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.variant_codings TO testgen_report_role;


--
-- Name: TABLE working_agg_cat_results; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.working_agg_cat_results TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.working_agg_cat_results TO testgen_report_role;


--
-- Name: TABLE working_agg_cat_tests; Type: ACL; Schema: testgen; Owner: admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE testgen.working_agg_cat_tests TO testgen_execute_role;
GRANT SELECT ON TABLE testgen.working_agg_cat_tests TO testgen_report_role;


--
-- PostgreSQL database dump complete
--

