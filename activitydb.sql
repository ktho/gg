/*
 * A database for diagramming workflow
 */

create or replace language plpgsql;

DROP SCHEMA IF EXISTS activitydb CASCADE;
CREATE SCHEMA activitydb; 

/*
 * Represents workflow with only one unique name
 */
CREATE TABLE activitydb.workflow (
	id 	SERIAL PRIMARY KEY,
	name	varchar(64) UNIQUE NOT NULL,
	info	text
);

/*
 * Represents different node types
 */	
CREATE DOMAIN activitydb.nodetype char(1)
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
CREATE TABLE activitydb.node (
	id 		SERIAL PRIMARY KEY,
	workflow_id 	int references activitydb.workflow(id) on delete no action,
	shortname	varchar(3) check (shortname ~ '^[abcdefghijklmnopqrstuvwxyz]+$') NOT NULL,  
			--3 character maximum, lowercase only, no spaces, not unique
	name		varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz ]+$') NOT NULL,  
			--lowercase or uppercase, space allowed, same name in multiple workflows allowed
	nodetype	activitydb.nodetype
);

/*
 * Represents a link between nodes
 */
CREATE TABLE activitydb.link (
	fromnode_id	int references activitydb.node(id) on delete no action,
	tonode_id	int references activitydb.node(id) on delete no action,
	guardlabel	varchar(64),
	PRIMARY KEY (fromnode_id, tonode_id)
);

/*
 * Function links node to starting node for that workflow
 */
CREATE OR REPLACE FUNCTION activitydb.link_from_start (
		p_workflowname varchar(64)
	        , p_nodeshortname char(3)
		, p_guardlabel varchar(64) 
)
RETURNS VOID AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	SELECT activitydb.workflow.id INTO workflowid FROM activitydb.workflow WHERE activitydb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app: workflow >%< not found', p_workflowname;
	END IF;

	IF p_nodeshortname NOT IN (select activitydb.node.shortname from activitydb.node where activitydb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'activity app:  node shortname >%< not found', p_nodeshortname;
	END IF;

	insert into activitydb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(select activitydb.node.id from activitydb.node where activitydb.node.workflow_id = workflowid and activitydb.node.nodetype = 'S')
		, (select activitydb.node.id from activitydb.node where activitydb.node.workflow_id = workflowid and activitydb.node.shortname = p_nodeshortname)
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function links node to ending node for that workflow
 */
CREATE OR REPLACE FUNCTION activitydb.link_to_finish (
		p_workflowname varchar(64)
	        , p_nodeshortname char(3)
		, p_guardlabel varchar(64) 
)
RETURNS VOID AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	SELECT activitydb.workflow.id INTO workflowid FROM activitydb.workflow WHERE activitydb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app: workflow >%< not found', p_workflowname;
	END IF;

	IF p_nodeshortname NOT IN (select activitydb.node.shortname from activitydb.node where activitydb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'activity app:  node shortname >%< not found', p_nodeshortname;
	END IF;

	insert into activitydb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(select activitydb.node.id from activitydb.node where activitydb.node.workflow_id = workflowid and activitydb.node.shortname = p_nodeshortname)
		, (select activitydb.node.id from activitydb.node where activitydb.node.workflow_id = workflowid and activitydb.node.nodetype = 'E')
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function links node to other nodes
 */
CREATE OR REPLACE FUNCTION activitydb.link_between (
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
	SELECT activitydb.workflow.id INTO workflowid  from activitydb.workflow where activitydb.workflow.name = p_workflowname;

	IF (workflowid IS NULL) THEN
		RAISE EXCEPTION 'activity app: workflow >%< not found', p_workflowname;
	END IF;

	IF p_node1short NOT IN (select activitydb.node.shortname from activitydb.node where activitydb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'activity app:  node shortname >%< not found', p_node1short;
	END IF;

	IF p_node1short NOT IN (select activitydb.node.shortname from activitydb.node where activitydb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'activity app:  node shortname >%< not found', p_node2short;
	END IF;

	insert into activitydb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(select activitydb.node.id from activitydb.node where activitydb.node.workflow_id = workflowid and activitydb.node.shortname = p_node1short)
		, (select activitydb.node.id from activitydb.node where activitydb.node.workflow_id = workflowid and activitydb.node.shortname = p_node2short)
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function adds nodes to a workflow
 */
CREATE OR REPLACE FUNCTION activitydb.add_node (
		p_workflowname varchar(64) 
		, p_shortname varchar(3)
		, p_name varchar(64)
		, p_nodetype char(1)
)
RETURNS void AS $PROC$
DECLARE
	workflowid INTEGER;
BEGIN
	select activitydb.workflow.id into workflowid from activitydb.workflow where activitydb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app:  workflow >%< not found', p_workflowname;
	END IF;

	IF p_shortname IN (select activitydb.node.shortname from activitydb.node where activitydb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'activity app:  node shortname >%< already exists', p_shortname;
	END IF;

	INSERT INTO activitydb.node (workflow_id, shortname, name, nodetype) VALUES
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
CREATE OR REPLACE FUNCTION activitydb.get_nodes (
		p_workflowname varchar(64) 
)
RETURNS TABLE (
	id 		INTEGER,
	workflow_id 	INTEGER,
	shortname	varchar(3),  
	name		varchar(64), 
	nodetype	activitydb.nodetype
) AS $PROC$
DECLARE
	workflowid INTEGER;
BEGIN
	select activitydb.workflow.id into workflowid from activitydb.workflow where activitydb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app:  workflow >%< not found', p_workflowname;
	END IF;

	RETURN QUERY select activitydb.node.* from activitydb.node where activitydb.node.workflow_id = workflowid;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns node information when given id of the node
 */
CREATE OR REPLACE FUNCTION activitydb.get_node_by_id (
		p_nodeid INTEGER
)
RETURNS TABLE (
	id 		INTEGER,
	workflow_id 	INTEGER,
	shortname	varchar(3),  
	name		varchar(64), 
	nodetype	activitydb.nodetype
) AS $PROC$
DECLARE
	row1 record;
BEGIN
	select activitydb.node.* into row1 from activitydb.node where activitydb.node.id = p_nodeid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app:  node >%< not found', p_nodeid;
	END IF;

	RETURN QUERY (SELECT activitydb.node.* FROM activitydb.node WHERE activitydb.node.id = p_nodeid);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns node information for nodes without links.
 */
CREATE OR REPLACE FUNCTION activitydb.find_loose_nodes (
		p_workflowname varchar(64) 
)
RETURNS TABLE (
	id 		INTEGER,
	workflow_id 	INTEGER,
	shortname	varchar(3),  
	name		varchar(64), 
	nodetype	activitydb.nodetype
) AS $PROC$
DECLARE
	workflowid INTEGER;
BEGIN
	select activitydb.workflow.id into workflowid from activitydb.workflow where activitydb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app:  workflow >%< not found', p_workflowname;
	END IF;

	RETURN QUERY select activitydb.node.* 
		from activitydb.node 
		where activitydb.node.workflow_id = workflowid
		AND activitydb.node.id NOT IN 
			(
			SELECT fromnode_id from activitydb.link
			UNION
			SELECT tonode_id FROM activitydb.link 
			);
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;


/*
 * Function creates a workflow.
 */
CREATE OR REPLACE FUNCTION activitydb.create_workflow (
		p_name varchar(64) 
		, p_info text
)
RETURNS void AS $PROC$
DECLARE
BEGIN
	if p_name not in (select activitydb.workflow.name from activitydb.workflow) then
	
		insert into activitydb.workflow (name, info) values (p_name, p_info);		
		perform activitydb.add_node (p_name, 'str', 'start', 'S');
		perform activitydb.add_node (p_name, 'end', 'end', 'E');

	else
		RAISE EXCEPTION 'activity app:  workflow >%< already exists', p_name;
	end if;

END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function deletes workflow and all of its associated nodes and links.
 */
CREATE OR REPLACE FUNCTION activitydb.drop_workflow (
		p_workflowname varchar(64) 
)
RETURNS void AS $PROC$
DECLARE
	/* variable to hold id of workflow that matches p_workflowname*/
	workflowid	integer;
BEGIN
	select activitydb.workflow.id into workflowid from activitydb.workflow where activitydb.workflow.name = p_workflowname;

	IF (workflowid IS NULL) THEN
		RAISE EXCEPTION 'activity app: workflow >%< not found', p_workflowname;
	ELSE
		DELETE FROM activitydb.link
			WHERE activitydb.link.fromnode_id IN (select id from activitydb.node where activitydb.node.workflow_id = workflowid);

		DELETE FROM activitydb.node
			WHERE activitydb.node.id IN (select id from activitydb.node where activitydb.node.workflow_id = workflowid);

		DELETE FROM activitydb.workflow
			WHERE activitydb.workflow.id = workflowid;
		
	end if;

END;
$PROC$ LANGUAGE plpgsql;

/*
 * Function returns all workflow information in database.
 */
CREATE OR REPLACE FUNCTION activitydb.get_workflows (
)
RETURNS TABLE (id INTEGER, name varchar(64), info text) AS $PROC$
DECLARE
BEGIN

	RETURN QUERY SELECT * FROM activitydb.workflow;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'No workflows.';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;

/*
 * Table created for the function activitydb.get_children, to return table in following format.
 */
CREATE TABLE activitydb.children (
		guardlabel	varchar(64),
		to_id 		integer, 
		to_shortname	varchar(3),  
		to_name		varchar(64)
);

/*
 * Function returns information on children of given node.
 */
CREATE OR REPLACE FUNCTION activitydb.get_children (
	p_workflowname		varchar(64),
	p_nodeshortname		varchar(3)
)
RETURNS SETOF activitydb.children AS $PROC$
DECLARE
	workflowid integer;
	nodeid integer;
	row2 record;
	linkrow activitydb.link%ROWTYPE;
	childrow activitydb.children%ROWTYPE;
BEGIN
	select activitydb.workflow.id into workflowid from activitydb.workflow where activitydb.workflow.name = p_workflowname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app:  workflow >%< not found', p_workflowname;
	END IF;

	SELECT activitydb.node.id INTO nodeid FROM activitydb.node WHERE activitydb.node.workflow_id = workflowid AND activitydb.node.shortname = p_nodeshortname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'activity app:  node shortname >%< not found', p_shortname;
	END IF;

	FOR linkrow IN
		SELECT * FROM  activitydb.link l WHERE l.fromnode_id = nodeid

		LOOP

			select * into row2 from activitydb.node n WHERE n.id = linkrow.tonode_id;


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
 * Following inputs are used for testing
 */
select activitydb.create_workflow ('w01', 'homework for the first worksheet');
select activitydb.create_workflow ('w02', 'homework for the second worksheet');
select activitydb.create_workflow ('w03', 'homework for the third worksheet');
select activitydb.add_node ('w01', 'bbb', 'bobby brady', 'A');
select activitydb.add_node ('w01', 'xxx', 'xavier xu', 'A');
select activitydb.link_from_start ('w01', 'bbb', 'this is a guard label');
select activitydb.link_to_finish ('w01', 'xxx', 'this is the guard label 2');


select activitydb.create_workflow ('A1', 'homework for activity1');
select activitydb.add_node('A1', 'two', 'second path', 'A');
select activitydb.add_node ('A1', 'fff', 'Yellow Power Ranger', 'A');
select activitydb.add_node ('A1', 'yyy', 'Black Power Ranger', 'A');

select activitydb.link_from_start('A1', 'fff', 'For the win');
select activitydb.link_to_finish ('A1', 'yyy', 'good game');
select activitydb.link_between ('A1', 'fff','yyy', 'starcraft2 sucks');


select activitydb.link_from_start ('A1', 'two', 'secondlife');
select activitydb.link_to_finish('A1', 'two', 'alternativelife');

/*
 * Implemented Activity Diagram from Assignment Details
 */
select activitydb.create_workflow ('X', 'Requested Order');

select activitydb.add_node ('X', 'rco', 'Receive Order', 'A');
select activitydb.add_node ('X', 'flo', 'Fill Order', 'A');
select activitydb.add_node ('X', 'for', 'Fork Node', 'F');
select activitydb.add_node ('X', 'so', 'Send Invoice', 'A');
select activitydb.add_node ('X', 'sho', 'Ship Order', 'A');
select activitydb.add_node ('X', 'inv', 'Invoice', 'A');
select activitydb.add_node ('X', 'ap', 'Accept Payment', 'A');
select activitydb.add_node ('X', 'joi', 'Join Node', 'J');
select activitydb.add_node ('X', 'clo', 'Close Order', 'A');

select activitydb.link_from_start ('X', 'rco', '');
select activitydb.link_to_finish('X', 'clo', '');
select activitydb.link_between ('X', 'rco','clo', 'order rejected');
select activitydb.link_between ('X', 'rco','flo', 'order accepted');
select activitydb.link_between ('X', 'flo', 'for', '');
select activitydb.link_between ('X', 'for', 'so', '');
select activitydb.link_between ('X', 'for', 'sho', '');
select activitydb.link_between ('X', 'so', 'ap', '');
select activitydb.link_between ('X', 'so', 'joi', '');
select activitydb.link_between ('X', 'ap', 'joi', '');
select activitydb.link_between ('X', 'joi', 'clo', '');



/*
 * Following were used to test functions.
 */
/*
select activitydb.get_workflows();
select activitydb.get_nodes('X');

select activitydb.drop_workflow ('A1');

select activitydb.get_children('X', 'rco');

select activitydb.get_node_by_id(24);

select activitydb.find_loose_nodes('X');

select * from activitydb.link;
select * from activitydb.node;

*/