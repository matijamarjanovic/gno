package gnocket

import (
	//"std"
	"strings"
	"gno.land/p/moul/md"
	"gno.land/p/demo/ufmt"
)


// TODO : add filtering by token type with parsing address.[tokenType]; if no token type is provided, return all tokens
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

		return RenderUserPageAllTypes(userToDisplay, tokenType, allBool)
	}
	

	sb := strings.Builder{}
	sb.WriteString("")

	return sb.String()
}

// TODO : add  sorting by token type
// todo : add error handling
// todo : make a better ui
func RenderUserPageAllTypes(userToDisplay string, tokenTypeOption string, allBool bool) string {

	_, exists := wallets.Get(string(userToDisplay))
	if !exists {
		return "no wallet found"
	}
	sb := strings.Builder{}

	sb.WriteString(md.H1(ufmt.Sprintf("Wallet of %s", userToDisplay)))

	sb.WriteString(md.BulletList([]string{}))

	balances := GetBalances(allBool, tokenTypeOption, userToDisplay)
	sb.WriteString(md.BulletList(balances))


	return sb.String()
}

func RenderCreateWalletInfo() string {

	return "Create a wallet first"
}

// todo: provide a better description of the realm
// todo: update links to not be localhost
func RenderHome() string {
	sb := strings.Builder{}

	sb.WriteString(md.H1("Welcome to Gnocket"))
	sb.WriteString(md.Paragraph("This is a wallet realm that helps you manage your funds in terms of tokens and NFTs. It uses " + md.Link("TokenHub", "http://localhost:8888/r/matijamarjanovic/tokenhub") + " to perform its operations."))
	sb.WriteString(md.Paragraph("You need to create a wallet first to get started."))
	sb.WriteString(md.Paragraph(md.Link("Not sure you have a wallet?", "https://localhost:8888/r/matijamarjanovic/gnocket:info")))

	return sb.String()
}
