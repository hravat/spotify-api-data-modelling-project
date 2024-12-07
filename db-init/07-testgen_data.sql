--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2 (Debian 17.2-1.pgdg120+1)
-- Dumped by pg_dump version 17.2 (Debian 17.2-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: auth_users; Type: TABLE DATA; Schema: testgen; Owner: admin
--

\c datakitchen;

--TRUNCATE TABLE testgen.profile_results;
TRUNCATE TABLE testgen.connections CASCADE; 
INSERT INTO testgen.connections OVERRIDING SYSTEM VALUE VALUES ('912a3143-dc4a-4a5e-921a-22f06e1606a2', 'DEFAULT', 1, 'postgresql', 'postgres_db', '5432', 'spotify_user', 'postgres', 'default', '\x4177412b6c3838454b4c394f7270346d636e76384d5473644a42334435376e785a556c3069594154456134534b63754e7133324745507135302b34594c6d5a32', 4, 5000, '', false, false, NULL, NULL);

TRUNCATE TABLE testgen.table_groups; 
INSERT INTO testgen.table_groups VALUES ('0ea85e17-acbe-47fe-8394-9970725ad37d', 'DEFAULT', 1, 'default', 'demo', NULL, '%', 'tmp%', '%id', '%_sk', 'N', '30', 15000, '0', 'N', 95, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO testgen.table_groups VALUES ('461ceda1-7c03-42d8-b77b-7c8c6c79b252', 'DEFAULT', 1, 'All Tables', 'spotify_api_prod', NULL, '', '', '', '', 'N', '30', 15000, '0', 'N', 95, '', '', '', '', '', '', '', NULL, NULL, NULL);

