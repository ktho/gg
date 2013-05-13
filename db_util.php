
<?php
/*
 * filename: db_util.php 
 */

// include key database variables for connection string 
include 'DBVars.php';


	function runScalarDbQuery($sql) 
	{
		global $gDB_conn_string;
	
		$return_value = 0; 
		
		// Try to make a connection 
		$db = pg_connect($gDB_conn_string); 
		if (!$db) {
			$return_value = ("Error in connection: " . pg_last_error());
			return $return_value;
		}     
		
		// Create and run a query 
		$result = pg_query($db, $sql);
		if (!$result) {
			$return_value = ("Error in SQL query: " . pg_last_error());
			return $return_value;
		}
		else {
			$row = pg_fetch_array($result); 
			if (isset($row[0])) {
				$return_value = $row[0];
			}
		}
		pg_free_result($result);       
		pg_close($db);
		//echo "DEBUG: " . $sql;
		return $return_value;
	}


/* 
 * This is a call back function for printing the rows of a result set. This 
 * function, or other function with this signature, can be passed into the 
 * function runSetDbQuery. 
 */ 
function basicPrintLine($row)
{
	$t = ""; 
	reset($row);
	while (list($key, $val) = each($row)) {
    	$t .= "$key: $val\n";
    }
    return $t;
}

/*
 * This function is used to generate a string containing a result set, that is, 
 * a query that returns 0 or more records. 
 * 		sql 		- the SQL query 
 *		funct_name	- the name of a function that prints a row
 *
 * Example: 
 *		$result_string = runSetDbQuery("select * from dtz.workflow;", "basicPrintLine"); 
 */



function runSetDbQuery($sql,$funct_name)
{
	global $gDB_conn_string;
	
	$output = ""; 
		
	// Try to make a connection 
	$db = pg_connect($gDB_conn_string); 
	if (!$db) {
		$output = ("Error in connection: " . pg_last_error());
		return $output;
	}     

	// Create and run a query 
	$result = pg_query($db, $sql);
	if (!$result) {
		$output("Error in SQL query: " . pg_last_error());
		return $output;
	}
	else {
		while ($row = pg_fetch_array($result, NULL, PGSQL_ASSOC)) {
			$output .= call_user_func($funct_name,$row);  
		}
	}

     // wrap up
	pg_free_result($result);       
	pg_close($db);
	
	return $output;
}


/*
 * Returns a string indicating the status of the db server
 */
function returnDbStatus() 
{
	global $gDB_conn_string;
	
	$status = 	""; 
	$status .= 	"Connection string >" . $gDB_conn_string . "<" . "\n"; 
			
	// Try to make a connection 
	$db = pg_connect($gDB_conn_string); 
	if (!$db) {
		$status .= "Error in connection: " . pg_last_error() . "</pre>";
		return $status;
	}     
			
	// Check the connection status and report basic information
	$stat = pg_connection_status($db);
  	if ($stat === PGSQL_CONNECTION_OK) {
      	$status .= "Connection status ok \n";
		$status .= "   Host: " . pg_host($db) . "\n"; 
		$status .= "   Port: " . pg_port($db) . "\n"; 
		$status .= "   db name: " . pg_dbname($db) . "\n"; 
		$status .="   options: " . pg_options($db) . "\n";
	} 
	else {
      	$status .='Connection status bad';
      }    
	$status .= "";

	// wrap up    
	pg_close($db);
		
	return $status;
}
?>       