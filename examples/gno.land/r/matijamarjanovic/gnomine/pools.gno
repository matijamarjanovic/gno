package gnomine

import ( 
	"errors"
	"std"
	"math"

	"gno.land/p/demo/ufmt"
	"gno.land/p/demo/grc/grc20"
	"gno.land/r/demo/tokenhub"
)

func CreatePool(tokenA, tokenB string, initialAmountA, initialAmountB uint64) (*Pool, error) {
	caller := std.PrevRealm().Addr()
	if tokenA == tokenB {
		return nil, errors.New("identical tokens")
	}

	tokenAInstance := tokenhub.GetToken(tokenA)
	if tokenAInstance == nil {
		return nil, errors.New(ufmt.Sprintf("token %s not found", tokenA))
	}

	tokenBInstance := tokenhub.GetToken(tokenB)
	if tokenBInstance == nil {
		return nil, errors.New(ufmt.Sprintf("token %s not found", tokenB))
	}

	poolKey := createPoolKey(tokenA, tokenB)
	if _, exists := poolRegistry.pools.Get(poolKey); exists {
		return nil, errors.New("pool already exists")
	}

	tellerA := tokenAInstance.CallerTeller()
	if err := tellerA.TransferFrom(
		std.PrevRealm().Addr(),      
		std.CurrentRealm().Addr(),    
		initialAmountA,               
	); err != nil {
		if err.Error() == "insufficient allowance" {
			return nil, errors.New(ufmt.Sprintf("failed to transfer token %s: %v, please approve the pool first : %s", tokenA, err, std.CurrentRealm().Addr()))
		}
		return nil, errors.New(ufmt.Sprintf("failed to transfer token %s: %v", tokenA, err))
	}

	tellerB := tokenBInstance.CallerTeller()
	if err := tellerB.TransferFrom(
		std.PrevRealm().Addr(),      
		std.CurrentRealm().Addr(),    
		initialAmountB,               
	); err != nil {
		if err.Error() == "insufficient allowance" {
			return nil, errors.New(ufmt.Sprintf("failed to transfer token %s: %v, please approve the pool first : %s", tokenB, err, std.CurrentRealm().Addr()))
		}
		return nil, errors.New(ufmt.Sprintf("failed to transfer token %s: %v", tokenB, err))
	}

	// liquidity pool token
	lpName := ufmt.Sprintf("LP %s-%s", tokenA, tokenB)
	lpSymbol := ufmt.Sprintf("LP-%s-%s", tokenA, tokenB)
	lpToken, lpLedger := grc20.NewToken(lpName, lpSymbol, 6)
	tokenhub.RegisterToken(lpToken.Getter(), lpSymbol) // should be added to tokenhub?

	shares := uint64(math.Sqrt(float64(initialAmountA * initialAmountB)))
	if shares == 0 {
		return nil, errors.New("insufficient initial liquidity")
	}

	pool := &Pool{
		tokenA:      tokenA,
		tokenB:      tokenB,
		reserveA:    initialAmountA,
		reserveB:    initialAmountB,
		lpToken:     lpToken,
		lpLedger:    lpLedger,
		totalSupplyLp: shares, 
	}

	// mint LP tokens to the creator
	if err := pool.lpLedger.Mint(caller, shares); err != nil {
		return nil, errors.New(ufmt.Sprintf("failed to mint LP tokens: %v", err))
	}

	poolRegistry.pools.Set(poolKey, pool)

	return pool, nil
}

func (p *Pool) AddLiquidity(provider std.Address, amountA, amountB uint64) error {
	tellerA := tokenhub.GetToken(p.tokenA).CallerTeller()
	if err := tellerA.TransferFrom(
		std.PrevRealm().Addr(),      
		std.CurrentRealm().Addr(),    
		amountA,               
	); err != nil {
		if err.Error() == "insufficient allowance" {
			return errors.New(ufmt.Sprintf("failed to transfer token %s: %v, please approve the pool first : %s", p.tokenA, err, std.CurrentRealm().Addr()))
		}
		return errors.New(ufmt.Sprintf("failed to transfer token %s: %v", p.tokenA, err))
	}

	tellerB := tokenhub.GetToken(p.tokenB).CallerTeller()
	if err := tellerB.TransferFrom(
		std.PrevRealm().Addr(),      
		std.CurrentRealm().Addr(),    
		amountB,               
	); err != nil {
		if err.Error() == "insufficient allowance" {
			return errors.New(ufmt.Sprintf("failed to transfer token %s: %v, please approve the pool first : %s", p.tokenB, err, std.CurrentRealm().Addr()))
		}
		return errors.New(ufmt.Sprintf("failed to transfer token %s: %v", p.tokenB, err))
	}

	var shares uint64
	if p.totalSupplyLp == 0 {
		if amountA == 0 || amountB == 0 {
			return errors.New("cannot add zero liquidity")
		}
		shares = uint64(math.Sqrt(float64(amountA * amountB)))
	} else {
		if (amountA * p.reserveB) != (amountB * p.reserveA) {
			return errors.New(ufmt.Sprintf("incorrect token ratio, should be %d:%d", p.reserveA, p.reserveB))
		}

		sharesA := (amountA * p.totalSupplyLp) / p.reserveA
		sharesB := (amountB * p.totalSupplyLp) / p.reserveB
		if sharesA < sharesB {
			shares = sharesA
		} else {
			shares = sharesB
		}
	}

	if shares == 0 {
		return errors.New("insufficient liquidity provided")
	}

	p.reserveA += amountA
	p.reserveB += amountB
	p.totalSupplyLp += shares

	// mint LP 
	if err := p.lpLedger.Mint(provider, shares); err != nil {
		return err
	}

	return nil
}

// todo: return amountA, amountB to caller
func (p *Pool) RemoveLiquidity(provider std.Address, lpAmount uint64) (uint64, uint64, error) {
	if lpAmount == 0 {
		return 0, 0, errors.New("cannot remove zero liquidity")
	}

	amountA := (lpAmount * p.reserveA) / p.totalSupplyLp
	amountB := (lpAmount * p.reserveB) / p.totalSupplyLp

	p.reserveA -= amountA
	p.reserveB -= amountB
	p.totalSupplyLp -= lpAmount

	if err := p.lpLedger.Burn(provider, lpAmount); err != nil {
		return 0, 0, err
	}

	return amountA, amountB, nil
}

func (p *Pool) GetLPBalance(address std.Address) uint64 {
	teller := p.lpToken.CallerTeller()
	return teller.BalanceOf(address)
}

func (p *Pool) GetSharePercentage(address std.Address) float64 {
	if p.totalSupplyLp == 0 {
		return 0
	}
	lpBalance := p.GetLPBalance(address)
	return float64(lpBalance) / float64(p.totalSupplyLp) * 100
}

func createPoolKey(tokenA, tokenB string) string {
	// consistent ordering of tokens
	if tokenA < tokenB {
		return tokenA + ":" + tokenB
	}
	return tokenB + ":" + tokenA
}
