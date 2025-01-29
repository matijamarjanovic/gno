package gnomine

import (

	"gno.land/p/demo/avl"
    "gno.land/p/demo/grc/grc20"
)
type PoolRegistry struct {
    pools *avl.Tree // key is "tokenA:tokenB", value is *Pool
}

type Pool struct {
    tokenA    string // tokenhub tokenKey
    tokenB    string // tokenhub tokenKey
    reserveA  uint64
    reserveB  uint64
    lpToken   *grc20.Token  // Change to GRC20 token
    lpLedger  *grc20.PrivateLedger
    totalSupplyLp uint64
}

var(
    poolRegistry *PoolRegistry
)

func init() {
    poolRegistry = &PoolRegistry{
        pools: avl.NewTree(),
    }
}
