/*
 * A database for gossip guy
 */

create or replace language plpgsql;

DROP SCHEMA IF EXISTS ggdb CASCADE;
CREATE SCHEMA ggdb; 


/*
 ********************************************************************************
    TABLES AND INDEXES:   
 ********************************************************************************
 */

/*
 * WORKFLOW:  Represents workflow with only one unique name
 */
CREATE TABLE ggdb.workflow (
	id 	SERIAL PRIMARY KEY,
	name	varchar(64) UNIQUE NOT NULL,
	info	text
);

/*
 * WORKFLOW:  Represents different node types
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
 * WORKFLOW:  Represents a node
 */
CREATE TABLE ggdb.node (
	id 		SERIAL PRIMARY KEY,
	workflow_id 	int references ggdb.workflow(id) on delete no action,
	shortname	varchar(3) check (shortname ~* '^[abcdefghijklmnopqrstuvwxyz]+$') NOT NULL,  
			--3 character maximum, no spaces, not unique
	name		varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz ]+$') NOT NULL,  
			--lowercase or uppercase, space allowed, same name in multiple workflows allowed
	nodetype	ggdb.nodetype
);

/*
 * WORKFLOW:  Represents a link between nodes
 */
CREATE TABLE ggdb.link (
	fromnode_id	int references ggdb.node(id) on delete no action,
	tonode_id	int references ggdb.node(id) on delete no action,
	guardlabel	varchar(64),
	PRIMARY KEY (fromnode_id, tonode_id)
);

/*
 * DOCUMENT:  Represents gossip
 */
CREATE TABLE ggdb.gossip (
	id		SERIAL PRIMARY KEY,
	title		varchar(128) NOT NULL,
	body		text NOT NULL
);


/*
 * WORKFLOW/DOCUMENT:  Represents state of each gossip, bridges gossip and node
 */
CREATE TABLE ggdb.gossip_node (
	node_id		int references ggdb.node(id) on delete no action,
	gossip_id	int references ggdb.gossip(id) on delete no action,
	time		timestamp NOT NULL,
	PRIMARY KEY (node_id, gossip_id)
);

/*
 * DOCUMENT:  Represents reporter
 */
CREATE TABLE ggdb.reporter (
	id		SERIAL PRIMARY KEY,
	username	varchar(64) check (username ~* '^[abcdefghijklmnopqrstuvwxyz ]+$') UNIQUE NOT NULL,
	first_name	varchar(64) check (first_name ~* '^[abcdefghijklmnopqrstuvwxyz-. ]+$') NOT NULL,
	last_name	varchar(64) check (last_name ~* '^[abcdefghijklmnopqrstuvwxyz-. ]+$') NOT NULL,
	commission	money	
);

/*
 * DOCUMENT:  Represents celebrity
 */
CREATE TABLE ggdb.celebrity (
	id		SERIAL PRIMARY KEY,
	nick_name	varchar(64) check (nick_name ~* '^[abcdefghijklmnopqrstuvwxyz-. ]+$') UNIQUE NOT NULL,	
	first_name	varchar(64) check (first_name ~* '^[abcdefghijklmnopqrstuvwxyz ]+$') NOT NULL,
	last_name	varchar(64) check (last_name ~* '^[abcdefghijklmnopqrstuvwxyz-. ]+$') NOT NULL,
	birthdate	date	
);

/*
 * DOCUMENT:  Represents link between reporter and gossip
 */
CREATE TABLE ggdb.reporter_gossip (
	reporter_id	int references ggdb.reporter(id) on delete no action,
	gossip_id	int references ggdb.gossip(id) on delete no action,
	PRIMARY KEY (gossip_id, reporter_id)
);

/*
 * DOCUMENT:  Represents link between celebrity and gossip
 */
CREATE TABLE ggdb.celebrity_gossip (
	celebrity_id	int references ggdb.celebrity(id) on delete no action,
	gossip_id	int references ggdb.gossip(id) on delete no action,
	PRIMARY KEY (gossip_id, celebrity_id)
);

/*
 * TAGGING:  Represents bundle of tags
 */
CREATE TABLE ggdb.bundle (
	id	SERIAL PRIMARY KEY,
	name	varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz-. ]+$') UNIQUE NOT NULL
);

/*
 * TAGGING:  Represents tag
 */
CREATE TABLE ggdb.tag (
	id		SERIAL PRIMARY KEY,
	bundle_id	int references ggdb.bundle(id) on delete no action,
	name		varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz-. ]+$') UNIQUE NOT NULL
);

/*
 * DOCUMENT/TAGGING:  Represents link between gossip and tag
 */
CREATE TABLE ggdb.gossip_tag (
	gossip_id	int references ggdb.gossip(id) on delete no action,
	tag_id		int references ggdb.tag(id) on delete no action,
	PRIMARY KEY (gossip_id, tag_id)
);

/*
 * UTILITY:  stores information on major system events
 */
CREATE TABLE ggdb.revision_history (
	id	SERIAL PRIMARY KEY,
	time	timestamp NOT NULL,
	message	text NOT NULL
);


/*
 ********************************************************************************
   WORKFLOW MODULE FUNCTIONS:   
 ********************************************************************************
 */


/*
 * WORKFLOW:  Function links node to starting node for that workflow
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

	IF p_nodeshortname NOT IN (SELECT ggdb.node.shortname FROM ggdb.node WHERE ggdb.node.workflow_id = workflowid) THEN
		RAISE EXCEPTION 'gossip guy app:  node shortname >%< not found', p_nodeshortname;
	END IF;

	insert into ggdb.link (fromnode_id, tonode_id, guardlabel) values
		(
		(SELECT ggdb.node.id FROM ggdb.node WHERE ggdb.node.workflow_id = workflowid AND ggdb.node.nodetype = 'S')
		, (SELECT ggdb.node.id FROM ggdb.node WHERE ggdb.node.workflow_id = workflowid AND ggdb.node.shortname = p_nodeshortname)
		, p_guardlabel
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * WORKFLOW:  Function links node to ending node for that workflow
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
 * WORKFLOW:  Function links node to other nodes
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
 * WORKFLOW:  Function adds nodes to a workflow
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
 * WORKFLOW:  Function returns node information for a workflow
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
 * WORKFLOW:  Function returns node information when given id of the node
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
 * WORKFLOW:  Function returns node information for nodes without links.
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
 * WORKFLOW:  Function creates a workflow.
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
 * WORKFLOW:  Function deletes workflow and all of its associated nodes and links.
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
 * WORKFLOW:  Function returns all workflow information in database.
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
 * WORKFLOW:  Table created for the function ggdb.get_children, to return table in following format.
 */
CREATE TABLE ggdb.children (
		guardlabel	varchar(64),
		to_id 		integer, 
		to_shortname	varchar(3),  
		to_name		varchar(64)
);

/*
 * WORKFLOW:  Function returns information on children of given node.
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
 ********************************************************************************
    DOCUMENT MODULE FUNCTIONS: Katie & Xing
 ********************************************************************************
 */


/*
 * DOCUMENT:  Add Reporter
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.add_reporter (
		p_username varchar(64) 
		, p_first varchar(64)
		, p_last varchar(64)
		, p_comm money
)
RETURNS void AS $PROC$
BEGIN

	IF p_username IN (select R.username from ggdb.reporter R where R.username = p_username) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter username >%< already exists', p_username;
	END IF;

	INSERT INTO ggdb.reporter (username, first_name, last_name, commission) VALUES
		(p_username, p_first, p_last, p_comm);
END;

/* Call Revision History Function Here
 */
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Update Reporter
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.update_reporter (
		p_username varchar(64)
		, p_first varchar(64)
		, p_last varchar(64)
		, p_comm money
)
RETURNS void AS $PROC$
BEGIN

	IF p_username NOT IN (select R.username from ggdb.reporter R where R.username = p_username) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter username >%< does not exist', p_username;
	END IF;
/*
	Update ggdb.reporter SET
		username
		;

	(username, first_name, last_name, commission) 
		(p_username, p_first, p_last, p_comm);
		*/
END;
$PROC$ LANGUAGE plpgsql;

/* Call Revision History Funciton Here
 */

/* DOCUMENT: Create Nick_Name for table celebrity if 
 * DOCUMENT:  Add Celebrity
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.add_celebrity (
		p_first varchar(64)
		, p_last varchar(64)
		, p_nick varchar(64)
		, p_bday date
)
RETURNS void AS $PROC$
BEGIN

	IF p_nick IN (select C.nick_name from ggdb.celebrity C where c.nick_name = p_nick) THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< already exists', p_first || ' ' ||p_last;
	END IF;

	INSERT INTO ggdb.celebrity (first_name, last_name, nick_name, birthdate) VALUES
		(p_first, p_last, p_nick, p_bday);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Create Gossip
 * @Author: Katie
 */
 
CREATE OR REPLACE FUNCTION ggdb.create_gossip (
		p_workflow
		, p_nodeshortname
		, p_reporter
		, p_celebrity
		, p_title varchar(128) 
		, p_body text
)
RETURNS void AS $PROC$
DECLARE
	workflowid INTEGER;
	nodeid INTEGER;
	reporterid INTEGER;
	celebrityid INTEGER;
	gossipid INTEGER;
	
BEGIN
	select ggdb.workflow.id into workflowid from ggdb.workflow where ggdb.workflow.name = p_workflow;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  workflow >%< not found', p_workflow;
	END IF;

	SELECT ggdb.node.id INTO nodeid FROM ggdb.node WHERE ggdb.workflow_id = workflowid and ggdb.node.shortname = p_nodeshortname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  node >%< not found', p_nodeshortname;
	END IF;

	select ggdb.reporter.id into reporterid from ggdb.reporter where ggdb.reporter.username = p_reporter;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  reporter >%< not found', p_workflow;
	END IF;

	select ggdb.celebrity.id into celebrityid from ggdb.celebrity where ggdb.celeberity.nick_name = p_celebrity;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< not found', p_workflow;
	END IF;

	INSERT INTO ggdb.gossip (title, body) VALUES
		(
		p_title
		, p_body
		);

	INSERT INTO ggdb.gossip_node(node_id, gossip_id, time) VALUES
		(
		nodeid
		, gossipid
		, clock_timestamop()
		);

	INSERT INTO ggdb.reporter_gossip(reporter_id, gossip_id) VALUES
		(
		reporterid
		, gossipid
		);

	INSERT INTO ggdb.celebrity_gossip(gossip_id, celebrity_id) VALUES
		(
		gossipid
		, celebrityid
		);
END;
$PROC$ LANGUAGE plpgsql;


/*
 * DOCUMENT:  Update Gossip
 */
--CREATE OR REPLACE FUNCTION ggdb.

/*
 * DOCUMENT:  Delete Gossip
 */
--CREATE OR REPLACE FUNCTION ggdb.

/*
 * DOCUMENT:  Get Gossip From Reporter
 */
--CREATE OR REPLACE FUNCTION ggdb.

/*
 * DOCUMENT:  Get Gossip About
 */
--CREATE OR REPLACE FUNCTION ggdb.



/*
 ********************************************************************************
   TAGGING MODULE FUNCTIONS:   
 ********************************************************************************
 */

/*
 * TAGGING:  Create Tag
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.create_tag (
		p_id 			int,
		p_bundle_id		int,
		p_name			varchar(64)
)
RETURNS void AS $PROC$
BEGIN

	IF p_id IN (select R.id from ggdb.tag R) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< already exists', p_name;
	END IF;

	INSERT INTO ggdb.tag (id, bundle_id, name) VALUES
		(p_id, p_bundle_id, p_name);
END;
$PROC$ LANGUAGE plpgsql;


/*
 * TAGGING:  Update Tag
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.update_tag (
		p_id 			int,
		p_bundle_id		int,
		p_name			varchar(64)
)
RETURNS void AS $PROC$
BEGIN

	IF p_id NOT IN (select R.id from ggdb.tag R) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< does not exist', p_name;
	END IF;

	UPDATE ggdb.tag (id, bundle_id, name) VALUES
		(p_id, p_bundle_id, p_name);
END;
$PROC$ LANGUAGE plpgsql;
 
 
 /*
 * TAGGING:  Delete Tag
 * @Author: cte13
 */
 CREATE OR REPLACE FUNCTION ggdb.delete_tag (
		p_id 			int,
		p_bundle_id		int,
		p_name			varchar(64)
)
RETURNS void AS $PROC$
BEGIN

	IF p_id NOT IN (select R.id from ggdb.tag R) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< does not exist', p_name;
	END IF;

	UPDATE ggdb.tag (id, bundle_id, name) VALUES
		(p_id, p_bundle_id, p_name);
END;
$PROC$ LANGUAGE plpgsql;
);
 
/*
 * TAGGING:  Create Bundle
 * @Author: cte13
 */
 
 /*
 * TAGGING:  Update Bundle
 * @Author: cte13
 */
 
 /*
 * TAGGING:  Delete Bundle
 * @Author: cte13
 */
 
 /*
 * TAGGING:  View Gossip by Tag
 * @Author: cte13
 */
 
/*
 * TAGGING:  View Gossip by Bundle
 * @Author: cte13
 */
 
/*
 ********************************************************************************
   UTILITY MODULE FUNCTIONS:   
 ********************************************************************************
 */




/*
 ********************************************************************************
    INSERT DEFAULT DATA:   
 ********************************************************************************
 */
select ggdb.create_workflow ('def', 'default');
select ggdb.add_node ('def', 'dra', 'draft', 'A');
select ggdb.add_node ('def', 'pub', 'publish', 'A');
select ggdb.link_from_start ('def', 'zzz', '');
select ggdb.link_to_finish ('def', 'zzz', '');
select ggdb.link_between('def', 'dra', 'pub');
/*
select ggdb.add_reporter('katie', 'Katie', 'Ho', '$10000.00');
select ggdb.add_celebrity('Kirsten', 'Stewart', 'kstew', '2012-03-30');
*/

/*
 * TESTING FUNCTIONS
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