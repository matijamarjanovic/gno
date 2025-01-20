package gnocket

import (
	"std"
	"strings"
	"gno.land/p/moul/md"
	"gno.land/p/demo/ufmt"
)


// TODO : add filtering by token type with parsing address.[tokenType]; if no token type is provided, return all tokens
func Render(path string) string {
	userToDisplay := getAddressForUsername(path)

	if RenderUserPageAllTypes(userToDisplay) != "no wallet found" {
		return RenderUserPageAllTypes(userToDisplay)
	}

	sb := strings.Builder{}
	sb.WriteString("")

	return sb.String()
}

// TODO : add  sorting by token type
func RenderUserPageAllTypes(userToDisplay std.Address) string {

	wallet, exists := wallets.Get(string(userToDisplay))
	if !exists {
		return "no wallet found"
	}
	sb := strings.Builder{}

	sb.WriteString(md.H1(ufmt.Sprintf("Wallet of %s", userToDisplay)))

	if wallet.(*Wallet).public {
		sb.WriteString(md.BulletList([]string{}))

		wallet.(*Wallet).tokenBalances.Iterate("", "", func(key string, value interface{}) bool {
			tokenType := value.(*userTokenMetadata).tokenType
			tokenKey := key
			balance := ufmt.Sprintf("%d", value.(*userTokenMetadata).balance)
			if tokenType == "NFT" {
				sb.WriteString(md.BulletItem(ufmt.Sprintf("%s : %s", tokenType, tokenKey)))
			} else {
				sb.WriteString(md.BulletItem(ufmt.Sprintf("%s : %s : %s", tokenType, tokenKey, balance)))
			}
			return false
		})

	} else {
		return md.H1("Wallet is not public") + md.Paragraph("If this is your wallet, you can toggle it's visibility by triggering TogglePublic().")
	}

	return sb.String()
}
