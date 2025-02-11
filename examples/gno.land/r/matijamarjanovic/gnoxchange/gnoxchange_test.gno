package gnoxchange

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/urequire"
	"gno.land/r/demo/tokenhub"
)


func TestCreatePool(t *testing.T) {
	std.TestSetRealm(std.NewCodeRealm("gno.land/r/test/pools"))
	tokenA, ledgerA := grc20.NewToken("Test Token A", "TTA", 6)
	tokenB, ledgerB := grc20.NewToken("Test Token B", "TTB", 6)
	
	tokenhub.RegisterToken(tokenA.Getter(), "test_token_a")
	tokenhub.RegisterToken(tokenB.Getter(), "test_token_b")

	ledgerA.Mint(std.CurrentRealm().Addr(), 10000)
	ledgerB.Mint(std.CurrentRealm().Addr(), 10000)

	_, err := CreatePool("gno.land/r/test/pools.test_token_a", "gno.land/r/test/pools.test_token_b", 1000, 1000)
	uassert.Error(t, err, "Should fail with identical tokens")

	tellerA := tokenA.CallerTeller()
	tellerB := tokenB.CallerTeller()
	
	err = tellerA.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 10000)
	urequire.NoError(t, err, "Should approve token A")
	err = tellerB.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 10000)
	urequire.NoError(t, err, "Should approve token B")

	poolKey, err := CreatePool(
		"gno.land/r/test/pools.test_token_a",
		"gno.land/r/test/pools.test_token_b",
		1000,
		1000,
	)
	urequire.NoError(t, err, "Should create pool successfully")
	uassert.NotEmpty(t, poolKey, "Pool key should not be empty")

	tokenAName, tokenBName, reserveA, reserveB, err := GetPoolInfo(poolKey)
	urequire.NoError(t, err, "Should get pool info")
	uassert.Equal(t, "gno.land/r/test/pools.test_token_a", tokenAName)
	uassert.Equal(t, "gno.land/r/test/pools.test_token_b", tokenBName)
	uassert.Equal(t, uint64(1000), reserveA)
	uassert.Equal(t, uint64(1000), reserveB)
}

func TestAddLiquidity(t *testing.T) {
	std.TestSetRealm(std.NewCodeRealm("gno.land/r/test/pools"))
	tokenA, ledgerA := grc20.NewToken("Test Token A", "TTA", 6)
	tokenB, ledgerB := grc20.NewToken("Test Token B", "TTB", 6)
	
	tokenhub.RegisterToken(tokenA.Getter(), "test_token_a2")
	tokenhub.RegisterToken(tokenB.Getter(), "test_token_b2")

	ledgerA.Mint(std.CurrentRealm().Addr(), 10000)
	ledgerB.Mint(std.CurrentRealm().Addr(), 10000)

	tellerA := tokenA.CallerTeller()
	tellerB := tokenB.CallerTeller()

	err := tellerA.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 10000)
	urequire.NoError(t, err, "Should approve token A")
	err = tellerB.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 10000)
	urequire.NoError(t, err, "Should approve token B")

	poolKey, err := CreatePool("gno.land/r/test/pools.test_token_a2", "gno.land/r/test/pools.test_token_b2", 1000, 1000)
	urequire.NoError(t, err, "Should create pool")

	err = tellerA.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 500)
	urequire.NoError(t, err)
	err = tellerB.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 1000)
	urequire.NoError(t, err)
	
	err = AddLiquidity(poolKey, 500, 1000)
	uassert.Error(t, err, "Should fail with incorrect ratio")

	err = tellerA.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 500)
	urequire.NoError(t, err)
	err = tellerB.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 500)
	urequire.NoError(t, err)
	
	err = AddLiquidity(poolKey, 500, 500)
	urequire.NoError(t, err, "Should add liquidity successfully")

	_, _, reserveA, reserveB, err := GetPoolInfo(poolKey)
	urequire.NoError(t, err)
	uassert.Equal(t, uint64(1500), reserveA)
	uassert.Equal(t, uint64(1500), reserveB)
}

func TestWithdrawLiquidity(t *testing.T) {
	std.TestSetRealm(std.NewCodeRealm("gno.land/r/test/pools"))
	tokenA, ledgerA := grc20.NewToken("Test Token A", "TTA", 6)
	tokenB, ledgerB := grc20.NewToken("Test Token B", "TTB", 6)
	
	tokenhub.RegisterToken(tokenA.Getter(), "test_token_a3")
	tokenhub.RegisterToken(tokenB.Getter(), "test_token_b3")

	ledgerA.Mint(std.CurrentRealm().Addr(), 10000)
	ledgerB.Mint(std.CurrentRealm().Addr(), 10000)

	tellerA := tokenA.CallerTeller()
	tellerB := tokenB.CallerTeller()

	err := tellerA.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 1000)
	urequire.NoError(t, err)
	err = tellerB.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 1000)
	urequire.NoError(t, err)

	poolKey, err := CreatePool("gno.land/r/test/pools.test_token_a3", "gno.land/r/test/pools.test_token_b3", 1000, 1000)
	urequire.NoError(t, err, "Should create pool")

	poolInterface, exists := poolRegistry.pools.Get(poolKey)
	urequire.True(t, exists, "Pool should exist")
	pool := poolInterface.(*Pool)

	initialLPBalance := pool.GetLPBalance(std.CurrentRealm().Addr())
	uassert.True(t, initialLPBalance > 0, "Should have LP tokens")

	_, _, err = WithdrawLiquidity(poolKey, initialLPBalance+1)
	uassert.Error(t, err, "Should fail withdrawing more than available")

	amountA, amountB, err := WithdrawLiquidity(poolKey, initialLPBalance/2)
	urequire.NoError(t, err, "Should withdraw successfully")
	uassert.Equal(t, uint64(500), amountA)
	uassert.Equal(t, uint64(500), amountB)

	newLPBalance := pool.GetLPBalance(std.CurrentRealm().Addr())
	uassert.Equal(t, initialLPBalance/2, newLPBalance)
}

func TestPoolRegistry(t *testing.T) {
	std.TestSetRealm(std.NewCodeRealm("gno.land/r/test/pools"))
	tokenA, ledgerA := grc20.NewToken("Test Token A", "TTA", 6)
	tokenB, ledgerB := grc20.NewToken("Test Token B", "TTB", 6)
	
	tokenhub.RegisterToken(tokenA.Getter(), "test_token_a4")
	tokenhub.RegisterToken(tokenB.Getter(), "test_token_b4")

	ledgerA.Mint(std.CurrentRealm().Addr(), 10000)
	ledgerB.Mint(std.CurrentRealm().Addr(), 10000)

	tellerA := tokenA.CallerTeller()
	tellerB := tokenB.CallerTeller()

	err := tellerA.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 2000)
	urequire.NoError(t, err)
	err = tellerB.Approve(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnoxchange"), 2000)
	urequire.NoError(t, err)
	
	poolKey1, err := CreatePool("gno.land/r/test/pools.test_token_a4", "gno.land/r/test/pools.test_token_b4", 1000, 1000)
	urequire.NoError(t, err)

	poolNames := GetAllPoolNames()
	uassert.True(t, len(poolNames) > 0, "Should have at least one pool")
	uassert.True(t, contains(poolNames, poolKey1), "Should contain created pool")

	page := GetPoolsPage("")
	uassert.True(t, len(page.Items) > 0, "Page should contain entries")
}

func contains(slice []string, str string) bool {
	for _, v := range slice {
		if v == str {
			return true
		}
	}
	return false
} 
