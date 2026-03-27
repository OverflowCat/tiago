// Generates `text_metrics/font_metrics.mbt` from the embedded reference fonts.
//
// Run this from a checkout where upstream reference's Go modules resolve, for example:
//   go run /path/to/diago/text_metrics/gen_font_metrics.go > /path/to/diago/text_metrics/font_metrics.mbt
package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/golang/freetype/truetype"
	"golang.org/x/image/font"
	"golang.org/x/image/math/fixed"

	"oss.terrastruct.com/d2/d2renderers/d2fonts"
)

const (
	baseFontSize = 16
	geoStart     = 0x25A0
	geoEnd       = 0x25FF
)

type fontVariant struct {
	name   string
	family d2fonts.FontFamily
	style  d2fonts.FontStyle
}

var variants = []fontVariant{
	{name: "sans_regular", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_REGULAR},
	{name: "sans_bold", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_BOLD},
	{name: "sans_semibold", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_SEMIBOLD},
	{name: "sans_italic", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_ITALIC},
	{name: "mono_regular", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_REGULAR},
}

var sizeSpecificSizes = map[string][]int{
	"sans_regular": {20, 24, 28},
	"sans_bold":    {20, 24, 28, 29, 32},
	"sans_semibold": {20, 24, 28, 32},
	"mono_regular": {20},
}

func loadFace(v fontVariant) (font.Face, error) {
	sizeless := d2fonts.Font{Family: v.family, Style: v.style, Size: 0}
	ttfBytes := d2fonts.FontFaces.Get(sizeless)
	ttf, err := truetype.Parse(ttfBytes)
	if err != nil {
		return nil, err
	}
	return truetype.NewFace(ttf, &truetype.Options{Size: float64(baseFontSize)}), nil
}

func glyphMetrics(face font.Face, r rune) (xMin, xMax int, advance fixed.Int26_6) {
	b, adv, ok := face.GlyphBounds(r)
	if !ok {
		return 0, 0, 0
	}
	return b.Min.X.Floor(), b.Max.X.Ceil(), adv
}

func loadFaceAtSize(v fontVariant, fontSize int) (font.Face, error) {
	sizeless := d2fonts.Font{Family: v.family, Style: v.style, Size: 0}
	ttfBytes := d2fonts.FontFaces.Get(sizeless)
	ttf, err := truetype.Parse(ttfBytes)
	if err != nil {
		return nil, err
	}
	return truetype.NewFace(ttf, &truetype.Options{Size: float64(fontSize)}), nil
}

func emitArrayIntFlat(name string, values []int, perLine int) {
	fmt.Printf("let %s : FixedArray[Int16] = [\n", name)
	for i, v := range values {
		if i%perLine == 0 {
			fmt.Print("  ")
		}
		fmt.Printf("%d", v)
		if i != len(values)-1 {
			fmt.Print(", ")
		}
		if i%perLine == perLine-1 || i == len(values)-1 {
			fmt.Print("\n")
		}
	}
	fmt.Println("]")
}

func emitArrayInt(name string, values []int) {
	emitArrayIntFlat(name, values, 32)
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--size-specific" {
		generateSizeSpecific()
		return
	}

	var b strings.Builder
	b.WriteString("// Generated from upstream reference embedded fonts by text_metrics/gen_font_metrics.go. Do not edit by hand.\n\n")
	b.WriteString("///|\n")
	b.WriteString(fmt.Sprintf("const BASE_FONT_SIZE : Int = %d\n\n", baseFontSize))
	b.WriteString("///|\n")
	b.WriteString(fmt.Sprintf("const GEO_START : Int = %d\n\n", geoStart))
	b.WriteString("///|\n")
	b.WriteString(fmt.Sprintf("const GEO_END : Int = %d\n\n", geoEnd))
	fmt.Print(b.String())

	for _, v := range variants {
		face, err := loadFace(v)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}

		asciiXMin := make([]int, 256)
		asciiXMax := make([]int, 256)
		asciiAdvance := make([]int, 256)
		for cp := 0; cp < 256; cp++ {
			xMin, xMax, adv := glyphMetrics(face, rune(cp))
			asciiXMin[cp] = xMin
			asciiXMax[cp] = xMax
			asciiAdvance[cp] = int(adv)
		}

		asciiKern := make([]int, 256*256)
		for left := 0; left < 256; left++ {
			for right := 0; right < 256; right++ {
				k := face.Kern(rune(left), rune(right))
				asciiKern[left*256+right] = int(k)
			}
		}

		geoN := geoEnd - geoStart + 1
		geoXMin := make([]int, geoN)
		geoXMax := make([]int, geoN)
		geoAdvance := make([]int, geoN)
		for cp := geoStart; cp <= geoEnd; cp++ {
			xMin, xMax, adv := glyphMetrics(face, rune(cp))
			idx := cp - geoStart
			geoXMin[idx] = xMin
			geoXMax[idx] = xMax
			geoAdvance[idx] = int(adv)
		}

		fmt.Println("///|")
		emitArrayInt("glyph_x_mins_"+v.name, asciiXMin)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_x_maxs_"+v.name, asciiXMax)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_advances_fixed_"+v.name, asciiAdvance)
		fmt.Println()
		fmt.Println("///|")
		emitArrayIntFlat("kernings_fixed_"+v.name, asciiKern, 16)
		fmt.Println()

		fmt.Println("///|")
		emitArrayInt("glyph_x_mins_"+v.name+"_geo", geoXMin)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_x_maxs_"+v.name+"_geo", geoXMax)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_advances_fixed_"+v.name+"_geo", geoAdvance)
		fmt.Println()
	}
}

func generateSizeSpecific() {
	fmt.Println("// Generated from upstream reference embedded fonts by text_metrics/gen_font_metrics.go.")
	fmt.Println("// Size-specific metrics to match the reference ruler hinting at selected sizes.")
	fmt.Println()

	for _, v := range variants {
		sizes := sizeSpecificSizes[v.name]
		for _, fontSize := range sizes {
			face, err := loadFaceAtSize(v, fontSize)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}

			asciiXMin := make([]int, 256)
			asciiXMax := make([]int, 256)
			asciiAdvance := make([]int, 256)
			for cp := 0; cp < 256; cp++ {
				xMin, xMax, adv := glyphMetrics(face, rune(cp))
				asciiXMin[cp] = xMin
				asciiXMax[cp] = xMax
				asciiAdvance[cp] = int(adv)
			}

			suffix := fmt.Sprintf("%s_sz%d", v.name, fontSize)
			fmt.Println("///|")
			emitArrayInt("glyph_x_mins_"+suffix, asciiXMin)
			fmt.Println()
			fmt.Println("///|")
			emitArrayInt("glyph_x_maxs_"+suffix, asciiXMax)
			fmt.Println()
			fmt.Println("///|")
			emitArrayInt("glyph_advances_fixed_"+suffix, asciiAdvance)
			fmt.Println()
		}
	}
}
