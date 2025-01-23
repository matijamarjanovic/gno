package gnocket

import (
	"std"
	//	"strings"
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ownable"
	"gno.land/r/demo/tokenhub"
)

type Wallet struct {
	*ownable.Ownable
	tokenBalances *avl.Tree // string -> userTokenMetadata
	public        bool
}

type userTokenMetadata struct {
	balance   uint64
	tokenType string
}

func assertOwnership() {
	caller := std.GetOrigCaller()
	w, exists := wallets.Get(string(caller))
	if !exists {
		panic("wallet not found")
	}
	w.(*Wallet).AssertCallerIsOwner()
}

func GetBalancesRaw() string {
	assertOwnership()
	caller := std.PrevRealm().Addr()
	return tokenhub.GetUserTokenBalancesNonZero(caller.String()) +
		tokenhub.GetUserNFTBalances(caller.String()) +
		tokenhub.GetUserMultiTokenBalancesNonZero(caller.String())
}

func GetBalancesRawWithZeros() string {
	assertOwnership()
	caller := std.PrevRealm().Addr()
	return tokenhub.GetUserTokenBalances(caller.String()) +
		tokenhub.GetUserNFTBalances(caller.String()) +
		tokenhub.GetUserMultiTokenBalances(caller.String())
}

