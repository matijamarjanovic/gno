package gnomads

import (
	"std"
	"time"

	"gno.land/p/demo/btree"
)

type Post struct {
	postID       string
	parentPostID string 			//if post is a reply, this is the id of the post it is replying to
	author       std.Address
	content      string
	createdAt    time.Time
	likes        []std.Address
}

func (p Post) Less(than btree.Record) bool {
	other, ok := than.(Post)
	if !ok {
		panic("invalid comparison")
	}
	return p.createdAt.After(other.createdAt)
}


type User struct {
	address            std.Address
	username           string
	password           string
	posts              []Post
	interactionCounter int
	signInStatus       int // 0 - not signed in, 1 - signed in
}

func (u User) Less(than btree.Record) bool {
	other, ok := than.(User)
	if !ok {
		panic("invalid comparison") 
	}
	return u.username < other.username
}

var (
	usersTree = btree.New()
	postsTree = btree.New()
)


