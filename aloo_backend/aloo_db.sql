--
-- PostgreSQL database dump
--

\restrict EryLJvArreXO5aS9e8ZKmPsCKPecpeC55w42Oq1EgUADFA5o1vtt7oj6AXsNB4L

-- Dumped from database version 18.1 (Debian 18.1-1)
-- Dumped by pg_dump version 18.1 (Debian 18.1-1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: aloo_user
--

CREATE TABLE public.clients (
    id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    email character varying(120) NOT NULL,
    phone character varying(20) NOT NULL,
    password character varying(255) NOT NULL,
    address character varying(255) NOT NULL,
    created_at timestamp without time zone
);


ALTER TABLE public.clients OWNER TO aloo_user;

--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: aloo_user
--

CREATE SEQUENCE public.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.clients_id_seq OWNER TO aloo_user;

--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: aloo_user
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: providers; Type: TABLE; Schema: public; Owner: aloo_user
--

CREATE TABLE public.providers (
    id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    email character varying(120) NOT NULL,
    phone character varying(20) NOT NULL,
    password character varying(255) NOT NULL,
    category character varying(100) NOT NULL,
    city character varying(100) NOT NULL,
    address character varying(255) NOT NULL,
    bio text NOT NULL,
    created_at timestamp without time zone
);


ALTER TABLE public.providers OWNER TO aloo_user;

--
-- Name: providers_id_seq; Type: SEQUENCE; Schema: public; Owner: aloo_user
--

CREATE SEQUENCE public.providers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.providers_id_seq OWNER TO aloo_user;

--
-- Name: providers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: aloo_user
--

ALTER SEQUENCE public.providers_id_seq OWNED BY public.providers.id;


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: aloo_user
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: providers id; Type: DEFAULT; Schema: public; Owner: aloo_user
--

ALTER TABLE ONLY public.providers ALTER COLUMN id SET DEFAULT nextval('public.providers_id_seq'::regclass);


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: aloo_user
--

COPY public.clients (id, full_name, email, phone, password, address, created_at) FROM stdin;
1	John Doe	john@gmail.com	21345678	$2b$12$y4SQMwko0GuoyyWG8oc4k.ld.O4XBSGmzYVyfllnpKjyudikKf7y.	12 rue matar	2026-03-05 10:52:40.058863
2	roua	rouachaker@gmail.com	27181355	$2b$12$HIIgnjjIifYxhnYnO2tYLulSQjaq/9UGK9fUC4xeIORIjeBw..6FS	tunisie	2026-03-05 11:05:23.459712
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: public; Owner: aloo_user
--

COPY public.providers (id, full_name, email, phone, password, category, city, address, bio, created_at) FROM stdin;
1	ali ben salem	ali@gmail.com	55123456	$2b$12$MxcEgHo8PDpBlNtrAd.M/O3txMVX8jGZoLatHD4nmYgMvs.Ugq/s.	Plombier	tunis	45 ariana	5 ans 5ebra	2026-03-05 10:56:39.362641
2	ahmed gheriani trabelsi	ahmed@gmail.com	12345678	$2b$12$QtTAKjIihVaip.t58R6ni.hBsC.tz07RZrMZfMj2VbP9jvtMkOMaS	Plombier	hay hbib	hay hbiib	tafffar + 5 ans experience	2026-03-05 12:28:25.9792
\.


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: aloo_user
--

SELECT pg_catalog.setval('public.clients_id_seq', 2, true);


--
-- Name: providers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: aloo_user
--

SELECT pg_catalog.setval('public.providers_id_seq', 2, true);


--
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: public; Owner: aloo_user
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: aloo_user
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: providers providers_email_key; Type: CONSTRAINT; Schema: public; Owner: aloo_user
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT providers_email_key UNIQUE (email);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: public; Owner: aloo_user
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO aloo_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO aloo_user;


--
-- PostgreSQL database dump complete
--

\unrestrict EryLJvArreXO5aS9e8ZKmPsCKPecpeC55w42Oq1EgUADFA5o1vtt7oj6AXsNB4L

