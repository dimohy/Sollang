package main

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"unicode/utf8"
)

// Independent RE2-based reference. It does not share the production NFA parser,
// scratch layout or work counter. Only the verifier owns compiled allocations.
func main() {
	if len(os.Args) != 2 {
		panic("expected exactly one contract path")
	}
	bytes, err := os.ReadFile(os.Args[1])
	if err != nil {
		panic(err)
	}
	var contract struct {
		ReferenceCases []struct{ Label, Pattern, Input string }
	}
	if err := json.Unmarshal(bytes, &contract); err != nil {
		panic(err)
	}
	if len(contract.ReferenceCases) == 0 {
		panic("empty reference inventory")
	}
	for _, test := range contract.ReferenceCases {
		if !utf8.ValidString(test.Pattern) || !utf8.ValidString(test.Input) {
			panic("reference requires valid UTF-8 Text")
		}
		pattern, err := regexp.Compile(test.Pattern)
		if err != nil {
			panic(err)
		}
		pattern.Longest()
		match := pattern.FindStringIndex(test.Input)
		if match == nil {
			fmt.Printf("%s=none\n", test.Label)
		} else {
			fmt.Printf("%s=%d,%d\n", test.Label, match[0], match[1]-match[0])
		}
	}
}
