package gnomine

import (
	"time"
	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
)

var statusEmojis = map[string]string{
	"open":      "🟢 Open",      
	"fulfilled": "✅ Fulfilled", 
	"expired":   "⏰ Expired",  
	"cancelled": "❌ Cancelled", 
}

func Render(path string) string {
	str := md.H1("GnoMine Ticket System")
	str += md.Paragraph("View all open tickets for coin and token swaps.")

	openTickets := GetOpenTickets()
	if len(openTickets) == 0 {
		str += md.Blockquote("No open tickets available.")
		return str
	}

	str += md.H2("Open Tickets")
	
	for _, ticket := range openTickets {
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
			"Creator: " + string(ticket.Creator),
			"Publisher Offers: " + formatAsset(ticket.AssetIn, ticket.AmountIn),
			"Publisher Wants (minimum of): " + formatAsset(ticket.AssetOut, ticket.MinAmountOut),
			"Created At: " + ticket.CreatedAt.Format(time.RFC3339),
			"Expires At: " + ticket.ExpiresAt.Format(time.RFC3339),
			"Status: " + statusEmojis[ticket.Status],
		}

		str += md.BulletList(details)
		str += md.HorizontalRule()
	}

	return str
}

func formatAsset(asset Asset, amount uint64) string {
	if asset.Type == AssetTypeCoin {
		return ufmt.Sprintf("**%d** %s", amount, asset.Denom)
	}
	return ufmt.Sprintf("**%d** %s", amount, asset.Token)
}
