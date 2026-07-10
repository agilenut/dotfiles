// Palette sample: Go — comments, strings, numbers, keywords, types, funcs.
package main

import (
	"fmt"
	"strings"
)

const maxRetries = 3

// Greeter builds greetings.
type Greeter struct {
	Name string
}

func (g Greeter) Greet() string {
	if g.Name == "" {
		g.Name = "world"
	}
	return fmt.Sprintf("hello %s\n", strings.TrimSpace(g.Name))
}

func main() {
	for i := 0; i < maxRetries; i++ {
		fmt.Print(Greeter{Name: "palette"}.Greet())
	}
}
