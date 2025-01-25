package r

import (
	//"std"

	"gno.land/p/demo/avl"
	"gno.land/r/matijamarjanovic/gnomine/p"
)

type PoolRegistry struct {
    pools *avl.Tree // key is "tokenA:tokenB", value is *Pool
}

func NewPoolRegistry() *PoolRegistry {
    return &PoolRegistry{
        pools: avl.NewTree(),
    }
}
