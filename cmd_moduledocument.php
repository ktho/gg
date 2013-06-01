<?php
/*
 * filename: cmd_document.php 
 */


//	foreach $cmd_list as $t {
//
//
// }

/*
 * This function dispatches a document command and its parameters to the corresponding function 
 */
function dispatchDocumentCmd($cmd, $cmd_list) 
{
	global $gResult;
	$status = cCmdStatus_NOT_FOUND;
	
	$cmd = $cmd_list[0];
	if (($cmd != "reporter") && ($cmd != "celebrity") && ($cmd != "gossip")) {
		$status = cCmdStatus_NOT_FOUND; 
		return $status;
		}
	
	if ($cmd == "reporter") { 

		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}
	
		if ($arg1 == "add") {
			$status = reporter_add($cmd_list);
		}
		elseif ($arg1 == "update") {
		$status = reporter_update($cmd_list);
		}
		elseif ($arg1 == "del") {
			$status = reporter_del($cmd_list);
		}
		elseif ($arg1 == "get") {
			$status = reporter_get($cmd_list);
		}
		else {
			$status = cCmdStatus_NOT_FOUND; 
		}
	return $status;
	}

	if ($cmd == "celebrity") { 

		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}
	
		if ($arg1 == "add") {
			$status = celebrity_add($cmd_list);
		}
		elseif ($arg1 == "update") {
		$status = celebrity_update($cmd_list);
		}
		elseif ($arg1 == "get") {
		$status = celebrity_get($cmd_list);
		}
		else {
			$status = cCmdStatus_NOT_FOUND; 
		}
	return $status;
	}

	if ($cmd == "gossip") { 

		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}

		if ($arg1 == "create") {
			$status = gossip_create($cmd_list);
		}
		else if ($arg1 == "update") {
			$status = gossip_update($cmd_list);
		}
		else if ($arg1 == "add") {
			$status = gossip_add($cmd_list);
		}
		else if ($arg1 == "del") {
			$status = gossip_delete($cmd_list);
		}
		else if ($arg1 == "list") {
			$status = gossip_list($cmd_list);
		}
		else if ($arg1 == "listby") {
			$status = gossip_listby($cmd_list);
		}
		else if ($arg1 == "getstatus") {
			$status = gossip_getstatus($cmd_list);
		}
		else if ($arg1 == "changestatus") {
			$status = gossip_changestatus($cmd_list);
		}
		else {
			$status = cCmdStatus_NOT_FOUND; 

		}
	return $status;
	}
}


/*
 * Add reporter
 * Author: Xing 5/23/13 9:25pm
 */
function reporter_add($cmd_list) {
	global $gResult;

	$id = getValue("-id",$cmd_list);
	$f = getValue("-f",$cmd_list); 
	$l = getValue("-l",$cmd_list); 
	$c = getValue("-c",$cmd_list); 

	if (($id == NULL) || ($f == NULL)|| ($l == NULL)|| ($c == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.add_reporter ('%s', '%s', '%s', '%f');", $id, $f, $l, $c);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Update reporter
 * Author: Xing 5/28/13 10:25pm
 */
function reporter_update($cmd_list) {
	global $gResult;

	$id = getValue("-id",$cmd_list);
	$f = getValue("-f",$cmd_list); 
	$l = getValue("-l",$cmd_list); 
	$c = getValue("-c",$cmd_list); 

	if (($id == NULL) || ($f == NULL)|| ($l == NULL)|| ($c == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.update_reporter ('%s', '%s', '%s', '%f');", $id, $f, $l, $c);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Get reporter(s) on different criteria
 * Author: Xing 6/1/13 10:25am
 */
function reporter_get($cmd_list) {
	global $gResult;

	$id = getValue("-id",$cmd_list);
	$f = getValue("-f",$cmd_list); 
	$l = getValue("-l",$cmd_list); 
	$c = getValue("-c",$cmd_list); 

	if (($id == NULL) && ($f == NULL)&& ($l == NULL)&& ($c == NULL)) {
		return cCmdStatus_ERROR; 
	}
	else if (($id != NULL) && ($f == NULL) && ($l == NULL) && ($c == NULL)) {
		$sql = sprintf("select * from ggdb.get_reporter_by_id ('%s');", $id);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else if (($id == NULL) && ($f != NULL) && ($l == NULL) && ($c == NULL)) {
		$sql = sprintf("select * from ggdb.get_reporter_by_fname ('%s');", $f);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else if (($id == NULL) && ($f == NULL) && ($l != NULL) && ($c == NULL)) {
		$sql = sprintf("select * from ggdb.get_reporter_by_lname ('%s');", $l);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else if (($id == NULL) && ($f != NULL) && ($l == NULL) && ($c != NULL)) {
		$sql = sprintf("select * from ggdb.get_reporter_by_comm ('%f');", $c);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else {
			$status = cCmdStatus_ERROR; 
		}

	$nl = "\n". $result . "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Add celebrity
 * Author: Xing 5/23/13 9:46pm
 */

function celebrity_add($cmd_list) {
	global $gResult;

	$f = getValue("-f",$cmd_list); 
	$l = getValue("-l",$cmd_list); 
	$n = getValue("-n",$cmd_list);
	$b = getValue("-b",$cmd_list); 

	if (($n == NULL) || ($f == NULL)|| ($l == NULL)|| ($b == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.add_celebrity ('%s', '%s', '%s', '%s');", $f, $l, $n, $b);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Add celebrity
 * Author: Xing 5/23/13 10:46pm
 */

function celebrity_update($cmd_list) {
	global $gResult;

	$f = getValue("-f",$cmd_list); 
	$l = getValue("-l",$cmd_list); 
	$n = getValue("-n",$cmd_list);
	$b = getValue("-b",$cmd_list); 

	if (($n == NULL) || ($f == NULL)|| ($l == NULL)|| ($b == NULL)) {
		return cCmdStatus_ERROR; 
	}

	$sql = sprintf("select ggdb.update_celebrity ('%s', '%s', '%s', '%s');", $f, $l, $n, $b);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Get reporter(s) on different criteria
 * Author: Xing 6/1/13 10:25am
 */
function celebrity_get($cmd_list) {
	global $gResult;
	$f = getValue("-f",$cmd_list); 
	$l = getValue("-l",$cmd_list);
	$n = getValue("-id",$cmd_list); 
	$b = getValue("-b",$cmd_list); 

	if (($n == NULL) && ($f == NULL)&& ($l == NULL)&& ($b == NULL)) {
		return cCmdStatus_ERROR; 
	}
	else if (($n != NULL) && ($f == NULL) && ($l == NULL) && ($b == NULL)) {
		$sql = sprintf("select * from ggdb.get_celebrity_by_id ('%s');", $n);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else if (($n == NULL) && ($f != NULL) && ($l == NULL) && ($b == NULL)) {
		$sql = sprintf("select * from ggdb.get_celebrity_by_fname ('%s');", $f);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else if (($n == NULL) && ($f == NULL) && ($l != NULL) && ($b == NULL)) {
		$sql = sprintf("select * from ggdb.get_celebrity_by_lname ('%s');", $l);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else if (($n == NULL) && ($f != NULL) && ($l == NULL) && ($b != NULL)) {
		$sql = sprintf("select * from ggdb.get_celebrity_by_bday ('%s');", $b);
		$result = runSetDbQuery($sql,"basicPrintLine");
	}
	else {
			$status = cCmdStatus_ERROR; 
		}

	$nl = "\n". $result . "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}



/*
 * Creates gossip
 */
function gossip_create($cmd_list) {
	global $gResult;

	$wf = getValue("-wf",$cmd_list);
	$sn = getValue("-sn",$cmd_list); 
	$r = getValue("-r",$cmd_list); 
	$c = getValue("-c",$cmd_list); 
	$t = getValue("-t",$cmd_list); 
	$b = getValue("-b",$cmd_list); 

	if (($wf == NULL) || ($sn == NULL)|| ($r == NULL)|| ($c == NULL)|| ($t == NULL)|| ($b == NULL)) {
		return cCmdStatus_ERROR; 
	}

	$sql = sprintf("select ggdb.create_gossip ('%s', '%s', '%s', '%s', '%s', '%s');", $wf, $sn, $r, $c, $t, $b);

	$result = runScalarDbQuery($sql);

	$nl = "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Updates version of gossip
 */
function gossip_update($cmd_list) {
	global $gResult;

	$gid = getValue("-gid",$cmd_list);
	$t = getValue("-t",$cmd_list); 
	$b = getValue("-b",$cmd_list); 
	$ac = getValue("-ac",$cmd_list); 

	if  (    ($gid == NULL)
			 || ($t == NULL)
			 || ($b == NULL)
			 || ($ac == NULL)	
		) {
		return cCmdStatus_ERROR; 
	}

	if ((strtolower($ac) == "true") || (strtolower($ac) == "t")) {
		$act = "t";
	} else {
		$act = "f";
	}

	$sql = sprintf("select ggdb.update_gossip ('%s', '%s', '%s', '%s');", $gid, $t, $b, $act);

	$result = runScalarDbQuery($sql);

	$nl = "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Deletes gossip
 */
function gossip_delete($cmd_list) {
	global $gResult;

	$gid = getValue("-gid",$cmd_list); 

	if  ($gid == NULL) {
		return cCmdStatus_ERROR; 
	}

	$sql = sprintf("select ggdb.delete_gossip ('%s');", $gid);

	$result = runScalarDbQuery($sql);

	$nl = "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * List all versions of gossip when given ID
 */
function gossip_list($cmd_list) {
	global $gResult;

	$gid = getValue("-gid",$cmd_list); 

	if  ($gid == NULL) {
		return cCmdStatus_ERROR; 
	}

	$sql = sprintf("select ggdb.get_gossip_by_id ('%s');", $gid);

	$result = runSetDbQuery($sql,"basicPrintLine");

	$nl = "\n". $result . "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * List latest version of gossip by reporter, celebrity, tag, or bundle.  
 */
function gossip_listby($cmd_list) {
	global $gResult;

	$r = getValue("-r",$cmd_list);
	$c = getValue("-c",$cmd_list);	
	$t = getValue("-t",$cmd_list); 
	$b = getValue("-b",$cmd_list); 
	$ac = getValue("-ac",$cmd_list); 

	if (($ac == null)
			|| (($r == null) 
					&& ($c == null)
					&& ($t == null)
					&& ($b == null))
		)  {
		return cCmdStatus_Error;
	}

	if ((strtolower($ac) == "true") || (strtolower($ac) == "t")) {
		$act = "t";
	} else {
		$act = "f";
	}

	if ($r != null) {
	$sql = sprintf("select ggdb.get_gossip_by_reporter ('%s', '%s');", $r, $act);
	}

	if ($c != null) {
	$sql = sprintf("select ggdb.get_gossip_by_celebrity ('%s', '%s');", $c, $act);
	}

	if ($t != null) {
	$sql = sprintf("select ggdb.get_gossip_by_tag ('%s', '%s');", $t, $act);
	}

	if ($b != null) {
	$sql = sprintf("select ggdb.get_gossip_by_bundle ('%s', '%s');", $b, $act);
	}

	$result = runSetDbQuery($sql,"basicPrintLine");
	$nl = "\n". $result . "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}


/*
 * Add reporter, celebrity, and tag to gossip
 */
function gossip_add($cmd_list) {
	global $gResult;

	$gid = getValue("-gid",$cmd_list); 
	if ($gid == null){
		return cCmdStatus_Error;
	}

	for ($k=0; $k < count($cmd_list); $k++) {
		if (
			(($cmd_list[$k] == "-r") 
			|| ($cmd_list[$k] == "-c") 
			|| ($cmd_list[$k] == "-t")) 
			&& ($k+1 < count($cmd_list))
			)
		    {
			
			$val = $cmd_list[$k+1];		
	
			if (($cmd_list[$k] == "-r") && ($val != NULL)) {
				$sql = sprintf("select ggdb.add_reporter_to_gossip ('%s', '%s');", $val, $gid);
				}

			if (($cmd_list[$k] == "-c") && ($val != NULL)) {
				$sql = sprintf("select ggdb.add_celebrity_to_gossip ('%s', '%s');", $val, $gid);
				}

			if (($cmd_list[$k] == "-t") && ($val != NULL)) {
				$sql = sprintf("select ggdb.add_tag_to_gossip ('%s', '%s');", $val, $gid);
				}
			
			$result = runScalarDbQuery($sql);
			$t = "\n"; 
			$gResult = $t . print_r($cmd_list,true);
		}
	}
	return cCmdStatus_OK; 
}


/*
 * List status of gossip
 */
function gossip_getstatus($cmd_list) {
	global $gResult;

	$gid = getValue("-gid",$cmd_list); 

	if  ($gid == NULL) {
		return cCmdStatus_ERROR; 
	}

	$sql = sprintf("select ggdb.get_gossip_status ('%s');", $gid);

	$result = runSetDbQuery($sql,"basicPrintLine");

	$nl = "\n". $result . "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * change status of gossip
 */
function gossip_changestatus($cmd_list) {
	global $gResult;

	$gid = getValue("-gid",$cmd_list); 
	$n = getValue("-n",$cmd_list); 
	$ac = getValue("-ac",$cmd_list); 

	if  (($gid == NULL) || ($n == null) || ($ac == null)){
		return cCmdStatus_ERROR; 
	}

	if ((strtolower($ac) == "true") || (strtolower($ac) == "t")) {
		$act = "t";
	} else {
		$act = "f";
	}

	$sql = sprintf("select ggdb.change_gossip_status ('%s', '%s', '%s');", $gid, $n, $act);

	$result = runScalarDbQuery($sql);

	$nl = "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}


?>