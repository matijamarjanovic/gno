package gnomine

import (
    "errors"
    "std"

	"gno.land/p/demo/avl"
)

type Pool struct {
    tokenA    string // tokenhub tokenKey
    tokenB    string // tokenhub tokenKey
    reserveA  uint64
    reserveB  uint64
    lpTokens  *avl.Tree // key is std.Address, value is uint64 owner->shares work on logic
    totalSupply uint64
}

type PoolRegistry struct {
    pools *avl.Tree // key is "tokenA:tokenB", value is *Pool
}

func NewPoolRegistry() *PoolRegistry {
    return &PoolRegistry{
        pools: avl.NewTree(),
    }
}

func createPoolKey(tokenA, tokenB string) string {
    // consistent ordering of tokens
    if tokenA < tokenB {
        return tokenA + ":" + tokenB
    }
    return tokenB + ":" + tokenA
}

func (pr *PoolRegistry) CreatePool(tokenA, tokenB string, initialAmountA, initialAmountB uint64) (*Pool, error) {
    if tokenA == tokenB {
        return nil, errors.New("identical tokens")
    }

    poolKey := createPoolKey(tokenA, tokenB)
    if _, exists := pr.pools.Get(poolKey); exists {
        return nil, errors.New("pool already exists")
    }

    pool := &Pool{
        tokenA:    tokenA,
        tokenB:    tokenB,
        reserveA:  initialAmountA,
        reserveB:  initialAmountB,
        lpTokens:  avl.NewTree(),
        totalSupply: 0,
    }

    pr.pools.Set(poolKey, pool)
    return pool, nil
}

func (p *Pool) AddLiquidity(provider std.Address, amountA, amountB uint64) error {
    var shares uint64
    if p.totalSupply == 0 {
        // First liquidity provision
        //shares = sqrt(amountA * amountB) //todo: implement sqrt
    } else {
        // Calculate shares based on the proportion of existing reserves
        sharesA := (amountA * p.totalSupply) / p.reserveA
        sharesB := (amountB * p.totalSupply) / p.reserveB
        if sharesA < sharesB {
            shares = sharesA
        } else {
            shares = sharesB
        }
    }

    if shares == 0 {
        return errors.New("insufficient liquidity provided")
    }

    // update pool state
    p.reserveA += amountA
    p.reserveB += amountB
    currentShares, _ := p.lpTokens.Get(string(provider))
    p.lpTokens.Set(string(provider), currentShares.(uint64)+shares)
    p.totalSupply += shares

    return nil
}

