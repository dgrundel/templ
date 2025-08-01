package parser

import (
	"github.com/a-h/parse"
)

var htmlCommentStart = parse.String("<!--")
var htmlCommentEnd = parse.String("--")

type htmlCommentParser struct {
}

var htmlComment = htmlCommentParser{}

func (p htmlCommentParser) Parse(pi *parse.Input) (n Node, ok bool, err error) {
	// Comment start.
	start := pi.Position()
	if _, ok, err = htmlCommentStart.Parse(pi); err != nil || !ok {
		return
	}

	// Once we've got the comment start sequence, parse anything until the end
	// sequence as the comment contents.
	c := &HTMLComment{}
	if c.Contents, ok, err = parse.StringUntil(htmlCommentEnd).Parse(pi); err != nil || !ok {
		err = parse.Error("expected end comment literal '-->' not found", start)
		return
	}
	// Cut the end element.
	_, _, _ = htmlCommentEnd.Parse(pi)

	// Cut the gt.
	if _, ok, err = gt.Parse(pi); err != nil || !ok {
		err = parse.Error("comment contains invalid sequence '--'", pi.Position())
		return
	}

	c.Range = NewRange(start, pi.Position())
	return c, true, nil
}
