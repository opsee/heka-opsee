package heka_opsee

import (
	"github.com/rafrombrc/gospec/src/gospec"
	"testing"
)

func TestAllSpecs(t *testing.T) {
	r := gospec.NewRunner()
	r.Parallel = false

	r.AddSpec(NsqInputSpec)

	gospec.MainGoTest(r, t)
}
