<?php
/*
 * filename: cmd_VARS.php 
 */

/*
 * Global variable used to hold an error message if an error should occur
 */
$gLastErrorMessage 	= ""; 

/*
 * Global variable used to hold the last command that is executed 
 */
$gLastCommand 		= "";

/*
 * Global variable used to hold the result
 */
 $gResult			= ""; 

/*
 * Global variable of the variables being used in script 
 */ 
$gVariables["__test__"] = "test";
  


  
/* 
 * Constants 
 */
define("cCmdStatus_ERROR",		0);
define("cCmdStatus_OK",			1);
define("cCmdStatus_NOT_FOUND",	2);

/*
 *  Returns the value of an argument; otherwise, returns NULL if argument 
 *  is not found or if value is not found. 
 */
function getArgValue($arg, $cmd_list) 
{ 
	global $gLastErrorMessage; 
	
	$val = ""; 
	$k = array_search($arg, $cmd_list); 
	if ($k != FALSE) {
		if (isset($cmd_list[$k+1]) == TRUE) {
			$val = $cmd_list[$k+1];
		}
		else {
			$gLastErrorMessage 	= "missing value for " . $arg; 
			return NULL; 
		}
	}
	else {
			$gLastErrorMessage 	= $arg . " <...> is missing"; 
			return NULL; 
	}
	return $val;
}

/*
 *  Returns TRUE if the arg is found list list of commands 
 */
function argExists($arg, $cmd_list) 
{ 
	$k = array_search($arg, $cmd_list); 
	if ($k != FALSE) {
		return TRUE;
	}
	else {
		return FALSE; 
	}
}


function fillArrayWithValues($array, $cmd_list) 
{
 // Foreach element in array
 // if the element is in cmd_list then add value into array 
 // otherwise set "" 
}



?>