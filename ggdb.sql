/*
 * A database for diagramming workflow
 */

create or replace language plpgsql;

DROP SCHEMA IF EXISTS ggdb CASCADE;
CREATE SCHEMA ggdb; 

/*
 * Represents workflow with only one unique name
 */
CREATE TABLE ggdb.workflow (
	id 	SERIAL PRIMARY KEY,
	name	varchar(64) UNIQUE NOT NULL,
	info	text
);

/*
 * Represents different node types
 */	
CREATE DOMAIN ggdb.nodetype char(1)
   check (value in (
		'A',    --Activity node
		'F', 	--Fork node
		'J',  	--Joiner node
		'S',	--Starting node
		'E'	--Ending node
		   )
         );

/*
 * Represents a node
 */
CREATE TABLE ggdb.node (
	id 		SERIAL PRIMARY KEY,
	workflow_id 	int references ggdb.workflow(id) on delete no action,
	shortname	varchar(3) check (shortname ~ '^[abcdefghijklmnopqrstuvwxyz]+$') NOT NULL,  
			--3 character maximum, lowercase only, no spaces, not unique
	name		varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz ]+$') NOT NULL,  
			--lowercase or uppercase, space allowed, same name in multiple workflows allowed
	nodetype	ggdb.nodetype
);

/*
 * Represents a link between nodes
 */
CREATE TABLE ggdb.link (
	fromnode_id	int references ggdb.node(id) on delete no action,
	tonode_id	int references ggdb.node(id) on delete no action,
	guardlabel	varchar(64),
	PRIMARY KEY (fromnode_id, tonode_id)
);

/*
 * Function links node to starting node for that workflow
 */
CREATE OR REPLACE FUNCTION ggdb.link_from_start (
		p_workflowname varchar(64)
	        , p_nodeshortname char(3)
		, p_guardlabel varchar(64) 
)
RETURNS VOID AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	SELECT ggdb.workflow.id INTO workflowid FROM ggdb.workflow WHERE ggdb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app: workflow >%< not found', p_workflowname;
	END IF;

	IF p_nodeshortname NOT IN (select ggdb.node.shortname from ggdb.node where ggdb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< not found', p_nodeshortname;
	END IF;

	insert into ggdb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(select ggdb.node.id from ggdb.node where ggdb.node.workflow_id = workflowid and ggdb.node.nodetype = 'S')
		, (select ggdb.node.id from ggdb.node where ggdb.node.workflow_id = workflowid and ggdb.node.shortname = p_nodeshortname)
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function links node to ending node for that workflow
 */
CREATE OR REPLACE FUNCTION ggdb.link_to_finish (
		p_workflowname varchar(64)
	        , p_nodeshortname char(3)
		, p_guardlabel varchar(64) 
)
RETURNS VOID AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	SELECT ggdb.workflow.id INTO workflowid FROM ggdb.workflow WHERE ggdb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app: workflow >%< not found', p_workflowname;
	END IF;

	IF p_nodeshortname NOT IN (select ggdb.node.shortname from ggdb.node where ggdb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< not found', p_nodeshortname;
	END IF;

	insert into ggdb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(select ggdb.node.id from ggdb.node where ggdb.node.workflow_id = workflowid and ggdb.node.shortname = p_nodeshortname)
		, (select ggdb.node.id from ggdb.node where ggdb.node.workflow_id = workflowid and ggdb.node.nodetype = 'E')
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function links node to other nodes
 */
CREATE OR REPLACE FUNCTION ggdb.link_between (
		p_workflowname varchar(64)
	        , p_node1short char(3)
	        , p_node2short char(3)
		, p_guardlabel varchar(64) 
)
RETURNS VOID AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	SELECT ggdb.workflow.id INTO workflowid  from ggdb.workflow where ggdb.workflow.name = p_workflowname;

	IF (workflowid IS NULL) THEN
		RAISE EXCEPTION 'gossip guy app: workflow >%< not found', p_workflowname;
	END IF;

	IF p_node1short NOT IN (select ggdb.node.shortname from ggdb.node where ggdb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< not found', p_node1short;
	END IF;

	IF p_node1short NOT IN (select ggdb.node.shortname from ggdb.node where ggdb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< not found', p_node2short;
	END IF;

	insert into ggdb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(select ggdb.node.id from ggdb.node where ggdb.node.workflow_id = workflowid and ggdb.node.shortname = p_node1short)
		, (select ggdb.node.id from ggdb.node where ggdb.node.workflow_id = workflowid and ggdb.node.shortname = p_node2short)
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function adds nodes to a workflow
 */
CREATE OR REPLACE FUNCTION ggdb.add_node (
		p_workflowname varchar(64) 
		, p_shortname varchar(3)
		, p_name varchar(64)
		, p_nodetype char(1)
)
RETURNS void AS $PROC$
DECLARE
	workflowid INTEGER;
BEGIN
	select ggdb.workflow.id into workflowid from ggdb.workflow where ggdb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  workflow >%< not found', p_workflowname;
	END IF;

	IF p_shortname IN (select ggdb.node.shortname from ggdb.node where ggdb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< already exists', p_shortname;
	END IF;

	INSERT INTO ggdb.node (workflow_id, shortname, name, nodetype) VALUES
		(
		workflowid
		, p_shortname
		, p_name
		, p_nodetype
		);

END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns node information for a workflow
 */
CREATE OR REPLACE FUNCTION ggdb.get_nodes (
		p_workflowname varchar(64) 
)
RETURNS TABLE (
	id 		INTEGER,
	workflow_id 	INTEGER,
	shortname	varchar(3),  
	name		varchar(64), 
	nodetype	ggdb.nodetype
) AS $PROC$
DECLARE
	workflowid INTEGER;
BEGIN
	select ggdb.workflow.id into workflowid from ggdb.workflow where ggdb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  workflow >%< not found', p_workflowname;
	END IF;

	RETURN QUERY select ggdb.node.* from ggdb.node where ggdb.node.workflow_id = workflowid;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns node information when given id of the node
 */
CREATE OR REPLACE FUNCTION ggdb.get_node_by_id (
		p_nodeid INTEGER
)
RETURNS TABLE (
	id 		INTEGER,
	workflow_id 	INTEGER,
	shortname	varchar(3),  
	name		varchar(64), 
	nodetype	ggdb.nodetype
) AS $PROC$
DECLARE
	row1 record;
BEGIN
	select ggdb.node.* into row1 from ggdb.node where ggdb.node.id = p_nodeid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  node >%< not found', p_nodeid;
	END IF;

	RETURN QUERY (SELECT ggdb.node.* FROM ggdb.node WHERE ggdb.node.id = p_nodeid);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns node information for nodes without links.
 */
CREATE OR REPLACE FUNCTION ggdb.find_loose_nodes (
		p_workflowname varchar(64) 
)
RETURNS TABLE (
	id 		INTEGER,
	workflow_id 	INTEGER,
	shortname	varchar(3),  
	name		varchar(64), 
	nodetype	ggdb.nodetype
) AS $PROC$
DECLARE
	workflowid INTEGER;
BEGIN
	select ggdb.workflow.id into workflowid from ggdb.workflow where ggdb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  workflow >%< not found', p_workflowname;
	END IF;

	RETURN QUERY select ggdb.node.* 
		from ggdb.node 
		where ggdb.node.workflow_id = workflowid
		AND ggdb.node.id NOT IN 
			(
			SELECT fromnode_id from ggdb.link
			UNION
			SELECT tonode_id FROM ggdb.link 
			);
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;


/*
 * Function creates a workflow.
 */
CREATE OR REPLACE FUNCTION ggdb.create_workflow (
		p_name varchar(64) 
		, p_info text
)
RETURNS void AS $PROC$
DECLARE
BEGIN
	if p_name not in (select ggdb.workflow.name from ggdb.workflow) then
	
		insert into ggdb.workflow (name, info) values (p_name, p_info);		
		perform ggdb.add_node (p_name, 'str', 'start', 'S');
		perform ggdb.add_node (p_name, 'end', 'end', 'E');

	else
		RAISE EXCEPTION 'gossip guy app:  workflow >%< already exists', p_name;
	end if;

END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function deletes workflow and all of its associated nodes and links.
 */
CREATE OR REPLACE FUNCTION ggdb.drop_workflow (
		p_workflowname varchar(64) 
)
RETURNS void AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	select ggdb.workflow.id into workflowid from ggdb.workflow where ggdb.workflow.name = p_workflowname;

	IF (workflowid IS NULL) THEN
		RAISE EXCEPTION 'gossip guy app: workflow >%< not found', p_workflowname;
	ELSE
		DELETE FROM ggdb.link
			WHERE ggdb.link.fromnode_id IN (select id from ggdb.node where ggdb.node.workflow_id = workflowid);

		DELETE FROM ggdb.node
			WHERE ggdb.node.id IN (select id from ggdb.node where ggdb.node.workflow_id = workflowid);

		DELETE FROM ggdb.workflow
			WHERE ggdb.workflow.id = workflowid;
		
	end if;

END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns all workflow information in database.
 */
CREATE OR REPLACE FUNCTION ggdb.get_workflows (
)
RETURNS TABLE (id INTEGER, name varchar(64), info text) AS $PROC$
DECLARE
BEGIN

	RETURN QUERY SELECT * FROM ggdb.workflow;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'No workflows.';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Table created for the function ggdb.get_children, to return table in following format.
 */
CREATE TABLE ggdb.children (
		guardlabel	varchar(64),
		to_id 		integer, 
		to_shortname	varchar(3),  
		to_name		varchar(64)
);

/*
 * Function returns information on children of given node.
 */
CREATE OR REPLACE FUNCTION ggdb.get_children (
	p_workflowname		varchar(64),
	p_nodeshortname		varchar(3)
)
RETURNS SETOF ggdb.children AS $PROC$
DECLARE
	workflowid integer;
	nodeid integer;
	row2 record;
	linkrow ggdb.link%ROWTYPE;
	childrow ggdb.children%ROWTYPE;
BEGIN
	select ggdb.workflow.id into workflowid from ggdb.workflow where ggdb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  workflow >%< not found', p_workflowname;
	END IF;

	SELECT ggdb.node.id INTO nodeid FROM ggdb.node WHERE ggdb.node.workflow_id = workflowid AND ggdb.node.shortname = p_nodeshortname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< not found', p_shortname;
	END IF;

	FOR linkrow IN
		SELECT * FROM  ggdb.link l WHERE l.fromnode_id = nodeid

		LOOP

			select * into row2 from ggdb.node n WHERE n.id = linkrow.tonode_id;

			childrow.to_id:= row2.id;
			childrow.to_shortname:= row2.shortname;
			childrow.to_name:= row2.name;
		
			childrow.guardlabel:= linkrow.guardlabel;	
			RETURN NEXT childrow;
		END LOOP;
	RETURN;

END;
$PROC$ LANGUAGE plpgsql;



/*
 * Following creates a default workflow
 */
select ggdb.create_workflow ('def', 'default');
select ggdb.add_node ('def', 'zzz', 'default node for default workflow', 'A');
select ggdb.link_from_start ('def', 'zzz', '');
select ggdb.link_to_finish ('def', 'zzz', '');


/*
 * Following were used to test functions.
 */
/*
select ggdb.get_workflows();
select ggdb.get_nodes('X');

select ggdb.drop_workflow ('A1');

select ggdb.get_children('X', 'rco');

select ggdb.get_node_by_id(24);

select ggdb.find_loose_nodes('X');

select * from ggdb.link;
select * from ggdb.node;

*/