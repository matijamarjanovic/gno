package gnocket

import (
	//"errors" //TODO: add error handling
	"std"
	//"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"
	"gno.land/r/demo/tokenhub"
)

var (
	wallets = avl.NewTree() // std.Address -> *Wallet
)

// creates a new wallet for the caller
func NewWallet() *Wallet {
	caller := std.PrevRealm().Addr()

	if wallet, exists := wallets.Get(string(caller)); exists {
		return wallet.(*Wallet)
	}

	wallet := &Wallet{
		Ownable: ownable.NewWithAddress(caller),
	}

	wallets.Set(string(caller), wallet)

	return wallet
}

// allBool flag is used to get all balances or only non-zero balances
//
// tokenType is used to get balances for a specific token type:
// "token" for standard tokens
// "nft" for NFTs
// "multitoken" for MultiTokens
// any combination of the above with , between them
// "" for all balances
//
// user is the address/username of the user to get the balances for
// "me" as the user will get the balances for the caller

func GetBalances(allBool bool, tokenTypesWanted string, user string) []string {
	var caller std.Address
	if user == "me" {
		caller = std.PrevRealm().Addr()
	} else {
		caller = getAddressForUsername(user)
	}
	_, exists := wallets.Get(string(caller))

	if !exists {
		return []string{"No wallet found. Please create a wallet first."}
	}

	allBalances := ""

	if allBool {
		allBalances = tokenhub.GetUserTokenBalancesNonZero(caller.String()) +
						tokenhub.GetUserNFTBalances(caller.String()) +
						tokenhub.GetUserMultiTokenBalancesNonZero(caller.String())
	} else {
		allBalances = tokenhub.GetUserTokenBalances(caller.String()) +
						tokenhub.GetUserNFTBalances(caller.String()) +
						tokenhub.GetUserMultiTokenBalances(caller.String())
	}

	allBalances = strings.TrimPrefix(allBalances, "Balances: ")
	allBalances = strings.TrimPrefix(allBalances, "Non-Zero Balances: ")
	allBalancesSlice := strings.Split(allBalances, ",")
	tokenBalances := []string{}
	for _, balance := range allBalancesSlice[:len(allBalancesSlice)-1] {
		balanceParts := strings.Split(balance, ":")
		tokenType := balanceParts[0]
		tokenType = strings.ToLower(tokenType)
		tokenKey := balanceParts[1]
		if tokenType != "nft" {
			tokenBalance := balanceParts[2]
			if strings.Contains(tokenTypesWanted, tokenType) || tokenTypesWanted == "" {
				tokenBalances = append(tokenBalances, ufmt.Sprintf("%s: %s", tokenKey, tokenBalance))
			}
		} else { //if it is an nft balance is not needed
			if strings.Contains(tokenTypesWanted, tokenType) || tokenTypesWanted == "" {
				tokenBalances = append(tokenBalances, tokenKey)
			}
		}
	}

	if len(tokenBalances) == 0 {
		return []string{"No tokens of the requested type(s) found."}
	}

	return tokenBalances
}

func GetAllTokens() string {
	return tokenhub.GetAllRegistered()
}

func GetAllTokensNoNFTs() string {
	return tokenhub.GetAllTokens() + tokenhub.GetAllMultiTokens()
}

func getAddressForUsername(addrOrName string) std.Address {
	addr := std.Address(addrOrName)

	if addr.IsValid() {
		return addr
	}
	if user := users.GetUserByName(addrOrName); user != nil {
		return user.Address
	}

	return ""
}
