package gnomine	

import (
	"time"
	"std"
	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc20"
)

// PoolRegistry is a registry for swap pools. It is a singleton that is initialized in the init function.
// It is private to only this realm and cannot and should not be accessed in other realms.
type PoolRegistry struct {
    pools *avl.Tree // key is "tokenA:tokenB", value is *Pool
}

// Pool is a struct that represents a swap pool. It contains the two tokens in the pool,
// the reserves of each token, the liquidity provider token, and the total supply of the liquidity provider token.
// None of the pool's fields are to be accessed externally, only through the PoolRegistry in the GnoMine realm.
type Pool struct {
    tokenA    string // tokenhub tokenKey
    tokenB    string // tokenhub tokenKey
    reserveA  uint64
    reserveB  uint64
    lpToken   *grc20.Token  // Change to GRC20 token
    lpLedger  *grc20.PrivateLedger
    totalSupplyLp uint64
}

// Ticket is a struct that represents a swap ticket.
// It holds information about the available swaps
type Ticket struct {
	ID           string
	Creator      std.Address
	AssetIn      Asset
	AssetOut     Asset
	AmountIn     uint64
	MinAmountOut uint64
	CreatedAt    time.Time
	ExpiresAt    time.Time
	Status       string
}

type TicketRegistry struct {
	tickets *avl.Tree // ticket ID -> *Ticket
}

type AssetType uint8

const (
    AssetTypeCoin AssetType = iota  // Native coins (like ugnot)
    AssetTypeToken                   // GRC20 tokens
)

type Asset struct {
    Type     AssetType
    Denom    string    // for coins (e.g. "ugnot")
    Token    string    // for GRC20 tokens (e.g. "gno.land/r/demo/token")
}

func NewCoinAsset(denom string) Asset {
    return Asset{
        Type:  AssetTypeCoin,
        Denom: denom,
    }
}

func NewTokenAsset(token string) Asset {
    return Asset{
        Type:  AssetTypeToken,
        Token: token,
    }
}

