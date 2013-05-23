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

		// $arg1 = "";
		// if (count($cmd_list) > 1) {
		// $arg1 = $cmd_list[1];
		// }
	
		// if ($arg1 == "create") {
		// 	$status = wf_create($cmd_list);
		// }
		// elseif ($arg1 == "delete") {
		// $status = wf_delete($cmd_list);
		// }
		// elseif ($arg1 == "list") {
		// 	$status = wf_list($cmd_list);
		// }
		// else {
		// 	$status = cCmdStatus_NOT_FOUND; 

		}

	if ($cmd == "celebrity") { 

		// $arg1 = "";
		// if (count($cmd_list) > 1) {
		// $arg1 = $cmd_list[1];
		// }
	
		// if ($arg1 == "create") {
		// 	$status = wf_create($cmd_list);
		// }
		// elseif ($arg1 == "delete") {
		// $status = wf_delete($cmd_list);
		// }
		// elseif ($arg1 == "list") {
		// 	$status = wf_list($cmd_list);
		// }
		// else {
		// 	$status = cCmdStatus_NOT_FOUND; 

		}

	if ($cmd == "gossip") { 

		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}
	
		if ($arg1 == "create") {
			$status = gossip_create($cmd_list);
		}
/*
		elseif ($arg1 == "add") {
		$status = wf_delete($cmd_list);
		}
		elseif ($arg1 == "list") {
			$status = wf_list($cmd_list);
		}*/
		else {
			$status = cCmdStatus_NOT_FOUND; 

		}
	return $status;

	}


}

/*
 * Adds gossip
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

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}