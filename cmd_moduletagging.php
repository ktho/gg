<?php
/*
 * filename: cmd_tagging.php 
 */


// //	foreach $cmd_list as $t {
// //
// //
// // }

// /*
//  * This function dispatches a workflow command and its parameters to the corresponding function 
//  */
function dispatchTagCmd($cmd, $cmd_list) 
// {
// 	global $gResult;
// 	$status = cCmdStatus_NOT_FOUND;
	
// 	$cmd = $cmd_list[0];
// 	if ($cmd != "workflow") {
// 		$status = cCmdStatus_NOT_FOUND; 
// 		return $status;
// 	}

// 	$arg1 = "";
// 	if (count($cmd_list) > 1) {
// 		$arg1 = $cmd_list[1];
// 	}
	
// 	if ($arg1 == "create") {
// 		$status = wf_create($cmd_list);
// 	}
// 	elseif ($arg1 == "delete") {
// 		$status = wf_delete($cmd_list);
// 	}
// 	elseif ($arg1 == "list") {
// 		$status = wf_list($cmd_list);
// 	}
// 	else {
// 		$status = cCmdStatus_NOT_FOUND; 
// 	}
	
// 	return $status;
// }


// /*
//  * This function dispatches a node command and its parameters to the corresponding function 
//  */
// function dispatchNodeCmd($cmd, $cmd_list) 
// {
// 	global $gResult;
// 	$status = cCmdStatus_NOT_FOUND;
	
// 	$cmd = $cmd_list[0];
// 	if ($cmd != "node") {
// 		$status = cCmdStatus_NOT_FOUND; 
// 		return $status;
// 	}

// 	$arg1 = "";
// 	if (count($cmd_list) > 1) {
// 		$arg1 = $cmd_list[1];
// 	}
	
// 	if ($arg1 == "add") {
// 		$status = node_add($cmd_list);
// 	}
// 	elseif ($arg1 == "list") {
// 		$status = node_list($cmd_list);
// 	}
// 	elseif ($arg1 == "loose") {
// 		$status = node_loose($cmd_list);
// 	}
// 	else {
// 		$status = cCmdStatus_NOT_FOUND; 
// 	}
	
// 	return $status;
// }

// /*
//  * This function dispatches a link command and its parameters to the corresponding function 
//  */
// function dispatchLinkCmd($cmd, $cmd_list) 
// {
// 	global $gResult;
// 	$status = cCmdStatus_NOT_FOUND;
	
// 	$cmd = $cmd_list[0];
// 	if ($cmd != "link") {
// 		$status = cCmdStatus_NOT_FOUND; 
// 		return $status;
// 	}

// 	$arg1 = "";
// 	if (count($cmd_list) > 1) {
// 		$arg1 = $cmd_list[1];
// 	}
	
// 	if ($arg1 == "start") {
// 		$status = link_start($cmd_list);
// 	}
// 	elseif ($arg1 == "finish") {
// 		$status = link_finish($cmd_list);
// 	}
// 	elseif ($arg1 == "children") {
// 		$status = link_children($cmd_list);
// 	}
// 	elseif ((getValue("-wf",$cmd_list) != NULL) 
// 			|| (getValue("-from",$cmd_list) != NULL)
// 			|| (getValue("-to",$cmd_list) != NULL)){
// 		$status = link_between($cmd_list);
// 	}
// 	else {
// 		$status = cCmdStatus_NOT_FOUND; 
// 	}
	
// 	return $status;
// }


// /*
//  * Creates a workflow
//  */
// function wf_create($cmd_list) {
// 	global $gResult;

// 	$n = getValue("-n",$cmd_list);
// 	$i = getValue("-i",$cmd_list); 

// 	if (($n == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}

// 	$sql = sprintf("SELECT ggdb.create_workflow ('%s', '%s')", $n, $i);

// 	$result = runScalarDbQuery($sql);

// 	$t = "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Deletes a workflow
//  */
// function wf_delete($cmd_list) {
// 	global $gResult;

// 	$n = getValue("-n",$cmd_list);
// 	if ($n == NULL) {
// 		return cCmdStatus_ERROR; 
// 	}


// 	$sql = sprintf("SELECT ggdb.drop_workflow ('%s');", $n);

// 	$result = runScalarDbQuery($sql, "basicPrintLine");

// 	$t = $result . "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }


// /*
//  * List all workflows
//  */
// function wf_list($cmd_list) {
// 	global $gResult;

// 	$sql = "SELECT ggdb.get_workflows();";

// 	$result = runSetDbQuery($sql,"basicPrintLine");

// 	$t = "\n" . $result . "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Adds node
//  */
// function node_add($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	$sn = getValue("-sn",$cmd_list); 
// 	$t = getValue("-t",$cmd_list); 
// 	$n = getValue("-n",$cmd_list); 

// 	if (($wf == NULL) || ($sn == NULL)|| ($t == NULL)|| ($n == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}


// 	$sql = sprintf("select ggdb.add_node ('%s', '%s', '%s', '%s');", $wf, $sn, $n, $t);

// 	$result = runScalarDbQuery($sql);

// 	$t = "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Lists nodes in workflow
//  */
// function node_list($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	if (($wf == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}


// 	$sql = sprintf("select ggdb.get_nodes ('%s');", $wf);


// 	$result = runSetDbQuery($sql,"basicPrintLine");

// 	$t = "\n" . $result . "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }


// /*
//  * Lists nodes that have no links.
//  */
// function node_loose($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	if (($wf == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}


// 	$sql = sprintf("select ggdb.find_loose_nodes ('%s');", $wf);


// 	$result = runSetDbQuery($sql,"basicPrintLine");

// 	$t = "\n" . $result . "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Links node to start node for that workflow.     
//  */
// function link_start($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	$to = getValue("-to",$cmd_list); 
// 	$g = getValue("-g",$cmd_list); 

// 	if (($wf == NULL) || ($to == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}


// 	$sql = sprintf("select ggdb.link_from_start ('%s', '%s', '%s');", $wf, $to, $g);

// 	$result = runScalarDbQuery($sql);

// 	$t = "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Links node to end node for that workflow.       
//  */
// function link_finish($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	$from = getValue("-from",$cmd_list); 
// 	$g = getValue("-g",$cmd_list); 

// 	if (($wf == NULL) || ($from == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}

// 	$sql = sprintf("select ggdb.link_to_finish ('%s', '%s', '%s');", $wf, $from, $g);

// 	$result = runScalarDbQuery($sql);

// 	$t = "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Links two nodes together.   
//  */
// function link_between($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	$from = getValue("-from",$cmd_list); 
// 	$to = getValue("-to",$cmd_list); 
// 	$g = getValue("-g",$cmd_list); 

// 	if (($wf == NULL) || ($from == NULL)|| ($to == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}

// 	$sql = sprintf("select ggdb.link_between ('%s', '%s', '%s', '%s');", $wf, $from, $to, $g);

// 	$result = runScalarDbQuery($sql);

// 	$t = "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

// /*
//  * Lists children of a node with the guard label.    
//  */
// function link_children($cmd_list) {
// 	global $gResult;

// 	$wf = getValue("-wf",$cmd_list);
// 	$sn = getValue("-sn",$cmd_list);
// 	if (($wf == NULL)||($sn == NULL)) {
// 		return cCmdStatus_ERROR; 
// 	}


// 	$sql = sprintf("select ggdb.get_children ('%s', '%s');", $wf, $sn);


// 	$result = runSetDbQuery($sql,"basicPrintLine");

// 	$t = "\n" . $result . "\n"; 
// 	$gResult = $t . print_r($cmd_list,true);
// 	return cCmdStatus_OK; 
// }

