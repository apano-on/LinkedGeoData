/****************************************************************************
 *                                                                          *
 * Helper Views to be used with Sparqlify                                   *
 *     (https://github.com/AKSW/Sparqlify)                                  *
 *                                                                          *
 ****************************************************************************/

-- DROP VIEW IF EXISTS lgd_mapped_k;
-- CREATE VIEW lgd_mapped_k AS
--   SELECT b.k FROM lgd_map_datatype b UNION ALL
--   SELECT c.k FROM lgd_map_resource_k UNION ALL
--   SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v) UNION ALL
--   SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k UNION ALL
--   SELECT f.k FROM lgd_map_property f WHERE f.k = a.k UNION ALL
--   SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k;



/****************************************************************************
 * nodes                                                                    *
 ****************************************************************************/

/* This view is an extension point and can be replaced with ones for better geometries */
DROP VIEW IF EXISTS lgd_nodes_geometry;
CREATE VIEW lgd_nodes_geometry AS
  SELECT id, geom
   FROM nodes;


DROP VIEW IF EXISTS lgd_node_tags_boolean;
CREATE VIEW lgd_node_tags_boolean AS
  SELECT a.node_id, b.property, lgd_tryparse_boolean(a.v) AS v
   FROM node_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_boolean(a.v) IS NOT NULL AND b.datatype = 'boolean'::lgd_datatype;


DROP VIEW IF EXISTS lgd_node_tags_int;
CREATE VIEW lgd_node_tags_int AS
  SELECT a.node_id, b.property, lgd_tryparse_int(a.v) AS v
   FROM node_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_int(a.v) IS NOT NULL AND b.datatype = 'int'::lgd_datatype;


DROP VIEW IF EXISTS lgd_node_tags_float;
CREATE VIEW lgd_node_tags_float AS
  SELECT a.node_id, b.property, lgd_tryparse_float(a.v) AS v
   FROM node_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_float(a.v) IS NOT NULL AND b.datatype = 'float'::lgd_datatype;


DROP VIEW IF EXISTS lgd_node_tags_uri;
CREATE VIEW lgd_node_tags_uri AS
  SELECT a.node_id, b.property, lgd_tryparse_uri(a.v) AS v
   FROM node_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_uri(a.v) IS NOT NULL AND b.datatype = 'uri'::lgd_datatype;


/*
CREATE OR REPLACE VIEW lgd_node_tags_string AS
    SELECT a.node_id, a.k, a.v FROM node_tags a WHERE
        NOT EXISTS (
            SELECT b.k FROM lgd_map_datatype  b WHERE b.k = a.k UNION ALL
            SELECT c.k FROM lgd_map_resource_k  c WHERE c.k = a.k UNION ALL
            SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v) UNION ALL
            SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k UNION ALL
            SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k);
*/

/**
 * Everything that is neither mapped to a datatype nor to a class/object property
 * becomes a data property
 */
-- This view seems to work ALOT better than the one above - 7 seconds vs 6min after vacuum full analyze ~Claus 2018-04-23;)
DROP VIEW IF EXISTS lgd_node_tags_string;
CREATE VIEW lgd_node_tags_string AS
    SELECT a.node_id, a.k, a.v FROM node_tags a WHERE
        NOT EXISTS (SELECT b.k FROM lgd_map_datatype b WHERE b.k = a.k) AND
        NOT EXISTS (SELECT c.k FROM lgd_map_resource_k  c WHERE c.k = a.k) AND
        NOT EXISTS (SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v)) AND
        NOT EXISTS (SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k) AND
        NOT EXISTS (SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k);



DROP VIEW IF EXISTS lgd_node_tags_text;
CREATE VIEW lgd_node_tags_text AS
 SELECT a.node_id, b.property, a.v, b.language
   FROM node_tags a
   JOIN lgd_map_literal b ON b.k = a.k;


/*
DROP VIEW IF EXISTS lgd_node_node_tags_text;
CREATE VIEW lgd_node_node_tags_text AS
 SELECT a.node_id, b.property, a.v, b.language
   FROM lgd_node_node_tags_string a
   JOIN lgd_map_literal b ON b.k = a.k;
*/


/*
-- Gives worse plans than the version below
DROP VIEW IF EXISTS lgd_node_tags_resource_k;
CREATE VIEW lgd_node_tags_resource_k AS
 SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN lgd_map_resource_k b ON (b.k = a.k)
 WHERE
  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);
*/
DROP VIEW IF EXISTS lgd_node_tags_resource_k;
CREATE VIEW lgd_node_tags_resource_k AS
 SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN lgd_map_resource_k b ON (b.k = a.k);
-- WHERE
--  b.k NOT IN (SELECT c.k FROM lgd_map_datatype c);


/*
-- Gives worse plans than the version below
DROP VIEW IF EXISTS lgd_node_tags_resource_kv;
CREATE VIEW lgd_node_tags_resource_kv AS
  SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
 WHERE
  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);
*/

-- This views seems to give better plans than that above
DROP VIEW IF EXISTS lgd_node_tags_resource_kv;
CREATE VIEW lgd_node_tags_resource_kv AS
  SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v);
-- WHERE
--  b.k NOT IN (SELECT c.k FROM lgd_map_datatype c);

-- This provides better Ontop performance for superclasses
DROP VIEW IF EXISTS lgd_node_tags_resource_all;
CREATE VIEW lgd_node_tags_resource_all AS
  SELECT node_id, "object"
  FROM
   ((SELECT a.node_id, b.property, b.object "object"
      FROM node_tags a
      JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
      WHERE b.property = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
    )
    UNION ALL
    (SELECT a.node_id, c.property, c.object "object"
      FROM node_tags a
      JOIN lgd_map_resource_k c ON a.k=c.k
    )) q0;

-- A default mapping is applied if the (k) is in resource_kd, but (k, v) is not in resource_kv
DROP VIEW IF EXISTS lgd_node_tags_resource_kd;
CREATE VIEW lgd_node_tags_resource_kd AS
 SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN lgd_map_resource_kd b ON (b.k = a.k)
 WHERE
  NOT EXISTS (SELECT c.k, c.v FROM lgd_map_resource_kv c WHERE c.k = a.k AND c.v = a.v);


/*
DROP VIEW IF EXISTS lgd_node_tags_resource_kv;
CREATE VIEW lgd_node_tags_resource_kv AS
  SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN (SELECT k FROM lgd_map_resource_kv WHERE k NOT IN (SELECT k FROM lgd_map_datatype c)) b ON (b.k, b.v) = (a.k, a.v);

DROP VIEW IF EXISTS lgd_node_tags_resource_kv;
CREATE VIEW lgd_node_tags_resource_kv AS
  SELECT a.node_id, b.property, b.object
   FROM node_tags a
   JOIN lgd_map_resource_kv b ON (b.v = a.v)
WHERE
    b.k = a.k;
*/

/* TODO Resolve above */



DROP VIEW IF EXISTS lgd_node_tags_resource_prefix;
CREATE VIEW lgd_node_tags_resource_prefix AS
  SELECT a.node_id, b.property, b.object_prefix, a.v, b.post_processing
   FROM node_tags a
   JOIN lgd_map_resource_prefix b ON (b.k = a.k);
-- WHERE
--  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = b.k);



-- VALIDATE There should not be an overlap between resource_k and lgd_node_tags_property

/****************************************************************************
 * ways                                                                     *
 ****************************************************************************/

/* This view is an extension point and can be replaced with ones for better geometries */
DROP VIEW IF EXISTS lgd_ways_geometry;
CREATE VIEW lgd_ways_geometry AS
  SELECT id, linestring AS geom
   FROM ways;

DROP VIEW IF EXISTS lgd_way_tags_boolean;
CREATE VIEW lgd_way_tags_boolean AS
  SELECT a.way_id, b.property, lgd_tryparse_boolean(a.v) AS v
   FROM way_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_boolean(a.v) IS NOT NULL AND b.datatype = 'boolean'::lgd_datatype;


DROP VIEW IF EXISTS lgd_way_tags_int;
CREATE VIEW lgd_way_tags_int AS
  SELECT a.way_id, b.property, lgd_tryparse_int(a.v) AS v
   FROM way_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_int(a.v) IS NOT NULL AND b.datatype = 'int'::lgd_datatype;


DROP VIEW IF EXISTS lgd_way_tags_float;
CREATE VIEW lgd_way_tags_float AS
  SELECT a.way_id, b.property, lgd_tryparse_float(a.v) AS v
   FROM way_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_float(a.v) IS NOT NULL AND b.datatype = 'float'::lgd_datatype;


DROP VIEW IF EXISTS lgd_way_tags_uri;
CREATE VIEW lgd_way_tags_uri AS
  SELECT a.way_id, b.property, lgd_tryparse_uri(a.v) AS v
   FROM way_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_uri(a.v) IS NOT NULL AND b.datatype = 'uri'::lgd_datatype;


/**
 * Everything that is neither mapped to a datatype nor to a class/object property
 * becomes a datatype property
 */
DROP VIEW IF EXISTS lgd_way_tags_string;
CREATE VIEW lgd_way_tags_string AS
    SELECT a.way_id, a.k, a.v FROM way_tags a WHERE
        NOT EXISTS (SELECT b.k FROM lgd_map_datatype  b WHERE b.k = a.k) AND
        NOT EXISTS (SELECT c.k FROM lgd_map_resource_k  c WHERE c.k = a.k) AND
        NOT EXISTS (SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v)) AND
        NOT EXISTS (SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k) AND
        NOT EXISTS (SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k);

--CREATE OR REPLACE VIEW lgd_way_tags_string AS
--    SELECT a.way_id, a.k, a.v FROM way_tags a WHERE
--        NOT EXISTS (
--            SELECT b.k FROM lgd_map_datatype  b WHERE b.k = a.k UNION ALL
--            SELECT c.k FROM lgd_map_resource_k  c WHERE c.k = a.k UNION ALL
--            SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v) UNION ALL
--            SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k UNION ALL
--            SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k);


DROP VIEW IF EXISTS lgd_way_tags_text;
CREATE VIEW lgd_way_tags_text AS
 SELECT a.way_id, b.property, a.v, b.language
   FROM way_tags a
   JOIN lgd_map_literal b ON b.k = a.k;


/*
DROP VIEW IF EXISTS lgd_way_way_tags_text;
CREATE VIEW lgd_way_way_tags_text AS
 SELECT a.way_id, b.property, a.v, b.language
   FROM lgd_way_way_tags_string a
   JOIN lgd_map_literal b ON b.k = a.k;
*/

/*
Gives worse plans than the version below
DROP VIEW IF EXISTS lgd_way_tags_resource_k;
CREATE VIEW lgd_way_tags_resource_k AS
 SELECT a.way_id, b.property, b.object
   FROM way_tags a
   JOIN lgd_map_resource_k b ON (b.k = a.k)
 WHERE
  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);
*/

DROP VIEW IF EXISTS lgd_way_tags_resource_k;
CREATE VIEW lgd_way_tags_resource_k AS
 SELECT a.way_id, b.property, b.object
   FROM way_tags a
   JOIN lgd_map_resource_k b ON (b.k = a.k)
;
-- WHERE
--  b.k NOT IN (SELECT c.k FROM lgd_map_datatype c);

/*
Gives worse plans than the version below
DROP VIEW IF EXISTS lgd_way_tags_resource_kv;
CREATE VIEW lgd_way_tags_resource_kv AS
  SELECT a.way_id, b.property, b.object
   FROM way_tags a
   JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
 WHERE
  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);
*/

DROP VIEW IF EXISTS lgd_way_tags_resource_kv;
CREATE VIEW lgd_way_tags_resource_kv AS
  SELECT a.way_id, b.property, b.object
   FROM way_tags a
   JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
;
-- WHERE
--  b.k NOT IN (SELECT c.k FROM lgd_map_datatype c);

-- This provides better Ontop performance for superclasses
DROP VIEW IF EXISTS lgd_way_tags_resource_all;
CREATE VIEW lgd_way_tags_resource_all AS
  SELECT way_id, "object"
  FROM
   ((SELECT a.way_id, b.property, b.object "object"
      FROM way_tags a
      JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
      WHERE b.property = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
    )
    UNION ALL
    (SELECT a.way_id, c.property, c.object "object"
      FROM way_tags a
      JOIN lgd_map_resource_k c ON a.k=c.k
    )) q0;

DROP VIEW IF EXISTS lgd_way_tags_resource_kd;
CREATE VIEW lgd_way_tags_resource_kd AS
 SELECT a.way_id, b.property, b.object
   FROM way_tags a
   JOIN lgd_map_resource_kd b ON (b.k = a.k)
 WHERE
  NOT EXISTS (SELECT c.k, c.v FROM lgd_map_resource_kv c WHERE c.k = a.k AND c.v = a.v);



DROP VIEW IF EXISTS lgd_way_tags_resource_prefix;
CREATE VIEW lgd_way_tags_resource_prefix AS
  SELECT a.way_id, b.property, b.object_prefix, a.v, b.post_processing
   FROM way_tags a
   JOIN lgd_map_resource_prefix b ON (b.k = a.k);
-- WHERE
--  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);


/*
CREATE OR REPLACE VIEW lgd_way_tags_property AS
  SELECT a.way_id, b.property, a.v "object"
   FROM way_tags a, lgd_map_property b
 WHERE
  b.k = a.k AND
  NOT EXISTS (
    SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k UNION ALL
    SELECT e.k FROM lgd_map_resource_kv e WHERE e.k = a.k UNION ALL
    SELECT f.k FROM lgd_map_literal f WHERE f.k = a.k UNION ALL
    SELECT h.k FROM lgd_map_resource_prefix h WHERE h.k = a.k);
*/

/****************************************************************************
 * relations                                                                *
 ****************************************************************************/
--DROP VIEW IF EXISTS lgd_relations_geometry;
--CREATE VIEW lgd_relations_geometry AS
--  SELECT NULL::bigint AS id, NULL::geometry AS geom WHERE false;


DROP VIEW IF EXISTS lgd_relation_tags_boolean;
CREATE VIEW lgd_relation_tags_boolean AS
  SELECT a.relation_id, b.property, lgd_tryparse_boolean(a.v) AS v
   FROM relation_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_boolean(a.v) IS NOT NULL AND b.datatype = 'boolean'::lgd_datatype;


DROP VIEW IF EXISTS lgd_relation_tags_int;
CREATE VIEW lgd_relation_tags_int AS
  SELECT a.relation_id, b.property, lgd_tryparse_int(a.v) AS v
   FROM relation_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_int(a.v) IS NOT NULL AND b.datatype = 'int'::lgd_datatype;


DROP VIEW IF EXISTS lgd_relation_tags_float;
CREATE VIEW lgd_relation_tags_float AS
  SELECT a.relation_id, b.property, lgd_tryparse_float(a.v) AS v
   FROM relation_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_float(a.v) IS NOT NULL AND b.datatype = 'float'::lgd_datatype;


DROP VIEW IF EXISTS lgd_relation_tags_uri;
CREATE VIEW lgd_relation_tags_uri AS
  SELECT a.relation_id, b.property, lgd_tryparse_uri(a.v) AS v
   FROM relation_tags a
   JOIN lgd_map_datatype b ON a.k = b.k
  WHERE lgd_tryparse_uri(a.v) IS NOT NULL AND b.datatype = 'uri'::lgd_datatype;


/**
 * Everything that is neither mapped to a datatype nor to a class/object property
 * becomes a datatype property
 */
DROP VIEW IF EXISTS lgd_relation_tags_string;
CREATE VIEW lgd_relation_tags_string AS
    SELECT a.relation_id, a.k, a.v FROM relation_tags a WHERE
        NOT EXISTS (SELECT b.k FROM lgd_map_datatype  b WHERE b.k = a.k) AND
        NOT EXISTS (SELECT c.k FROM lgd_map_resource_k  c WHERE c.k = a.k) AND
        NOT EXISTS (SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v)) AND
        NOT EXISTS (SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k) AND
        NOT EXISTS (SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k);


/*
CREATE OR REPLACE VIEW lgd_relation_tags_string AS
    SELECT a.relation_id, a.k, a.v FROM relation_tags a WHERE
        NOT EXISTS (
            SELECT b.k FROM lgd_map_datatype  b WHERE b.k = a.k UNION ALL
            SELECT c.k FROM lgd_map_resource_k  c WHERE c.k = a.k UNION ALL
            SELECT d.k FROM lgd_map_resource_kv d WHERE (d.k, d.v) = (a.k, a.v) UNION ALL
            SELECT e.k FROM lgd_map_literal e WHERE e.k = a.k UNION ALL
            SELECT g.k FROM lgd_map_resource_prefix g WHERE g.k = a.k);
*/

DROP VIEW IF EXISTS lgd_relation_tags_text;
CREATE VIEW lgd_relation_tags_text AS
 SELECT a.relation_id, b.property, a.v, b.language
   FROM relation_tags a
   JOIN lgd_map_literal b ON b.k = a.k;


/*
DROP VIEW IF EXISTS lgd_relation_relation_tags_text;
CREATE VIEW lgd_relation_relation_tags_text AS
 SELECT a.relation_id, b.property, a.v, b.language
   FROM lgd_relation_relation_tags_string a
   JOIN lgd_map_literal b ON b.k = a.k;
*/

/*
Gives worse plans than the verison below
DROP VIEW IF EXISTS lgd_relation_tags_resource_k;
CREATE VIEW lgd_relation_tags_resource_k AS
 SELECT a.relation_id, b.property, b.object
   FROM relation_tags a
   JOIN lgd_map_resource_k b ON (b.k = a.k)
 WHERE
  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);
*/

DROP VIEW IF EXISTS lgd_relation_tags_resource_k;
CREATE VIEW lgd_relation_tags_resource_k AS
 SELECT a.relation_id, b.property, b.object
   FROM relation_tags a
   JOIN lgd_map_resource_k b ON (b.k = a.k)
;
-- WHERE
--  b.k NOT IN (SELECT c.k FROM lgd_map_datatype c);


/*
Gives worse plans than the verison below
DROP VIEW IF EXISTS lgd_relation_tags_resource_kv;
CREATE VIEW lgd_relation_tags_resource_kv AS
  SELECT a.relation_id, b.property, b.object
   FROM relation_tags a
   JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
 WHERE
  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = a.k);
*/

DROP VIEW IF EXISTS lgd_relation_tags_resource_kv;
CREATE VIEW lgd_relation_tags_resource_kv AS
  SELECT a.relation_id, b.property, b.object
   FROM relation_tags a
   JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v);
-- WHERE
--  b.k NOT IN (SELECT c.k FROM lgd_map_datatype c);

-- This provides better Ontop performance for superclasses
DROP VIEW IF EXISTS lgd_relation_tags_resource_all;
CREATE VIEW lgd_relation_tags_resource_all AS
  SELECT node_id, "object"
  FROM
   ((SELECT a.relation_id, b.property, b.object "object"
      FROM relation_tags a
      JOIN lgd_map_resource_kv b ON (b.k, b.v) = (a.k, a.v)
      WHERE b.property = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
    )
    UNION ALL
    (SELECT a.relation_id, c.property, c.object "object"
      FROM relation_tags a
      JOIN lgd_map_resource_k c ON a.k=c.k
    )) q0;

DROP VIEW IF EXISTS lgd_relation_tags_resource_kd;
CREATE VIEW lgd_relation_tags_resource_kd AS
 SELECT a.relation_id, b.property, b.object
   FROM relation_tags a
   JOIN lgd_map_resource_kd b ON (b.k = a.k)
 WHERE
  NOT EXISTS (SELECT c.k, c.v FROM lgd_map_resource_kv c WHERE c.k = a.k AND c.v = a.v);


DROP VIEW IF EXISTS lgd_relation_tags_resource_prefix;
CREATE VIEW lgd_relation_tags_resource_prefix AS
  SELECT a.relation_id, b.property, b.object_prefix, a.v, b.post_processing
   FROM relation_tags a
   JOIN lgd_map_resource_prefix b ON (b.k = a.k);
-- WHERE
--  NOT EXISTS (SELECT c.k FROM lgd_map_datatype c WHERE c.k = b.k);


DROP VIEW IF EXISTS lgd_node_tags_text_wide;
CREATE VIEW lgd_node_tags_text_wide AS
  SELECT node_id,
       MAX(v) FILTER (WHERE language = '') AS "rdfs:label",
  	   MAX(v) FILTER (WHERE language = 'en') AS "rdfs:label@en",
  	   MAX(v) FILTER (WHERE language = 'ja') AS "rdfs:label@ja",
       MAX(v) FILTER (WHERE language = 'fr') AS "rdfs:label@fr",
  	   MAX(v) FILTER (WHERE language = 'korm') AS "rdfs:label@korm",
  	   MAX(v) FILTER (WHERE language = 'ar') AS "rdfs:label@ar",
  	   MAX(v) FILTER (WHERE language = 'de') AS "rdfs:label@de",
  	   MAX(v) FILTER (WHERE language = 'ru') AS "rdfs:label@ru",
  	   MAX(v) FILTER (WHERE language = 'sv') AS "rdfs:label@sv",
  	   MAX(v) FILTER (WHERE language = 'botanical') AS "rdfs:label_botanical",
  	   MAX(v) FILTER (WHERE language = 'zh') AS "rdfs:label@zh",
  	   MAX(v) FILTER (WHERE language = 'fi') AS "rdfs:label@fi",
  	   MAX(v) FILTER (WHERE language = 'be') AS "rdfs:label@be",
  	   MAX(v) FILTER (WHERE language = 'ka') AS "rdfs:label@ka",
  	   MAX(v) FILTER (WHERE language = 'fi') AS "rdfs:label@ko",
  	   MAX(v) FILTER (WHERE language = 'be') AS "rdfs:label@he",
  	   MAX(v) FILTER (WHERE language = 'ka') AS "rdfs:label@nl",
  	   MAX(v) FILTER (WHERE language = 'ga') AS "rdfs:label@ga",
  	   MAX(v) FILTER (WHERE language = 'jarm') AS "rdfs:label@jarm",
  	   MAX(v) FILTER (WHERE language = 'el') AS "rdfs:label@el",
  	   MAX(v) FILTER (WHERE language = 'it') AS "rdfs:label@it",
  	   MAX(v) FILTER (WHERE language = 'es') AS "rdfs:label@es",
  	   MAX(v) FILTER (WHERE language = 'zhpinyin') AS "rdfs:label@zhpinyin",
  	   MAX(v) FILTER (WHERE language = 'th') AS "rdfs:label@th",
  	   MAX(v) FILTER (WHERE language = 'sr') AS "rdfs:label@sr",
  	   MAX(v) FILTER (WHERE language = 'py') AS "rdfs:label@py",
  	   MAX(v) FILTER (WHERE language = 'uk') AS "rdfs:label@uk",
  	   MAX(v) FILTER (WHERE language = 'ca') AS "rdfs:label@ca",
  	   MAX(v) FILTER (WHERE language = 'hu') AS "rdfs:label@hu",
  	   MAX(v) FILTER (WHERE language = 'hsb') AS "rdfs:label@hsb",
  	   MAX(v) FILTER (WHERE language = 'fa') AS "rdfs:label@fa",
  	   MAX(v) FILTER (WHERE language = 'eu') AS "rdfs:label@eu",
  	   MAX(v) FILTER (WHERE language = 'br') AS "rdfs:label@br",
  	   MAX(v) FILTER (WHERE language = 'pl') AS "rdfs:label@pl",
  	   MAX(v) FILTER (WHERE language = 'hy') AS "rdfs:label@hy",
  	   MAX(v) FILTER (WHERE language = 'kn') AS "rdfs:label@kn",
  	   MAX(v) FILTER (WHERE language = 'sl') AS "rdfs:label@sl",
  	   MAX(v) FILTER (WHERE language = 'ro') AS "rdfs:label@ro",
  	   MAX(v) FILTER (WHERE language = 'sq') AS "rdfs:label@sq",
  	   MAX(v) FILTER (WHERE language = 'am') AS "rdfs:label@am",
  	   MAX(v) FILTER (WHERE language = 'fy') AS "rdfs:label@fy",
  	   MAX(v) FILTER (WHERE language = 'cs') AS "rdfs:label@cs",
  	   MAX(v) FILTER (WHERE language = 'gd') AS "rdfs:label@gd",
  	   MAX(v) FILTER (WHERE language = 'sk') AS "rdfs:label@sk",
  	   MAX(v) FILTER (WHERE language = 'af') AS "rdfs:label@af",
  	   MAX(v) FILTER (WHERE language = 'lb') AS "rdfs:label@lb",
  	   MAX(v) FILTER (WHERE language = 'jakana') AS "rdfs:label@jakana",
  	   MAX(v) FILTER (WHERE language = 'pt') AS "rdfs:label@pt",
  	   MAX(v) FILTER (WHERE language = 'hr') AS "rdfs:label@hr",
  	   MAX(v) FILTER (WHERE language = 'vi') AS "rdfs:label@vi",
  	   MAX(v) FILTER (WHERE language = 'tr') AS "rdfs:label@tr",
  	   MAX(v) FILTER (WHERE language = 'fur') AS "rdfs:label@fur",
  	   MAX(v) FILTER (WHERE language = 'bg') AS "rdfs:label@bg",
  	   MAX(v) FILTER (WHERE language = 'eo') AS "rdfs:label@eo",
  	   MAX(v) FILTER (WHERE language = 'lt') AS "rdfs:label@lt",
  	   MAX(v) FILTER (WHERE language = 'la') AS "rdfs:label@la",
  	   MAX(v) FILTER (WHERE language = 'kk') AS "rdfs:label@kk",
  	   MAX(v) FILTER (WHERE language = 'gsw') AS "rdfs:label@gsw",
  	   MAX(v) FILTER (WHERE language = 'et') AS "rdfs:label@et",
  	   MAX(v) FILTER (WHERE language = 'mn') AS "rdfs:label@mn",
  	   MAX(v) FILTER (WHERE language = 'ku') AS "rdfs:label@ku",
  	   MAX(v) FILTER (WHERE language = 'mk') AS "rdfs:label@mk",
  	   MAX(v) FILTER (WHERE language = 'lv') AS "rdfs:label@lv",
  	   MAX(v) FILTER (WHERE language = 'carnaval') AS "rdfs:label_carnaval",
  	   MAX(v) FILTER (WHERE language = 'hi') AS "rdfs:label@hi",
  	   MAX(v) FILTER (WHERE language = 'no') AS "rdfs:label@no",
  	   MAX(v) FILTER (WHERE language = 'gl') AS "rdfs:label@gl",
  	   MAX(v) FILTER (WHERE language = 'cv') AS "rdfs:label@cv",
  	   MAX(v) FILTER (WHERE language = 'is') AS "rdfs:label@is",
  	   MAX(v) FILTER (WHERE language = 'cf') AS "rdf:slabel@cf",
  	   MAX(v) FILTER (WHERE language = 'mdf') AS "rdfs:label@mdf",
  	   MAX(v) FILTER (WHERE language = 'yv') AS "rdfs:label@yv",
  	   MAX(v) FILTER (WHERE language = 'da') AS "rdfs:label@da",
  	   MAX(v) FILTER (WHERE language = 'ast') AS "rdfs:label@ast",
  	   MAX(v) FILTER (WHERE language = 'az') AS "rdfs:label@az",
  	   MAX(v) FILTER (WHERE language = 'gv') AS "rdfs:label@gv",
  	   MAX(v) FILTER (WHERE language = 'ba') AS "rdfs:label@ba",
  	   MAX(v) FILTER (WHERE language = 'scn') AS "rdfs:label@scn",
  	   MAX(v) FILTER (WHERE language = 'dsb') AS "rdfs:label@dsb",
  	   MAX(v) FILTER (WHERE language = 'ur') AS "rdfs:label@ur",
  	   MAX(v) FILTER (WHERE language = 'oc') AS "rdfs:label@oc",
  	   MAX(v) FILTER (WHERE language = 'tt') AS "rdfs:label@tt",
  	   MAX(v) FILTER (WHERE language = 'zhpy') AS "rdfs:label@zhpy",
  	   MAX(v) FILTER (WHERE language = 'tg') AS "rdfs:label@tg",
  	   MAX(v) FILTER (WHERE language = 'tg') AS "rdfs:label@tg",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/addr/postcode') AS "addr/postcode",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/openingHours') AS "openingHours",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/operator') AS "operator",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/covered') AS "covered",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/access') AS "access",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/rawCapacity') AS "rawCapacity",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/fee') AS "fee",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/bicycleParking') AS "bicycleParking",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/cycleStreetIds') AS "cycleStreetIds",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/maxStay') AS "maxStay",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/surveillance') AS "surveillance",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/castleType') AS "castleType",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/postalCode') AS "postalCode",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/postCode') AS "postCode",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/officialName') AS "officialName",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/internationalName') AS "internationalName",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/nationalName') AS "nationalName",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/regionalName') AS "regionalName",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/historicalName') AS "historicalName",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/placeNumbers') AS "placeNumbers",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/isIn') AS "isIn",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/note') AS "note",
  	   MAX(v) FILTER (WHERE property = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#comment') AS "comment",
  	   MAX(v) FILTER (WHERE property = 'http://xmlns.com/foaf/0.1/phone') AS "phone",
  	   MAX(v) FILTER (WHERE property = 'http://xmlns.com/foaf/0.1/fax') AS "fax",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/createdBy') AS "createdBy",
  	   MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ontology/attribution') AS "attribution"
  FROM public.lgd_node_tags_text
  GROUP BY node_id;


DROP VIEW IF EXISTS lgd_node_tags_int_wide;
CREATE VIEW lgd_node_tags_int_wide AS
SELECT node_id,
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity') AS "capacity",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/undefined') AS "undefined",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/tables') AS "tables",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/cables') AS "cables",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/ref-fgkz') AS "ref-fgkz",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/minispeed') AS "minispeed",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/game-patrizier2-tuch') AS "game-patrizier2-tuch",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/uicRef') AS "uicRef",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/familySpaces') AS "familySpaces",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/openGeoDB-locId') AS "openGeoDB-locId",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/stepCount') AS "stepCount",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/game-patrizier2-bier') AS "game-patrizier2-bier",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/gauge') AS "gauge",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/StrVz') AS "StrVz",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/lanes') AS "lanes",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/game-patrizier2-ziegel') AS "game-patrizier2-ziegel",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/asb') AS "asb",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/erected') AS "erected",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/onkz') AS "onkz",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/VzG') AS "VzG",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/seats') AS "seats",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/tracks') AS "tracks",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/openGeoDB-layer') AS "openGeoDB-layer",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/game-patrizier2-eisenwaren') AS "game-patrizier2-eisenwaren",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/stars') AS "stars",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/blz') AS "blz",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/maxwidth') AS "maxwidth",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/adminLevel') AS "adminLevel",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/build') AS "build",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/waterway-lock-height') AS "waterway-lock-height",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/maxspeed') AS "maxspeed",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/maxlength') AS "maxlength",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/openGeoDB-population') AS "openGeoDB-population",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/population') AS "population",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/TMC-cid58-tabcd1-prevlocationcode') AS "TMC-cid58-tabcd1-prevlocationcode",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/TMC-cid58-tabcd1-locationcode') AS "TMC-cid58-tabcd1-locationcode",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/produced') AS "produced",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/de-amtlicherGemeindeschluessel') AS "de-amtlicherGemeindeschluessel",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/openGeoDB-isInLocId') AS "openGeoDB-isInLocId",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/openGeoDB-telephoneAreaCode') AS "openGeoDB-telephoneAreaCode",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/openGeoDB-communityIdentificationNumber') AS "openGeoDB-communityIdentificationNumber",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-disabled') AS "capacity-disabled",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-women') AS "capacity-women",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-parent') AS "capacity-parent",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-charging') AS "capacity-charging",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-hgv') AS "capacity-hgv",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-bus') AS "capacity-bus",
	MAX(v) FILTER (WHERE property = 'http://linkedgeodata.org/capacity-car') AS "capacity-car"
FROM public.lgd_node_tags_int
GROUP BY node_id;







