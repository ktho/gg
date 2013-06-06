<?php
/*
 * filename: cmd_moduleutility.php 
 */


//	foreach $cmd_list as $t {
//
//
// }

/*
 * This function dispatches a document command and its parameters to the corresponding function 
 */
function dispatchUtilityCmd($cmd, $cmd_list) 
{
	global $gResult;
	$status = "test1";
	
	$cmd = $cmd_list[0];
	if ($cmd != "history") {
		$status = cCmdStatus_NOT_FOUND; 
		return $status;
		}
	
	if ($cmd == "history") { 

		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}
	
		if ($arg1 == "get") {
			$status = revisionhistory_get($cmd_list);
		}
		else {
			$status = cCmdStatus_NOT_FOUND; 
		}
	return $status;
	}

}

/*
 * List revision history
 */
function revisionhistory_get($cmd_list) {
	global $gResult;

	$t = getValue("-t",$cmd_list); 

	if  ($t == NULL) {
		return cCmdStatus_ERROR; 
	}

	$sql = sprintf("select ggdb.get_revision_history ('%s');", $t);

	$result = runSetDbQuery($sql,"basicPrintLine");

	$nl = "\n". $result . "\n"; 
	$gResult = $nl . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}


?>