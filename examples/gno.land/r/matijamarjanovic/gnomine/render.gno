package gnomine

import (
	"time"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
	"strings"
)

var statusEmojis = map[string]string{
	"open":      "🟢 Open",      
	"fulfilled": "✅ Fulfilled", 
	"expired":   "⏰ Expired",  
	"cancelled": "❌ Cancelled", 
}

func Render(path string) string {
	// Extract the base path (before any query parameters)
	basePath := path
	if idx := strings.Index(path, "?"); idx != -1 {
		basePath = path[:idx]
	}

	switch basePath {
	case "ticketing":
		return RenderTickets(path)
	case "pools":
		return RenderPools(path)
	default:
		return RenderHome()
	}
}

// RenderHome displays the main landing page with navigation
func RenderHome() string {
	var str string
	str += md.H1("GnoMine")
	str += md.Paragraph("Welcome to GnoMine - Decentralized token exchange system on Gno.land")
	
	// Navigation section
	str += md.H2("Navigation")
	links := []string{
		md.Link("Liquidity Pools", "http://localhost:8888/r/matijamarjanovic/gnomine:pools") + " - View and interact with liquidity pools", // TODO: change to gno.land
		md.Link("Ticket System", "http://localhost:8888/r/matijamarjanovic/gnomine:ticketing") + " - Create and manage swap tickets", // TODO: change to gno.land
	}
	str += md.BulletList(links)
	
	// Quick stats section
	str += md.H2("Quick Stats")
	stats := []string{
		ufmt.Sprintf("Total Pools: %d", len(GetAllPoolNames())),
		ufmt.Sprintf("Open Tickets: %d", len(GetOpenTickets("").Items)),
	}
	str += md.BulletList(stats)
	
	// Add some space at the bottom
	str += md.HorizontalRule()
	str += md.Paragraph("Start by exploring the available pools or creating a new swap ticket.")
	
	return str
}

// RenderTickets handles the ticket system view
func RenderTickets(path string) string {
	var str string
	str += md.H2("Ticket System")
	str += md.Paragraph("View all open tickets for coin and token swaps.")

	page := GetOpenTickets(path)
	if len(page.Items) == 0 {
		str += md.Blockquote("No open tickets available.")
		return str
	}

	str += md.H2("Open Tickets")
	
	for _, item := range page.Items {
		ticket := item.Value.(*Ticket)
		
		swapType := ""
		if ticket.AssetIn.Type == AssetTypeCoin {
			swapType = ticket.AssetIn.Denom + " → " + ticket.AssetOut.Token
		} else if ticket.AssetOut.Type == AssetTypeCoin {
			swapType = ticket.AssetIn.Token + " → " + ticket.AssetOut.Denom
		} else {
			swapType = ticket.AssetIn.Token + " → " + ticket.AssetOut.Token
		}
		
		str += md.H3("#" + ticket.ID + " (" + swapType + ")")
		
		details := []string{
			"Publisher Offers: " + formatAsset(ticket.AssetIn, ticket.AmountIn),
			"Publisher Wants (min): " + formatAsset(ticket.AssetOut, ticket.MinAmountOut),
			"Created At: " + ticket.CreatedAt.Format(time.RFC3339),
			"Expires In: " + formatDuration(ticket.ExpiresAt.Sub(time.Now())),
			"Status: " + statusEmojis[ticket.Status],
		}

		str += md.BulletList(details)
		str += md.HorizontalRule()
	}

	if page.TotalPages > 1 {
		str += "\n\nPages: " + page.Picker()
	}

	return str
}

// RenderPools handles the main pools view (default)
func RenderPools(path string) string {
	var str string
	str += md.H2("Available Pools")
	str += md.Paragraph("View and interact with liquidity pools.")

	page := GetPoolsPage(path)
	if len(page.Items) == 0 {
		str += md.Blockquote("No pools available.")
		return str
	}

	for _, item := range page.Items {
		poolKey := item.Key
		tokenA, tokenB, reserveA, reserveB, err := GetPoolInfo(poolKey)
		if err != nil {
			continue
		}

		tokens := strings.Split(poolKey, ":")
		str += md.H3(tokens[0] + " <-> " + tokens[1])
		details := []string{
			"First token: " + tokenA + " - **" + ufmt.Sprintf("%d", reserveA) + "**",
			"Second token: " + tokenB + " - **" + ufmt.Sprintf("%d", reserveB) + "**",
		}
		str += md.BulletList(details)
		str += md.HorizontalRule()
	}

	if page.TotalPages > 1 {
		str += "\n\nPages: " + page.Picker()
	}

	return str
}

func formatAsset(asset Asset, amount uint64) string {
	if asset.Type == AssetTypeCoin {
		return ufmt.Sprintf("**%d** %s", amount, asset.Denom)
	}
	return ufmt.Sprintf("**%d** %s", amount, asset.Token)
}

func formatDuration(d time.Duration) string {
	if d <= 0 {
		return "Expired"
	}
	
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	
	if hours > 24 {
		days := hours / 24
		hours = hours % 24
		return ufmt.Sprintf("%dd %dh", days, hours)
	}
	
	if hours > 0 {
		return ufmt.Sprintf("%dh %dm", hours, minutes)
	}
	
	return ufmt.Sprintf("%dm", minutes)
}
