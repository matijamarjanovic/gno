package main

import "fmt"

func main() {
	// Creating a map where keys are strings and values are integers
	scores := [3]string{
		"a", "b", "c",
	}

	// Using range to iterate over the map
	// k is the key and v is the value for each pair in the map
	var k, v int
	for k, v = range scores {
		fmt.Printf("%d has a score of %s\n", k, v)
	}
}

// Error:
// main/files/types/assign_range_b1.gno:14:2: cannot use string as int

// TypeCheckError:
// main/files/types/assign_range_b1.gno:14:9: cannot use v (value of type string) as int value in assignment
