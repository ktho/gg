<?php
/*
 * filename: cmd_tagging.php 
 */



 /* This function dispatches a tagging & bundle commands and its parameters to the corresponding function 
  */
function dispatchTagCmd($cmd, $cmd_list) 
{
	global $gResult;
	$status = cCmdStatus_NOT_FOUND;
	
	$cmd = $cmd_list[0];
	if (($cmd != "tag") && ($cmd != "bundle")) {
		$status = cCmdStatus_NOT_FOUND; 
		return $status;
	}
	
	if ($cmd == "tag") { 
		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}
	
		if ($arg1 == "create") {
			$status = create_tag($cmd_list);
		}
		elseif ($arg1 == "update") {
		$status = update_tag($cmd_list);
		}
		elseif ($arg1 == "remove") {
			$status = delete_tag($cmd_list);
		}
		else {
			$status = cCmdStatus_NOT_FOUND; 
		}
	return $status;
	}

	if ($cmd == "bundle") { 

		$arg1 = "";
		if (count($cmd_list) > 1) {
		$arg1 = $cmd_list[1];
		}
	
		if ($arg1 == "create") {
			$status = create_bundle($cmd_list);
		}
		elseif ($arg1 == "update") {
		$status = update_bundle($cmd_list);
		}
		elseif ($arg1 == "remove") {
		$status = delete_bundle($cmd_list);
		}
		else {
			$status = cCmdStatus_NOT_FOUND; 
		}
	return $status;
	}
}

/*
 * Create Tag
 * Author: Cory
 */
function create_tag($cmd_list) {
	global $gResult;

	$b = getValue("-b",$cmd_list); 
	$n = getValue("-n",$cmd_list);  

	if (($b == NULL)|| ($n == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.create_tag('%s', '%s');", $b, $n);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Update Tag
 * Author: Cory
 */
function update_tag($cmd_list) {
	global $gResult;

	$n = getValue("-n",$cmd_list); 
	$nb = getValue("-nb",$cmd_list); 
	$nt = getValue("-nt",$cmd_list); 

	if (($n == NULL) || ($nb == NULL)|| ($nt == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.update_tag('%s', '%s', '%s');", $n, $nb, $nt);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Delete Tag
 * Author: Cory
 */
function delete_tag($cmd_list) {
	global $gResult;

	$n = getValue("-n",$cmd_list); 

	if (($n == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.delete_tag('%s');", $n);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Create Bundle
 * Author: Cory
 */
function create_bundle($cmd_list) {
	global $gResult;

	$n = getValue("-n",$cmd_list); 

	if ($n == NULL) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.create_bundle('%s');", $n);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Update Bundle
 * Author: Cory
 */
function update_bundle($cmd_list) {
	global $gResult;

	$n = getValue("-n",$cmd_list); 
	$nb = getValue("-nb",$cmd_list); 

	if (($n == NULL) || ($nb == NULL)) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.update_bundle('%s', '%s');", $n, $nb);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

/*
 * Delete Bundle
 * Author: Cory
 */
function delete_bundle($cmd_list) {
	global $gResult;

	$n = getValue("-n",$cmd_list); 

	if ($n == NULL) {
		return cCmdStatus_ERROR; 
	}


	$sql = sprintf("select ggdb.delete_bundle('%s');", $n);

	$result = runScalarDbQuery($sql);

	$t = "\n"; 
	$gResult = $t . print_r($cmd_list,true);
	return cCmdStatus_OK; 
}

?>
