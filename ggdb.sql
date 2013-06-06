 /* A database for gossip guy
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
	publish_date	timestamp,
	is_active	boolean
);

/*
 * DOCUMENT/WORKFLOW:  Represents link between gossip and node (i.e. the status)
 */
CREATE TABLE ggdb.gossip_node (
	gossip_id	int references ggdb.gossip(id) on delete no action,
	node_id		int references ggdb.node(id) on delete no action,
	start_time	timestamp NOT NULL,
	PRIMARY KEY (gossip_id, node_id)
);

/*
 * DOCUMENT:  Represents versions of the gossip
 */
CREATE TABLE ggdb.version (
	id			SERIAL PRIMARY KEY,
	gossip_id		int references ggdb.gossip(id) on delete no action,
 	title			varchar(128) NOT NULL,
	body			text NOT NULL,
	creation_time		timestamp,
	is_current		boolean DEFAULT TRUE
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
	name	varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') UNIQUE NOT NULL
);

/*
 * TAGGING:  Represents tag
 */
CREATE TABLE ggdb.tag (
	id		SERIAL PRIMARY KEY,
	bundle_id	int references ggdb.bundle(id) on delete no action,
	name		varchar(64) check (name ~* '^[abcdefghijklmnopqrstuvwxyz .]+$') UNIQUE NOT NULL
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


/* Best Match Functions*/
ALTER TABLE ggdb.reporter ADD COLUMN reporter_fname_bucket_for_index tsvector;
UPDATE ggdb.reporter SET reporter_fname_bucket_for_index =
	to_tsvector('english', first_name); 


ALTER TABLE ggdb.version ADD COLUMN gossip_body_bucket_for_index tsvector;
UPDATE ggdb.version SET gossip_body_bucket_for_index =
	to_tsvector('english', body);

--CREATE INDEX doc_index       ON txt.doc USING gin(text_bucket_for_index);
CREATE INDEX reporter_fname_index ON ggdb.reporter USING gin(reporter_fname_bucket_for_index);
CREATE INDEX gossip_body_index ON ggdb.version USING gin(gossip_body_bucket_for_index);


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
DECLARE
	reporterid integer;
BEGIN

	IF p_username IN (select R.username from ggdb.reporter R where R.username = p_username) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter username >%< already exists', p_username;
	END IF;

	INSERT INTO ggdb.reporter (username, first_name, last_name, commission) VALUES
		(p_username, p_first, p_last, p_comm);

	SELECT currval('ggdb.reporter_id_seq') into reporterid;

	PERFORM ggdb.update_revision_history ('Reporter ID ' || reporterid || ' added');
	
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
DECLARE
	reporterid integer;
BEGIN

	IF p_username NOT IN (select R.username from ggdb.reporter R where R.username = p_username) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter username >%< does not exist', p_username;
	END IF;

	Update ggdb.reporter SET first_name=p_first, last_name=p_last, commission=p_comm
	WHERE username=p_username;

	SELECT r.id into reporterid from ggdb.reporter r WHERE username=p_username;

	PERFORM ggdb.update_revision_history ('Reporter ID ' || reporterid || ' updated');

 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of reporters based off of username
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_reporter_by_id (
		p_username varchar(64)
)
RETURNS SETOF ggdb.Reporter AS $PROC$
DECLARE
	reporterid varchar(64);
	row2 RECORD;
	reporterrow ggdb.Reporter%ROWTYPE;
BEGIN
	select r.username into reporterid from ggdb.reporter r where r.username = p_username;

	IF p_username NOT IN (select R.username from ggdb.reporter R) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter  username >%< does not exist', p_username;
	END IF;

	FOR row2 IN SELECT * from ggdb.reporter R where r.username = p_username
	LOOP

		reporterrow.id := row2.id;
		reporterrow.username := row2.username;
		reporterrow.first_name := row2.first_name;
		reporterrow.last_name := row2.last_name;
		reporterrow.commission := row2.commission;

		RETURN NEXT reporterrow;

	END LOOP;
	RETURN;
	/* Call Revision History Funciton Here
	*/ 
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of reporters based off of first name
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_reporter_by_fname (
		p_first varchar(64)
)
RETURNS SETOF ggdb.Reporter AS $PROC$
DECLARE
	reporterid integer;
	row2 RECORD;
	reporterrow ggdb.Reporter%ROWTYPE;
BEGIN
	select r.id into reporterid from ggdb.reporter r where r.first_name = p_first;

	IF p_first NOT IN (select R.first_name from ggdb.reporter R) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter first name >%< does not exist', p_first;
	END IF;

	FOR row2 IN SELECT * from ggdb.reporter R where r.first_name = p_first
	LOOP

		reporterrow.id := row2.id;
		reporterrow.username := row2.username;
		reporterrow.first_name := row2.first_name;
		reporterrow.last_name := row2.last_name;
		reporterrow.commission := row2.commission;

		RETURN NEXT reporterrow;

	END LOOP;
	RETURN;

 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of reporters based off of last name
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_reporter_by_lname (
		p_last varchar(64)
)
RETURNS SETOF ggdb.Reporter AS $PROC$
DECLARE
	row2 RECORD;
	reporterrow ggdb.Reporter%ROWTYPE;
BEGIN

	IF p_last NOT IN (select R.last_name from ggdb.reporter R) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter last name >%< does not exist', p_last;
	END IF;

	FOR row2 IN SELECT * from ggdb.reporter R where r.last_name = p_last
	LOOP

		reporterrow.id := row2.id;
		reporterrow.username := row2.username;
		reporterrow.first_name := row2.first_name;
		reporterrow.last_name := row2.last_name;
		reporterrow.commission := row2.commission;

		RETURN NEXT reporterrow;

	END LOOP;
	RETURN;
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of reporters based off of commission
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_reporter_by_comm (
		p_comm money
)
RETURNS SETOF ggdb.Reporter AS $PROC$
DECLARE
	row2 RECORD;
	reporterrow ggdb.Reporter%ROWTYPE;
BEGIN

	IF p_comm NOT IN (select R.commission from ggdb.reporter R) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter commission >%< does not exist', p_comm;
	END IF;

	FOR row2 IN SELECT * from ggdb.reporter R where r.commission = p_comm
	LOOP

		reporterrow.id := row2.id;
		reporterrow.username := row2.username;
		reporterrow.first_name := row2.first_name;
		reporterrow.last_name := row2.last_name;
		reporterrow.commission := row2.commission;

		RETURN NEXT reporterrow;

	END LOOP;
	RETURN;
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT: Best match of reporter first name
 * @Author: Xing
 */

CREATE OR REPLACE FUNCTION ggdb.bestmatch_reporter (
		p_first varchar(64)
)
RETURNS TABLE (
	id		integer,
	username		varchar(64),
	first_name		varchar(64), 
	last_name 		varchar(64),
	commission		money
	) AS $PROC$
BEGIN
	RETURN QUERY select r.id, r.username, r.first_name, r.last_name,r.commission from ggdb.reporter r where to_tsvector (r.first_name) @@ to_tsquery(p_first);
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;

/*
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
DECLARE
	celebrityid integer;
BEGIN

	--DOCUMENT: Create Nick_Name for table celebrity if the user doesn't specify the nickname
	IF p_nick IS NULL THEN
		p_nick := p_first || ' ' || p_last;
	END IF;

	IF p_nick IN (select C.nick_name from ggdb.celebrity C where c.nick_name = p_nick) THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< already exists', p_first || ' ' ||p_last;
	END IF;

	INSERT INTO ggdb.celebrity (first_name, last_name, nick_name, birthdate) VALUES
		(p_first, p_last, p_nick, p_bday);

	SELECT currval('ggdb.celebrity_id_seq') into celebrityid;

	PERFORM ggdb.update_revision_history ('Celebrity ID ' || celebrityid || ' added');

END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Update Celebrity
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.update_celebrity (
		p_first varchar(64)
		, p_last varchar(64)
		, p_nick varchar(64)
		, p_bday date
)
RETURNS void AS $PROC$
DECLARE
	celebrityid integer;
BEGIN

	IF p_nick NOT IN (select c.nick_name from ggdb.celebrity c where c.nick_name = p_nick) THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity nickname >%< does not exist', p_nick;
	END IF;

	Update ggdb.celebrity SET first_name=p_first, last_name=p_last, birthdate=p_bday
	WHERE nick_name=p_nick;

	SELECT c.id into celebrityid from ggdb.celebrity c WHERE nick_name=p_nick;

	PERFORM ggdb.update_revision_history ('Celebrity ID ' || celebrityid || ' updated');
	
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of celebrities based off of nickname
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_celebrity_by_id (
		p_nick varchar(64)
)
RETURNS SETOF ggdb.celebrity AS $PROC$
DECLARE
	row2 RECORD;
	celebrityrow ggdb.celebrity%ROWTYPE;
BEGIN

	IF p_nick NOT IN (select c.nick_name from ggdb.celebrity c) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter nick_name >%< does not exist', p_nick;
	END IF;

	FOR row2 IN SELECT * from ggdb.celebrity c where c.nick_name = p_nick
	LOOP

		celebrityrow.id := row2.id;
		celebrityrow.first_name := row2.first_name;
		celebrityrow.last_name := row2.last_name;
		celebrityrow.nick_name := row2.nick_name;
		celebrityrow.birthdate := row2.birthdate;
		RETURN NEXT celebrityrow;

	END LOOP;
	RETURN;

 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of celebrities based off of first name
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_celebrity_by_fname (
		p_first varchar(64)
)
RETURNS SETOF ggdb.celebrity AS $PROC$
DECLARE
	row2 RECORD;
	celebrityrow ggdb.celebrity%ROWTYPE;
BEGIN

	IF p_first NOT IN (select c.first_name from ggdb.celebrity c) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter first name >%< does not exist', p_first;
	END IF;

	FOR row2 IN SELECT * from ggdb.celebrity c where c.first_name = p_first
	LOOP

		celebrityrow.id := row2.id;
		celebrityrow.first_name := row2.first_name;
		celebrityrow.last_name := row2.last_name;
		celebrityrow.nick_name := row2.nick_name;
		celebrityrow.birthdate := row2.birthdate;
		RETURN NEXT celebrityrow;

	END LOOP;
	RETURN;

 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of celebrities based off of last name
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_celebrity_by_lname (
		p_last varchar(64)
)
RETURNS SETOF ggdb.celebrity AS $PROC$
DECLARE
	row2 RECORD;
	celebrityrow ggdb.celebrity%ROWTYPE;
BEGIN

	IF p_last NOT IN (select c.last_name from ggdb.celebrity c) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter last name >%< does not exist', p_last;
	END IF;

	FOR row2 IN SELECT * from ggdb.celebrity c where c.last_name = p_last
	LOOP

		celebrityrow.id := row2.id;
		celebrityrow.first_name := row2.first_name;
		celebrityrow.last_name := row2.last_name;
		celebrityrow.nick_name := row2.nick_name;
		celebrityrow.birthdate := row2.birthdate;
		RETURN NEXT celebrityrow;

	END LOOP;
	RETURN;

 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of reporters based off of commission
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.get_celebrity_by_bday (
		p_bday date
)
RETURNS SETOF ggdb.celebrity AS $PROC$
DECLARE
	row2 RECORD;
	celebrityrow ggdb.celebrity%ROWTYPE;
BEGIN

	IF p_bday NOT IN (select c.birthdate from ggdb.celebrity c) THEN
		RAISE EXCEPTION 'gossip guy app:  reporter brithdate >%< does not exist', p_bday;
	END IF;

	FOR row2 IN SELECT * from ggdb.celebrity c where c.birthdate = p_bday
	LOOP

		celebrityrow.id := row2.id;
		celebrityrow.first_name := row2.first_name;
		celebrityrow.last_name := row2.last_name;
		celebrityrow.nick_name := row2.nick_name;
		celebrityrow.birthdate := row2.birthdate;

		RETURN NEXT celebrityrow;

	END LOOP;
	RETURN;

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

	INSERT INTO ggdb.gossip (publish_date, is_active) VALUES (NULL, FALSE);

	select currval('ggdb.gossip_id_seq') into gossipid;

	INSERT INTO ggdb.version (gossip_id, title, body, creation_time, is_current) VALUES (
		gossipid
		, p_title
		, p_body
		, clock_timestamp()
		, TRUE
	);

	INSERT INTO ggdb.gossip_node (gossip_id, node_id, start_time) VALUES
		(
		gossipid, 
		nodeid,
		clock_timestamp()
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

	PERFORM ggdb.update_revision_history ('Gossip ID ' || gossipid || ' added');
	
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Update Gossip
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.update_gossip (
		p_gossipid integer
		, p_title varchar(128) 
		, p_body text
		, p_isactive boolean
)
RETURNS void AS $PROC$
DECLARE
	workflowid INTEGER;
	nodeid INTEGER;
	gossipid INTEGER;
	versionid INTEGER;
	p_publishdate timestamp;
BEGIN

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	UPDATE ggdb.version v SET
		is_current = FALSE
		WHERE v.gossip_id = gossipid;

	INSERT INTO ggdb.version (gossip_id, title, body, creation_time, is_current) VALUES (
		gossipid
		, p_title
		, p_body
		, clock_timestamp()
		, TRUE
	);
	SELECT currval('ggdb.version_id_seq') into versionid;
	
	IF (p_isactive) THEN
		p_publishdate = clock_timestamp();
	ELSE p_publishdate = NULL;
	END IF;

	UPDATE ggdb.gossip g SET
		publish_date = p_publishdate, is_active = p_isactive
		WHERE g.id = gossipid;

	PERFORM ggdb.update_revision_history ('Gossip ID ' || gossipid || ' updated; ' || 'Version ID ' || versionid || ' added');

END;
$PROC$ LANGUAGE plpgsql;


/*
 * DOCUMENT:  Delete Gossip
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.delete_gossip (
		p_gossipid integer
)
RETURNS void AS $PROC$
DECLARE
	gossipid INTEGER;
BEGIN

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	DELETE FROM ggdb.gossip_node gn WHERE gn.gossip_id = gossipid;
	DELETE FROM ggdb.version v WHERE v.gossip_id = gossipid;
	DELETE FROM ggdb.reporter_gossip rg WHERE rg.gossip_id = gossipid;
	DELETE FROM ggdb.celebrity_gossip cg WHERE cg.gossip_id = gossipid;
	DELETE FROM ggdb.gossip_tag gt WHERE gt.gossip_id = gossipid;
	DELETE FROM ggdb.gossip g WHERE g.id = gossipid;

	PERFORM ggdb.update_revision_history ('Gossip ID ' || gossipid || ' deleted and all associated links');
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get latest version of gossip from reporter, when given reporter_name, and active/inactive value
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_gossip_by_reporter (
		p_reporter varchar(64),
		p_isactive boolean
)
RETURNS TABLE (
	gossip_id		integer,
	version_title		varchar(128),
	version_body		text, 
	version_ctime 		timestamp,
	node_name		varchar(64)
	) AS $PROC$
DECLARE
	reporterid integer;
BEGIN

	select ggdb.reporter.id into reporterid from ggdb.reporter where ggdb.reporter.username = p_reporter;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  reporter >%< not found', p_reporter;
	END IF;

	RETURN QUERY (
		select g.id
			, v.title
			, v.body
			, v.creation_time
			, n.name
			from ggdb.gossip g
			inner join ggdb.version v on v.gossip_id = g.id
			inner join ggdb.reporter_gossip rg on rg.gossip_id = g.id
			inner join ggdb.reporter r on r.id = rg.reporter_id
			inner join ggdb.gossip_node gn on gn.gossip_id = g.id
			inner join ggdb.node n on gn.node_id = n.id
			where (g.is_active = p_isactive) and (v.is_current = 't') and (r.username = p_reporter)
			);
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get latest version of gossip about celebrity, when given celebrity nickname, and active/inactive value
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_gossip_by_celebrity (
		p_celebrity varchar(128),
		p_isactive boolean
)
RETURNS TABLE (
	gossip_id		integer,
	version_title		varchar(128),
	version_body		text, 
	version_ctime 		timestamp,
	node_name		varchar(64)
	) AS $PROC$
DECLARE
	celebrityid integer;
BEGIN

	select ggdb.celebrity.id into celebrityid from ggdb.celebrity where ggdb.celebrity.nick_name = p_celebrity;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< not found', p_celebrity;
	END IF;

	RETURN QUERY (
		select g.id
			, v.title
			, v.body
			, v.creation_time
			, n.name
			from ggdb.gossip g
			inner join ggdb.version v on v.gossip_id = g.id
			inner join ggdb.celebrity_gossip cg on cg.gossip_id = g.id
			inner join ggdb.celebrity c on c.id = cg.celebrity_id
			inner join ggdb.gossip_node gn on gn.gossip_id = g.id
			inner join ggdb.node n on gn.node_id = n.id
			where (g.is_active = p_isactive) and (v.is_current = 't') and (c.nick_name = p_celebrity)
			);
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get latest version of gossip about tag, when given tag name, and active/inactive value
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_gossip_by_tag (
		p_tag varchar(64),
		p_isactive boolean
)
RETURNS TABLE (
	gossip_id		integer,
	version_title		varchar(128),
	version_body		text, 
	version_ctime 		timestamp,
	node_name		varchar(64)
	) AS $PROC$
DECLARE
	tagid integer;
BEGIN

	select ggdb.tag.id into tagid from ggdb.tag where ggdb.tag.name = p_tag;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< not found', p_tag;
	END IF;

	RETURN QUERY (
		select g.id
			, v.title
			, v.body
			, v.creation_time
			, n.name
			from ggdb.gossip g
			inner join ggdb.version v on v.gossip_id = g.id
			inner join ggdb.gossip_tag gt on gt.gossip_id = g.id
			inner join ggdb.tag t on t.id = gt.tag_id
			inner join ggdb.gossip_node gn on gn.gossip_id = g.id
			inner join ggdb.node n on gn.node_id = n.id
			where (g.is_active = p_isactive) and (v.is_current = 't') and (t.name = p_tag)
			);
 END;
$PROC$ LANGUAGE plpgsql;


/*
 * DOCUMENT:  Get latest version of gossip when given bundle name, and active/inactive value; 
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_gossip_by_bundle (
		p_bundle varchar(64),
		p_isactive boolean
)
RETURNS TABLE (
	gossip_id		integer,
	version_title		varchar(128),
	version_body		text, 
	version_ctime 		timestamp,
	node_name		varchar(64)
	) AS $PROC$
DECLARE
	bundleid integer;
BEGIN

	select ggdb.bundle.id into bundleid from ggdb.bundle where ggdb.bundle.name = p_bundle;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  bundle >%< not found', p_bundle;
	END IF;

	RETURN QUERY (
		select distinct g.id
			, v.title
			, v.body
			, v.creation_time
			, n.name
			from ggdb.gossip g
			inner join ggdb.version v on v.gossip_id = g.id
			inner join ggdb.gossip_tag gt on gt.gossip_id = g.id
			inner join ggdb.tag t on t.id = gt.tag_id
			inner join ggdb.gossip_node gn on gn.gossip_id = g.id
			inner join ggdb.node n on gn.node_id = n.id
			where (g.is_active = p_isactive) and (v.is_current = 't') and (t.bundle_id = bundleid)
			);
 END;
$PROC$ LANGUAGE plpgsql;


/*
 * DOCUMENT:  Get list of versions of gossip when given id
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_gossip_by_id (
		p_gossipid integer
)
RETURNS TABLE (
	version_id	integer,
	version_title	varchar(128),
	version_body	text, 
	version_ctime	timestamp,
	is_current	boolean
	) AS $PROC$
DECLARE
	gossipid integer;
BEGIN

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	RETURN QUERY (SELECT v.id, v.title, v.body, v.creation_time, v.is_current FROM ggdb.version v WHERE v.gossip_id = gossipid ORDER BY v.is_current desc, v.creation_time desc);
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Get list of status of gossip
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_gossip_status (
		p_gossipid integer
)
RETURNS TABLE (
	node_shortname  varchar(3),
	node_name 	varchar(64),
	node_type	ggdb.nodetype,
	start_time	timestamp
	) AS $PROC$
DECLARE
	gossipid integer;
BEGIN

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	RETURN QUERY (
		select n.shortname, n.name, n.nodetype, gn.start_time
			from ggdb.gossip g
			inner join ggdb.gossip_node gn on gn.gossip_id = g.id
			inner join ggdb.node n on gn.node_id = n.id
			where g.id = gossipid
	);
 END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  change gossip status.  Next status must be next step in workflow.
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.change_gossip_status (
		p_gossipid INTEGER
		,  p_nodeshortname varchar(3)		
		,  p_isactive boolean	
)
RETURNS void AS $PROC$
DECLARE
	gossipid INTEGER;
	oldnodeid INTEGER;
	newnodeid INTEGER;
BEGIN
	SELECT g.id, n.id INTO gossipid, oldnodeid 
		FROM ggdb.gossip g 
		INNER JOIN ggdb.gossip_node gn ON gn.gossip_id = g.id
		INNER JOIN ggdb.node n ON gn.node_id = n.id
		WHERE g.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	SELECT n.id INTO newnodeid
		FROM ggdb.node n
		WHERE n.shortname = p_nodeshortname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the node >%< not found', p_nodeshortname;
	END IF;	

	IF newnodeid NOT IN (select distinct tonode_id from ggdb.link l where l.fromnode_id = oldnodeid) THEN
		RAISE EXCEPTION 'gossip guy app:  the node >%< is not the next step in workflow', p_nodeshortname;
	END IF;	

	INSERT INTO ggdb.gossip_node (gossip_id, node_id, start_time) VALUES
		(
		gossipid
		, newnodeid
		, clock_timestamp()
		);

	IF p_isactive THEN
		UPDATE ggdb.gossip g SET
			publish_date = clock_timestamp(), is_active = p_isactive
			WHERE g.id = gossipid;
	END IF;

	PERFORM ggdb.update_revision_history ('Gossip ID ' || gossipid || ' status updated to ' || (select n.name from ggdb.node n where n.id = newnodeid));

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
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
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
		RAISE EXCEPTION 'gossip guy app:  celebrity >%< not found', p_celebritynickname;
	END IF;

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	INSERT INTO ggdb.celebrity_gossip(celebrity_id, gossip_id) VALUES
		(
		celebrityid
		, gossipid
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT:  Add Tag To Gossip
 * @Author: Katie
 */
CREATE OR REPLACE FUNCTION ggdb.add_tag_to_gossip (
		  p_tagname VARCHAR (64)
		, p_gossipid INTEGER
)
RETURNS void AS $PROC$
DECLARE
	tagid INTEGER;
	gossipid INTEGER;
BEGIN
	SELECT ggdb.tag.id INTO tagid FROM ggdb.tag WHERE ggdb.tag.name = p_tagname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< not found', p_tagname;
	END IF;

	SELECT ggdb.gossip.id INTO gossipid FROM ggdb.gossip WHERE ggdb.gossip.id = p_gossipid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  the gossip id >%< not found', p_gossipid;
	END IF;	

	INSERT INTO ggdb.gossip_tag(tag_id, gossip_id) VALUES
		(
		tagid
		, gossipid
		);
END;
$PROC$ LANGUAGE plpgsql;

/*
 * DOCUMENT: Best match of gossip
 * @Author: Xing
 */
CREATE OR REPLACE FUNCTION ggdb.bestmatch_gossip (
		keyword varchar(64)
)
RETURNS TABLE (
	title		varchar(128),
	body		text,
	creation_time	timestamp,
	is_current		boolean
	) AS $PROC$
BEGIN
	RETURN QUERY select v.title, v.body, v.creation_time, v.is_current from ggdb.version v where to_tsvector(body) @@ to_tsquery(keyword);
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;


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
	p_bname			varchar(64),
	p_tname			varchar(64)
)
RETURNS void AS $PROC$
DECLARE
	bid		INTEGER;
BEGIN
	SELECT B.id INTO bid FROM ggdb.bundle B WHERE B.name = p_bname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'gossip guy app:  bundle >%< not found', p_bname;
		-- Possible to create a bundle if it does not exist... better option?
	END IF;

	IF p_tname IN (select T.name from ggdb.tag T) THEN
		RAISE EXCEPTION 'gossip guy app:  tag >%< already exists', p_tname;
	END IF;

	INSERT INTO ggdb.tag (bundle_id, name) VALUES
		(bid, p_tname);
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
 * UTILITY:  records major system changes into revision history
 * @Author: katie
 */
CREATE OR REPLACE FUNCTION ggdb.update_revision_history (
		p_message		text
)
RETURNS void AS $PROC$
BEGIN
	INSERT INTO ggdb.revision_history (time, message) VALUES
		(clock_timestamp(), p_message);
END;
$PROC$ LANGUAGE plpgsql;

 /*
 * UTILITY:  returns revision history after the given timestamp
 * @Author: katie
 */
CREATE OR REPLACE FUNCTION ggdb.get_revision_history (
	p_timestamp	timestamp
)
RETURNS TABLE (
	thetime  	timestamp,
	message		text 
) AS $PROC$
DECLARE
BEGIN

	RETURN QUERY (select rh.time, rh.message from ggdb.revision_history rh where rh.time > p_timestamp);
END;
$PROC$ LANGUAGE plpgsql;

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
select ggdb.update_reporter('katie', 'kt', 'ho', '$10000000.00');
select ggdb.add_celebrity('Kirsten', 'Stewart', 'kstew', '2012-03-30');
select ggdb.create_gossip('def', 'dra', 'katie', 'kstew', 'Kstew is in another scandal!', 'kstew tweets about whether she should get plastic surgery');
select ggdb.add_reporter_to_gossip('xingxu', 1);
select ggdb.add_celebrity('Robert', 'Pattinson', 'RPat', '2013-05-30');
select ggdb.update_celebrity('Robbie', 'Pattinson', 'RPat', '2013-05-30');
select ggdb.add_celebrity_to_gossip('RPat', 1);
SELECT ggdb.create_bundle('relationship');
SELECT ggdb.create_tag('relationship', 'RPatKStew');
SELECT ggdb.create_tag('relationship', 'Brangelina');
select ggdb.add_tag_to_gossip('RPatKStew', 1);
select ggdb.add_tag_to_gossip('Brangelina', 1);
select ggdb.add_celebrity('Kim', 'Kardashian', NULL, '1980-05-30');
select ggdb.add_celebrity('Cee Lo', 'Green', 'Cee Lo', '1970-05-30');
select ggdb.add_celebrity('Brad', 'Pitt', 'Brad Pitt', '1976-05-30');
select ggdb.add_celebrity('Peter', 'Griffen', NULL, '1970-05-30');
select ggdb.add_celebrity('Ben', 'Haggerty', 'Macklemore', '1970-05-30');
select ggdb.add_celebrity('Will', 'Smith', 'Fresh Prince', '1970-05-30');
select ggdb.add_celebrity('LeBron', 'James', NULL, '1970-05-30');
select ggdb.add_celebrity('Lindsay', 'Lohan', 'LiLo', '1970-05-30');
select ggdb.add_celebrity('Charlie', 'Sheen', 'The Masheen', '1970-05-30');
select ggdb.add_reporter('Cory', 'Cory', 'Eurom', '$50000.00');
select ggdb.add_reporter('Bob', 'Bobby', 'Brady', '$50000.00');
select ggdb.add_reporter('JBieber', 'Justin', 'Bieber', '$50000.00');
select ggdb.add_reporter('JTim', 'Justin', 'Timberlake', '$50000.00');

select ggdb.update_gossip('1', 'Adam Levine hates his country', 'Adam Levine declared his hate for America on The Voice last night.', FALSE);
select ggdb.update_gossip('1', 'Testing', 'testing update.', 'f');
select ggdb.change_gossip_status('1', 'pub', 'true');

select * from ggdb.revision_history;


/*
 ********************************************************************************
    UTILITY:  IMPORT DATA FROM FILES:   
 ********************************************************************************
 */

/*
 *  Import data
COPY ggdb.celebrity (nick_name, first_name, last_name, birthdate) FROM '/nfs/bronfs/uwfs/dw00/d12/cte13/gg.git/celebNames.txt';

COPY ggdb.reporter (username, first_name, last_name, commission)FROM '/nfs/bronfs/uwfs/dw00/d12/cte13/gg.git/reporterNames.txt';

COPY ggdb.gossip (publish_date) FROM '/nfs/bronfs/uwfs/dw00/d12/cte13/gg.git/gossipTable.txt';

COPY ggdb.gossip_node (gossip_id, node_id, start_time) FROM '/nfs/bronfs/uwfs/dw00/d12/cte13/gg.git/gossipNode.txt';

COPY ggdb.version (gossip_id, title, body) FROM '/nfs/bronfs/uwfs/dw00/d12/cte13/gg.git/versionGossip.txt';
*/


COPY ggdb.celebrity (nick_name, first_name, last_name, birthdate) FROM '/nfs/bronfs/uwfs/dw00/d41/ktyunho/gossipguy/celebNames.txt';

COPY ggdb.reporter (username, first_name, last_name, commission)FROM '/nfs/bronfs/uwfs/dw00/d41/ktyunho/gossipguy/reporterNames.txt';

COPY ggdb.gossip (publish_date) FROM '/nfs/bronfs/uwfs/dw00/d41/ktyunho/gossipguy/gossipTable.txt';

COPY ggdb.gossip_node (gossip_id, node_id, start_time) FROM '/nfs/bronfs/uwfs/dw00/d41/ktyunho/gossipguy/gossipNode.txt';

COPY ggdb.version (gossip_id, title, body) FROM '/nfs/bronfs/uwfs/dw00/d41/ktyunho/gossipguy/versionGossip.txt';



 /*  Import data to Xing's server
COPY ggdb.celebrity (nick_name, first_name, last_name, birthdate) FROM '/nfs/bronfs/uwfs/hw00/d74/xingxu/gossipguy/celebNames.txt';

COPY ggdb.reporter (username, first_name, last_name, commission)FROM '/nfs/bronfs/uwfs/hw00/d74/xingxu/gossipguy/reporterNames.txt';

COPY ggdb.gossip (publish_date) FROM '/nfs/bronfs/uwfs/hw00/d74/xingxu/gossipguy/gossipTable.txt';

COPY ggdb.gossip_node (gossip_id, node_id, start_time) FROM '/nfs/bronfs/uwfs/hw00/d74/xingxu/gossipguy/gossipNode.txt';

COPY ggdb.version (gossip_id, title, body) FROM '/nfs/bronfs/uwfs/hw00/d74/xingxu/gossipguy/versionGossip.txt';
*/



/*
 * TESTING FUNCTIONS
 *
 */
select ggdb.get_gossip_status ('1');

select ggdb.get_gossip_by_reporter ('katie', 'f');

select ggdb.get_gossip_by_celebrity ('RPat', 'f');

select ggdb.get_gossip_by_tag ('RPatKStew', 'f');

select ggdb.get_gossip_by_tag ('Brangelina', 'f');

select ggdb.get_gossip_by_bundle ('relationship', 'f');



/*
select ggdb.change_gossip_status('1', 'pub', 'true');


select * from ggdb.gossip;


select ggdb.delete_gossip('1');
select ggdb.get_gossip_by_id ('1');


select * from ggdb.gossip g
	inner join ggdb.version v on g.id = v.gossip_id;
select * from ggdb.version v

select ggdb.update_reporter('katie', 'Bobby', 'Brady', '$5.00');
select ggdb.add_tag_to_gossip('RPatKStew', 1);
select ggdb.add_tag_to_gossip('Brangelina', 1);

select * from ggdb.reporter;
select * from ggdb.gossip_tag;
select * from ggdb.gossip;

<<<<<<< HEAD
select * from ggdb.gossip;
=======
select * from ggdb.gossip_node;
select * from ggdb.reporter_gossip;
select * from ggdb.celebrity_gossip;
select * from ggdb.gossip_tag;

select * from ggdb.gossip_tag gt
	inner join ggdb.tag t on gt.tag_id = t.id;
select * from ggdb.reporter_gossip rg
	inner join ggdb.reporter r on rg.reporter_id = r.id;
select * from ggdb.celebrity_gossip rg
	inner join ggdb.celebrity c on rg.celebrity_id = c.id;
		
>>>>>>> parent of 6c1e62e... Tested add_celebrity and update_celebrity

select * from ggdb.version v;

select * from ggdb.version v order by v.creation_time limit 10
select * from ggdb.gossip_node;

select ggdb.get_workflows();
select ggdb.get_nodes('X');

select ggdb.drop_workflow ('A1');

select ggdb.get_children('X', 'rco');

select ggdb.get_node_by_id(24);

select ggdb.find_loose_nodes('X');

select * from ggdb.link;
select * from ggdb.node;
*/