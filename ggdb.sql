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
		'E'		--Ending node
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
	username	varchar(64) check (username ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') UNIQUE NOT NULL,	
	first_name	varchar(64) check (first_name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') NOT NULL,
	last_name	varchar(64) check (last_name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') NOT NULL,
	commission	money	
);

/*
 * DOCUMENT:  Represents celebrity
 */
CREATE TABLE ggdb.celebrity (
	id		SERIAL PRIMARY KEY,
	nick_name	varchar(64) check (nick_name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') UNIQUE NOT NULL,	
	first_name	varchar(32) check (first_name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') NOT NULL,
	last_name	varchar(32) check (last_name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') NOT NULL,
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
	/* Call Revision History Funciton Here
	*/ 
END;

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
	
	Update ggdb.reporter SET first_name=p_first, last_name=p_last, commission=p_comm
	WHERE username=p_username;
	/* Call Revision History Funciton Here
	*/ 
 END;
$PROC$ LANGUAGE plpgsql;



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
	
	/* Call Revision History Funciton Here
	*/ 
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Create Gossip
 * @Author: Katie
 */
 
CREATE OR REPLACE FUNCTION ggdb.create_gossip (
		p_workflow varchar(64)
		, p_nodeshortname varchar(3)
		, p_reporter varchar(64)
		, p_celebrity varchar(64)
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

	SELECT ggdb.node.id INTO nodeid FROM ggdb.node WHERE ggdb.node.workflow_id = workflowid and ggdb.node.shortname = p_nodeshortname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  node >%< not found', p_nodeshortname;
	END IF;

	select ggdb.reporter.id into reporterid from ggdb.reporter where ggdb.reporter.username = p_reporter;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  reporter >%< not found', p_reporter;
	END IF;

	select ggdb.celebrity.id into celebrityid from ggdb.celebrity where ggdb.celebrity.nick_name = p_celebrity;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< not found', p_celebrity;
	END IF;

	INSERT INTO ggdb.gossip (title, body) VALUES
		(
		p_title
		, p_body
		);

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.title = p_title AND ggdb.gossip.body = p_body;

	INSERT INTO ggdb.gossip_node(node_id, gossip_id, time) VALUES
		(
		nodeid
		, gossipid
		, clock_timestamp()
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
 * DOCUMENT:  Add Reporter To Gossip
 * @Author: Katie
 */
 
CREATE OR REPLACE FUNCTION ggdb.add_reporter_to_gossip (
		  p_reporter varchar(64)
		, p_gossipid INTEGER
)
RETURNS void AS $PROC$
DECLARE
	reporterid INTEGER;
	gossipid INTEGER;
BEGIN
	SELECT ggdb.reporter.id INTO reporterid FROM ggdb.reporter WHERE ggdb.reporter.username = p_reporter;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  reporter >%< not found', p_reporter;
	END IF;

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_reporter;
	END IF;	

	INSERT INTO ggdb.reporter_gossip(reporter_id, gossip_id) VALUES
		(
		reporterid
		, gossipid
		);
END;
$PROC$ LANGUAGE plpgsql;


/*
 * DOCUMENT:  Add Celebrity To Gossip
 * @Author: Katie
 */
 
CREATE OR REPLACE FUNCTION ggdb.add_celebrity_to_gossip (
		  p_celebritynickname VARCHAR (64)
		, p_gossipid INTEGER
)
RETURNS void AS $PROC$
DECLARE
	celebrityid INTEGER;
	gossipid INTEGER;
BEGIN
	SELECT ggdb.celebrity.id INTO celebrityid FROM ggdb.celebrity WHERE ggdb.celebrity.nick_name = p_celebritynickname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< not found', p_reporter;
	END IF;

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_reporter;
	END IF;	

	INSERT INTO ggdb.celebrity_gossip(celebrity_id, gossip_id) VALUES
		(
		celebrityid
		, gossipid
		);
END;
$PROC$ LANGUAGE plpgsql;





/*
add_tag_to_gossip
*/




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
	p_title			varchar(128),
	p_bname			int,
	p_tname			varchar(64)
)
RETURNS void AS $PROC$
DECLARE
	bid		INTEGER;
	gid		INTEGER;
	tid		INTEGER;
BEGIN
	SELECT G.id INTO gid FROM ggdb.gossip G WHERE G.title = p_title;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  title >%< not found', p_title;
	END IF;
	
	IF p_tname IN (select T.name from ggdb.tag T) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< already exists', p_name;
	END IF;
	
	SELECT B.id INTO bid FROM ggdb.bundle B WHERE B.name = p_bname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  bundle >%< not found', p_bname;
		-- Possible to create a bundle if it does not exist... better option?
	END IF;
	
	INSERT INTO ggdb.tag (bundle_id, name) VALUES
		(bid, p_name);
		
	SELECT T.id INTO tid FROM ggdb.tag T WHERE T.name = p_tname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app: error with tag >%< not found', p_title;
	END IF;
		
	INSERT INTO ggdb.gossip_tag (gossip_id, tag_id) VALUES
		(gid, tid);
END;
$PROC$ LANGUAGE plpgsql;


/*
 * TAGGING:  Update Tag
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.update_tag (
		p_name			varchar(64),
		p_newbname		varchar(64),
		p_newname		varchar(64)
)
RETURNS void AS $PROC$
DECLARE
	new_bid		INTEGER;
BEGIN
	IF p_name NOT IN (select R.name from ggdb.tag R) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< does not exist', p_name;
	END IF;
	
	SELECT B.id INTO new_bid FROM ggdb.bundle B WHERE B.name = p_newbname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  bundle >%< not found', p_bname;
		-- Possible to create a bundle if it does not exist... better option?
	END IF;	

	UPDATE ggdb.tag T SET T.name = p_newname, T.bundle_id = new_bid
		WHERE T.name = p_name;
END;
$PROC$ LANGUAGE plpgsql;

 
 /*
 * TAGGING:  Delete Tag
 * @Author: cte13
 */
 CREATE OR REPLACE FUNCTION ggdb.delete_tag (
		p_name			varchar(64)
)
RETURNS void AS $PROC$
DECLARE
	id		INTEGER;
BEGIN
	SELECT T.id INTO id FROM ggdb.tag T WHERE T.name = p_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< does not exist', p_name;
	END IF;

	DELETE FROM ggdb.tag T WHERE T.id = id;
END;
$PROC$ LANGUAGE plpgsql;

 
/*
 * TAGGING:  Create Bundle
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.create_bundle (
		p_name		varchar(64)
)
RETURNS void AS $PROC$
BEGIN
	IF p_name IN (select B.name from ggdb.bundle B) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< already exists', p_name;
	END IF;

	INSERT INTO ggdb.bundle (name) VALUES
		(p_name);
END;
$PROC$ LANGUAGE plpgsql;

 /*
 * TAGGING:  Update Bundle
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.update_bundle (
		p_name			varchar(64),
		p_newname		varchar(64)
)
RETURNS void AS $PROC$
BEGIN
	IF p_name NOT IN (select B.name from ggdb.bundle B) THEN
		RAISE EXCEPTION 'gossip guy app: bundle >%< does not exist', p_name;
	END IF;

	UPDATE ggdb.bundle B SET B.name = p_newname
		WHERE T.name = p_name;
END;
$PROC$ LANGUAGE plpgsql;

 /*
 * TAGGING:  Delete Bundle
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.delete_bundle (
		p_name			varchar(64)
)
RETURNS void AS $PROC$
BEGIN
	IF p_name NOT IN (select B.name from ggdb.bundle B) THEN
		RAISE EXCEPTION 'gossip guy app: bundle >%< does not exist', p_name;
	END IF;

	DELETE FROM ggdb.bundle B WHERE B.name = p_name;
END;
$PROC$ LANGUAGE plpgsql;
 
 /*
 * TAGGING:  View Gossip by Tag
 * @Author: cte13
 */
CREATE OR REPLACE FUNCTION ggdb.view_tag (
		p_name		varchar(64)
)
RETURNS TABLE (
	title		varchar(128),
	body		text
) AS $PROC$
DECLARE
	tid		INTEGER;
	gid		RECORD;
BEGIN
	select T.id into tid from ggdb.tag T where T.name = p_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< not found', p_name;
	END IF;

	select B.id into gid from ggdb.gossip_tag B where B.tag_id = tid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< not in use', p_name;
	END IF;
	
	RETURN QUERY (SELECT G.title, G.body FROM ggdb.gossip G WHERE G.id IN (
		SELECT * FROM gid
		));
END;
$PROC$ LANGUAGE plpgsql;

/*
 * TAGGING:  View Gossip by Bundle
 * @Author: cte13
 */
 CREATE OR REPLACE FUNCTION ggdb.view_bundle (
		p_name		varchar(64)
)
RETURNS TABLE (
	title		varchar(128),
	body		text
) AS $PROC$
DECLARE
	bid		INTEGER;
	tid		INTEGER;
	gid		RECORD;
BEGIN
	select B.id into bid from ggdb.bundle B where B.name = p_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  bundle >%< not found', p_name;
	END IF;

	select T.id into tid from ggdb.tag T where T.bundle_id = bid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  bundle >%< does not contain any tags', p_name;
	END IF;

	select G.id into gid from ggdb.gossip_tag G where G.tag_id = tid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< not in use', p_name;
	END IF;
	
	RETURN QUERY (SELECT G.title, G.body FROM ggdb.gossip G WHERE G.id IN (
		SELECT * FROM gid
		));
END;
$PROC$ LANGUAGE plpgsql;

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
select ggdb.link_from_start ('def', 'dra', '');
select ggdb.link_to_finish ('def', 'pub', '');
select ggdb.link_between('def', 'dra', 'pub', '');
select ggdb.add_reporter('katie', 'Katie', 'Ho', '$10000.00');
select ggdb.add_reporter('xingxu', 'Xing', 'Xu', '$50000.00');
select ggdb.add_celebrity('Kirsten', 'Stewart', 'kstew', '2012-03-30');
select ggdb.create_gossip('def', 'dra', 'katie', 'kstew', 'Kstew is in another scandal!', 'kstew tweets about whether she should get plastic surgery');
select ggdb.add_reporter_to_gossip('xingxu', 1);
select ggdb.add_celebrity('Robert', 'Pattinson', 'RPat', '2013-05-30');
select ggdb.add_celebrity_to_gossip('RPat', 1);

/*
 * TESTING FUNCTIONS
 */
/*
select ggdb.update_reporter('katie', 'Bobby', 'Brady', '$5.00');

select * from ggdb.reporter;

select * from ggdb.gossip;

select * from ggdb.gossip_node;
select * from ggdb.reporter_gossip;
select * from ggdb.celebrity_gossip;


select ggdb.get_workflows();
select ggdb.get_nodes('X');

select ggdb.drop_workflow ('A1');

select ggdb.get_children('X', 'rco');

select ggdb.get_node_by_id(24);

select ggdb.find_loose_nodes('X');

select * from ggdb.link;
select * from ggdb.node;

*/