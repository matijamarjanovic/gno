package gnocket

import (
	//"std"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
)

func Render(path string) string {

	switch path {
	case "":
		return RenderHome()
	case "createWalletInfo":
		return RenderCreateWalletInfo()

	default:
		pathParts := strings.Split(path, ".")

		userToDisplay := ""
		tokenType := ""
		allBool := false
		if len(pathParts) == 1 {
			userToDisplay = path
		} else if len(pathParts) == 2 {
			userToDisplay = pathParts[0]
			if pathParts[1] == "showAll" {
				allBool = true
			} else {
				tokenType = pathParts[1]
			}
		} else if len(pathParts) == 3 {
			userToDisplay = pathParts[0]
			tokenType = pathParts[1]
			allBool = pathParts[2] == "showAll"
		} else {
			return "Invalid path"
		}

		return RenderUserPageAllTypes(userToDisplay, tokenType, allBool, path)
	}

	sb := strings.Builder{}
	sb.WriteString("")

	return sb.String()
}

// TODO : add  sorting by token type when there are no filters applied
// todo : add error handling
// todo : make a better ui
// todo : add pagination through the path
func RenderUserPageAllTypes(userToDisplay string, tokenTypeOption string, allBool bool, path string) string {
	sb := strings.Builder{}

	sb.WriteString(md.H1(ufmt.Sprintf("Wallet of %s", userToDisplay)))

	sb.WriteString(md.Link("Show Tokens Only", "http://localhost:8888/r/matijamarjanovic/gnocket:"+userToDisplay+".token") + " | ")
	sb.WriteString(md.Link("Show NFTs Only", "http://localhost:8888/r/matijamarjanovic/gnocket:"+userToDisplay+".nft") + " | ")
	sb.WriteString(md.Link("Show MultiTokens Only", "http://localhost:8888/r/matijamarjanovic/gnocket:"+userToDisplay+".multitoken") + " | ")
	sb.WriteString(md.Link("Reset Filters", "http://localhost:8888/r/matijamarjanovic/gnocket:"+userToDisplay))

	sb.WriteString("\n")
	sb.WriteString("\n")

	toggleShowAllPath := path
	if allBool {
		toggleShowAllPath = strings.TrimSuffix(toggleShowAllPath, ".showAll")
		sb.WriteString(md.Link("Hide Zero Balances", "http://localhost:8888/r/matijamarjanovic/gnocket:"+toggleShowAllPath))

	} else {
		toggleShowAllPath += ".showAll"
		sb.WriteString(md.Link("Show Zero Balances", "http://localhost:8888/r/matijamarjanovic/gnocket:"+toggleShowAllPath))

	}

	sb.WriteString("\n")

	_, exists := wallets.Get(string(userToDisplay))
	if !exists {
		return "no wallet found"
	}

	sb.WriteString(md.BulletList([]string{}))

	balances := GetBalances(allBool, tokenTypeOption, userToDisplay)
	sb.WriteString(md.BulletList(balances))

	sb.WriteString(md.Link("Return to Homepage", "http://localhost:8888/r/matijamarjanovic/gnocket"))

	return sb.String()
}

// todo: update script to approve all tokens in the tokenhub (both nfts and tokens)
// todo: formatt better
func RenderCreateWalletInfo() string {
	sb := strings.Builder{}

	sb.WriteString(md.Paragraph("Not sure you have a wallet? Run: `NewWallet()` by running this command in your command line:"))
	sb.WriteString("\n")
	sb.WriteString(md.CodeBlock(`gnokey maketx call
	-pkgpath "gno.land/r/matijamarjanovic/gnocket"
	-func "NewWallet"
	-gas-fee 1000000ugnot
	-gas-wanted 2000000
	-broadcast
	-chainid "<chain-id>" 
	-remote "<remote>"
	<your-address>`))
	sb.WriteString("\n")
	sb.WriteString(md.Paragraph("If you already have a wallet, this will do nothing; if you don't, this will create a new wallet that is bound to your address. Now for you to use this wallet, Gnocket needs some approvals:"))
	sb.WriteString(md.Paragraph("You need to give it permission for each token to use in your name. You can do this by running this script:"))
	sb.WriteString(md.Paragraph("Run the following commands to approve tokens:"))
	sb.WriteString(md.CodeBlock(`package main
	
import (
	"std"
	"strings"
	"gno.land/p/demo/grc/grc721"
	"gno.land/r/matijamarjanovic/tokenhub"
)

func main() {
	approvedAddress := std.Address(std.DerivePkgAddr("gno.land/r/matijamarjanovic/gnocket")) 

	allTokens := tokenhub.GetAllTokens()
	keys := []string{}

	for _, token := range strings.Split(allTokens, ",") {
		if strings.HasPrefix(token, "NFT:") {
			keys = append(keys, token)
		} else if strings.HasPrefix(token, "Token:") {
			keys = append(keys, token)
		}
	}

	for _, key := range keys {
		if strings.HasPrefix(key, "NFT:") {
			nftGetter := tokenhub.MustGetGRC721(strings.TrimPrefix(key, "NFT:"))
			nft := nftGetter()
			tokenID := grc721.TokenID(strings.Split(key, ".")[len(strings.Split(key, "."))-1])
			err := nft.Approve(approvedAddress, tokenID)
			if err != nil {
				panic(err)
			}
		} else if strings.HasPrefix(key, "Token:") {
			tokenGetter := tokenhub.MustGetGRC20(strings.TrimPrefix(key, "Token:"))
			token := tokenGetter()
			token.Approve(approvedAddress, uint64(token.TotalSupply()))
		}
	}
}`))
	sb.WriteString("\n")
	sb.WriteString(md.Paragraph(" by running this command in your command line:"))
	sb.WriteString(md.CodeBlock(`gnokey maketx run
	-gas-fee 1000000ugnot
	-gas-wanted 200000000
	-broadcast
	-chainid <chain-id>
	-remote <remote-url>
	<your-address>
	<path-to-approve-script.gno>`))

	sb.WriteString("\n")

	sb.WriteString(md.Link("Return to Homepage", "http://localhost:8888/r/matijamarjanovic/gnocket"))

	return sb.String()
}

// todo: provide a better description of the realm
// todo: update links to not be localhost
func RenderHome() string {
	sb := strings.Builder{}

	sb.WriteString(md.H1("Welcome to Gnocket"))
	sb.WriteString(md.Paragraph("This is a wallet realm that helps you manage your funds in terms of tokens and NFTs. It uses " + md.Link("TokenHub", "http://localhost:8888/r/matijamarjanovic/tokenhub") + " to perform its operations."))
	sb.WriteString(md.Paragraph("You need to create a wallet first to get started."))
	sb.WriteString(md.Paragraph(md.Link("Not sure you have a wallet?", "http://localhost:8888/r/matijamarjanovic/gnocket:createWalletInfo")))

	return sb.String()
}
